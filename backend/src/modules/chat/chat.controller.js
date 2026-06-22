'use strict';

const { asyncHandler, ok } = require('../../utils/http');
const { query } = require('../../db/pool');
const { ApiError } = require('../../utils/http');
const { notifyUsers } = require('../../utils/notify');
const projects = require('../projects/projects.service');

const list = asyncHandler(async (req, res) => {
  const project = await projects.getAccessibleProject(req.user, req.params.projectId);
  const limit = Math.min(parseInt(req.query.limit || '50', 10), 100);
  let sql = `SELECT m.*, u.full_name AS author_name, u.role AS author_role
               FROM project_messages m
               JOIN users u ON u.id = m.author_id
              WHERE m.project_id = $1 AND m.is_deleted = false`;
  const params = [req.params.projectId];
  if (req.query.before) {
    params.push(req.query.before);
    sql += ` AND m.created_at < (SELECT created_at FROM project_messages WHERE id = $${params.length})`;
  }
  sql += ` ORDER BY m.created_at DESC LIMIT ${limit}`;
  const { rows } = await query(sql, params);
  ok(res, rows.map(serialize));
});

const create = asyncHandler(async (req, res) => {
  const project = await projects.getAccessibleProject(req.user, req.params.projectId);
  const { rows } = await query(
    `INSERT INTO project_messages (project_id, author_id, body)
     VALUES ($1,$2,$3) RETURNING *`,
    [req.params.projectId, req.user.id, req.body.body]
  );
  // Notify all project members (except author).
  const members = await query(
    `SELECT DISTINCT user_id FROM project_assignments
      WHERE project_id = $1 AND active = true AND user_id != $2
     UNION SELECT supervisor_id FROM projects WHERE id = $1 AND supervisor_id != $2
     UNION SELECT designer_id FROM projects WHERE id = $1 AND designer_id != $2`,
    [req.params.projectId, req.user.id]
  );
  const ids = members.rows.map((r) => r.user_id || r.supervisor_id || r.designer_id).filter(Boolean);
  await notifyUsers(ids, {
    type: 'project.message',
    title: `${req.user.full_name} in ${project.project_name}`,
    body: req.body.body.slice(0, 100),
    projectId: req.params.projectId,
    data: { route: `icms://project/${req.params.projectId}` },
  });
  ok(res, serialize(rows[0]), 201);
});

const remove = asyncHandler(async (req, res) => {
  const { rows } = await query('SELECT * FROM project_messages WHERE id = $1', [req.params.id]);
  if (!rows[0]) throw ApiError.notFound('Message not found');
  if (rows[0].author_id !== req.user.id && req.user.role !== 'admin') {
    throw ApiError.forbidden('Cannot delete this message');
  }
  await query(
    `UPDATE project_messages SET is_deleted = true, body = '[deleted]', updated_at = now() WHERE id = $1`,
    [req.params.id]
  );
  res.status(204).send();
});

function serialize(r) {
  return { id: r.id, projectId: r.project_id, authorId: r.author_id,
    authorName: r.author_name, authorRole: r.author_role,
    body: r.body, attachmentKey: r.attachment_key,
    createdAt: r.created_at };
}

module.exports = { list, create, remove };
