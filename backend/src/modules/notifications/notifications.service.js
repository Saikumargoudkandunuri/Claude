'use strict';

const { query } = require('../../db/pool');
const { ApiError } = require('../../utils/http');

function serialize(row) {
  return {
    id: row.id,
    type: row.type,
    title: row.title,
    body: row.body,
    projectId: row.project_id,
    data: row.data,
    isRead: row.is_read,
    createdAt: row.created_at,
  };
}

async function list(userId, { unread, page, limit }) {
  const params = [userId];
  let where = 'user_id = $1';
  if (unread) where += ' AND is_read = false';
  const offset = (page - 1) * limit;
  const total = await query(`SELECT COUNT(*)::int AS total FROM notifications WHERE ${where}`, params);
  const { rows } = await query(
    `SELECT * FROM notifications WHERE ${where} ORDER BY created_at DESC LIMIT ${limit} OFFSET ${offset}`,
    params
  );
  return { data: rows.map(serialize), meta: { page, limit, total: total.rows[0].total } };
}

async function unreadCount(userId) {
  const { rows } = await query(
    'SELECT COUNT(*)::int AS count FROM notifications WHERE user_id = $1 AND is_read = false',
    [userId]
  );
  return { count: rows[0].count };
}

async function markRead(userId, id) {
  const { rows } = await query(
    'UPDATE notifications SET is_read = true WHERE id = $1 AND user_id = $2 RETURNING *',
    [id, userId]
  );
  if (!rows[0]) throw ApiError.notFound('Notification not found');
  return serialize(rows[0]);
}

async function markAllRead(userId) {
  await query('UPDATE notifications SET is_read = true WHERE user_id = $1 AND is_read = false', [
    userId,
  ]);
}

module.exports = { list, unreadCount, markRead, markAllRead };
