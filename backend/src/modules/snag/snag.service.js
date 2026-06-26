'use strict';

const { query } = require('../../db/pool');

async function createSnagItem(projectId, { title, description, priority, assignedTo }, createdBy) {
  const result = await query(
    `INSERT INTO snag_items
      (project_id, title, description, priority, assigned_to, created_by)
     VALUES ($1, $2, $3, $4, $5, $6)
     RETURNING *`,
    [projectId, title, description || null, priority || 'medium', assignedTo || null, createdBy]
  );
  await query(
    `INSERT INTO activity_logs (user_id, project_id, action, entity_type, entity_id, description)
     VALUES ($1, $2, 'snag.created', 'snag_item', $3, $4)`,
    [createdBy, projectId, result.rows[0].id, `Snag item created: ${title}`]
  );
  return result.rows[0];
}

async function getSnagItems(projectId, status) {
  const params = [projectId];
  let statusFilter = '';
  if (status) {
    params.push(status);
    statusFilter = `AND s.status = $${params.length}`;
  }
  const result = await query(
    `SELECT s.*,
       u_created.full_name as created_by_name,
       u_assigned.full_name as assigned_to_name,
       u_resolved.full_name as resolved_by_name
     FROM snag_items s
     LEFT JOIN users u_created  ON u_created.id  = s.created_by
     LEFT JOIN users u_assigned ON u_assigned.id = s.assigned_to
     LEFT JOIN users u_resolved ON u_resolved.id = s.resolved_by
     WHERE s.project_id = $1 ${statusFilter}
     ORDER BY
       CASE s.priority WHEN 'high' THEN 1 WHEN 'medium' THEN 2 ELSE 3 END,
       s.created_at DESC`,
    params
  );
  return result.rows;
}

async function resolveSnagItem(itemId, { resolutionNote, resolutionPhoto }, userId) {
  const result = await query(
    `UPDATE snag_items
     SET status = 'resolved',
         resolution_note = $1,
         resolution_photo = $2,
         resolved_by = $3,
         resolved_at = NOW()
     WHERE id = $4 AND status = 'open'
     RETURNING *`,
    [resolutionNote || null, resolutionPhoto || null, userId, itemId]
  );
  if (result.rows.length === 0) {
    const err = new Error('Snag item not found or already resolved');
    err.statusCode = 400;
    throw err;
  }
  return result.rows[0];
}

async function closeSnagItem(itemId, userId) {
  const result = await query(
    `UPDATE snag_items
     SET status = 'closed', closed_by = $1, closed_at = NOW()
     WHERE id = $2 AND status = 'resolved'
     RETURNING *`,
    [userId, itemId]
  );
  if (result.rows.length === 0) {
    const err = new Error('Item not found or not yet resolved');
    err.statusCode = 400;
    throw err;
  }
  return result.rows[0];
}

async function getProjectSnagSummary(projectId) {
  const result = await query(
    `SELECT
       COUNT(*) FILTER (WHERE status='open')::int as open_count,
       COUNT(*) FILTER (WHERE status='resolved')::int as resolved_count,
       COUNT(*) FILTER (WHERE status='closed')::int as closed_count,
       COUNT(*)::int as total
     FROM snag_items WHERE project_id = $1`,
    [projectId]
  );
  return result.rows[0];
}

module.exports = { createSnagItem, getSnagItems, resolveSnagItem, closeSnagItem, getProjectSnagSummary };
