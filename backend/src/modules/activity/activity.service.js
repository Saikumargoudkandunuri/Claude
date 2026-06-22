'use strict';

const { query } = require('../../db/pool');
const projects = require('../projects/projects.service');

function serialize(row) {
  const created = new Date(row.created_at);
  return {
    id: row.id,
    userId: row.user_id,
    userName: row.user_name,
    projectId: row.project_id,
    action: row.action,
    entityType: row.entity_type,
    entityId: row.entity_id,
    description: row.description,
    metadata: row.metadata,
    createdAt: row.created_at,
    // Pre-formatted date/day/time for the UI as required by the spec.
    date: created.toISOString().slice(0, 10),
    day: created.toLocaleDateString('en-US', { weekday: 'long' }),
    time: created.toTimeString().slice(0, 8),
  };
}

/** Global/admin activity feed with optional filters. */
async function list(user, { projectId, userId, from, to, page, limit }) {
  const params = [];
  const where = [];

  // Non-admins are restricted to project-scoped reads they can access.
  if (user.role !== 'admin') {
    if (!projectId) {
      return { data: [], meta: { page, limit, total: 0 } };
    }
    await projects.getAccessibleProject(user, projectId);
  }

  if (projectId) {
    params.push(projectId);
    where.push(`a.project_id = $${params.length}`);
  }
  if (userId) {
    params.push(userId);
    where.push(`a.user_id = $${params.length}`);
  }
  if (from) {
    params.push(from);
    where.push(`a.created_at >= $${params.length}`);
  }
  if (to) {
    params.push(to);
    where.push(`a.created_at <= $${params.length}`);
  }
  const whereSql = where.length ? `WHERE ${where.join(' AND ')}` : '';
  const offset = (page - 1) * limit;

  const total = await query(`SELECT COUNT(*)::int AS total FROM activity_logs a ${whereSql}`, params);
  const { rows } = await query(
    `SELECT a.*, u.full_name AS user_name
       FROM activity_logs a
       LEFT JOIN users u ON u.id = a.user_id
       ${whereSql}
       ORDER BY a.created_at DESC LIMIT ${limit} OFFSET ${offset}`,
    params
  );
  return { data: rows.map(serialize), meta: { page, limit, total: total.rows[0].total } };
}

async function forProject(user, projectId, { page, limit }) {
  await projects.getAccessibleProject(user, projectId);
  const offset = (page - 1) * limit;
  const { rows } = await query(
    `SELECT a.*, u.full_name AS user_name
       FROM activity_logs a LEFT JOIN users u ON u.id = a.user_id
      WHERE a.project_id = $1
      ORDER BY a.created_at DESC LIMIT ${limit} OFFSET ${offset}`,
    [projectId]
  );
  return rows.map(serialize);
}

/**
 * Complete project timeline (creation -> completion), ascending by time.
 * Built entirely from activity_logs which already capture project creation,
 * file/drawing uploads, reports, payments, assignments and stage changes.
 */
async function timeline(user, projectId, { limit = 300 } = {}) {
  await projects.getAccessibleProject(user, projectId);
  const { rows } = await query(
    `SELECT a.*, u.full_name AS user_name
       FROM activity_logs a LEFT JOIN users u ON u.id = a.user_id
      WHERE a.project_id = $1
      ORDER BY a.created_at ASC
      LIMIT ${Math.min(Number(limit) || 300, 1000)}`,
    [projectId]
  );
  return rows.map(serialize);
}

module.exports = { serialize, list, forProject, timeline };
