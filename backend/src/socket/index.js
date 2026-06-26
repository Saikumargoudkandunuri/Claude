'use strict';

const { Server } = require('socket.io');
const { verifyAccessToken } = require('../utils/jwt');
const { query } = require('../db/pool');

/**
 * Initialize Socket.IO on the HTTP server.
 * Handles: real-time messages, typing indicators, read receipts.
 */
function initSocket(httpServer, config) {
  const io = new Server(httpServer, {
    cors: {
      origin: config.corsOrigins.includes('*') ? true : config.corsOrigins,
      credentials: true,
    },
    transports: ['websocket', 'polling'],
  });

  // Auth middleware — verify JWT token from handshake
  io.use((socket, next) => {
    const token = socket.handshake.auth?.token || socket.handshake.query?.token;
    if (!token) return next(new Error('Authentication required'));
    try {
      const payload = verifyAccessToken(token);
      socket.userId = payload.sub;
      socket.userRole = payload.role;
      next();
    } catch (_) {
      next(new Error('Invalid token'));
    }
  });

  io.on('connection', async (socket) => {
    const userId = socket.userId;
    console.log(`[Socket] User connected: ${userId}`);

    // Auto-join all project rooms the user is assigned to
    try {
      const { rows } = await query(
        `SELECT DISTINCT project_id FROM project_assignments
         WHERE user_id = $1 AND active = true`,
        [userId]
      );
      for (const r of rows) {
        socket.join(`project:${r.project_id}`);
      }

      // Admins join ALL project rooms
      const userRes = await query('SELECT role FROM users WHERE id = $1', [userId]);
      if (userRes.rows[0]?.role === 'admin') {
        const all = await query('SELECT id FROM projects WHERE is_archived = false');
        for (const p of all.rows) {
          socket.join(`project:${p.id}`);
        }
      }

      // Supervisors join their projects
      if (userRes.rows[0]?.role === 'supervisor') {
        const supervised = await query(
          'SELECT id FROM projects WHERE supervisor_id = $1 AND is_archived = false',
          [userId]
        );
        for (const p of supervised.rows) {
          socket.join(`project:${p.id}`);
        }
      }
    } catch (e) {
      console.error('[Socket] Room join error:', e.message);
    }

    // Handle typing indicator
    socket.on('typing', (data) => {
      if (data?.projectId) {
        socket.to(`project:${data.projectId}`).emit('typing', {
          userId,
          projectId: data.projectId,
          isTyping: data.isTyping ?? true,
        });
      }
    });

    // Handle message read receipt
    socket.on('message_read', async (data) => {
      if (data?.reportId && data?.projectId) {
        try {
          // Update the read_by field
          await query(
            `UPDATE daily_reports
             SET read_by = read_by || $1::jsonb
             WHERE id = $2 AND NOT (read_by @> $1::jsonb)`,
            [JSON.stringify([userId]), data.reportId]
          );
          // Broadcast to room
          io.to(`project:${data.projectId}`).emit('message_read', {
            reportId: data.reportId,
            userId,
            readAt: new Date().toISOString(),
          });
        } catch (e) {
          console.error('[Socket] Read receipt error:', e.message);
        }
      }
    });

    // Handle disconnect
    socket.on('disconnect', () => {
      console.log(`[Socket] User disconnected: ${userId}`);
    });
  });

  return io;
}

/**
 * Emit a new message event to all members of a project room.
 * Called from the reports controller after a report is created.
 */
function emitNewMessage(io, projectId, message) {
  if (io) {
    io.to(`project:${projectId}`).emit('new_message', message);
  }
}

module.exports = { initSocket, emitNewMessage };
