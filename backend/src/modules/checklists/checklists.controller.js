'use strict';

const { asyncHandler, ok } = require('../../utils/http');
const { query } = require('../../db/pool');
const { ApiError } = require('../../utils/http');
const { logActivity } = require('../../utils/activity');
const projects = require('../projects/projects.service');

const list = asyncHandler(async (req, res) => {
  await projects.getAccessibleProject(req.user, req.params.projectId);
  const params = [req.params.projectId];
  let sql = 'SELECT * FROM material_checklists WHERE project_id = $1';
  if (req.query.stage) {
    params.push(req.query.stage);
    sql += ` AND stage = $2`;
  }
  sql += ' ORDER BY created_at ASC';
  const { rows } = await query(sql, params);
  ok(res, rows.map(serialize));
});

const create = asyncHandler(async (req, res) => {
  await projects.getAccessibleProject(req.user, req.params.projectId);
  const { stage, itemName, quantity, unit } = req.body;
  const { rows } = await query(
    `INSERT INTO material_checklists (project_id, stage, item_name, quantity, unit, created_by)
     VALUES ($1,$2,$3,$4,$5,$6) RETURNING *`,
    [req.params.projectId, stage, itemName, quantity || null, unit || null, req.user.id]
  );
  await logActivity({
    userId: req.user.id,
    projectId: req.params.projectId,
    action: 'checklist.add',
    entityType: 'material_checklist',
    entityId: rows[0].id,
    description: `Added checklist item: ${itemName}`,
  });
  ok(res, serialize(rows[0]), 201);
});

const update = asyncHandler(async (req, res) => {
  const { rows: existing } = await query('SELECT * FROM material_checklists WHERE id = $1', [req.params.id]);
  if (!existing[0]) throw ApiError.notFound('Checklist item not found');
  const set = [];
  const params = [];
  const fields = { status: 'status', notes: 'notes', itemName: 'item_name', quantity: 'quantity', unit: 'unit' };
  for (const [k, col] of Object.entries(fields)) {
    if (k in req.body) { params.push(req.body[k]); set.push(`${col} = $${params.length}`); }
  }
  params.push(req.user.id); set.push(`updated_by = $${params.length}`);
  params.push(req.params.id);
  const { rows } = await query(
    `UPDATE material_checklists SET ${set.join(', ')}, updated_at = now() WHERE id = $${params.length} RETURNING *`,
    params
  );
  ok(res, serialize(rows[0]));
});

const remove = asyncHandler(async (req, res) => {
  await query('DELETE FROM material_checklists WHERE id = $1', [req.params.id]);
  res.status(204).send();
});

function serialize(r) {
  return { id: r.id, projectId: r.project_id, stage: r.stage, itemName: r.item_name,
    quantity: r.quantity, unit: r.unit, status: r.status, notes: r.notes,
    createdBy: r.created_by, updatedBy: r.updated_by, createdAt: r.created_at };
}

module.exports = { list, create, update, remove };
