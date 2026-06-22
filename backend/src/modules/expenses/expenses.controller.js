'use strict';

const { asyncHandler, ok } = require('../../utils/http');
const { query } = require('../../db/pool');
const { ApiError } = require('../../utils/http');
const { logActivity } = require('../../utils/activity');

const list = asyncHandler(async (req, res) => {
  const params = [req.params.projectId];
  let sql = 'SELECT * FROM expenses WHERE project_id = $1';
  if (req.query.stage) { params.push(req.query.stage); sql += ` AND stage = $${params.length}`; }
  if (req.query.from) { params.push(req.query.from); sql += ` AND spent_on >= $${params.length}`; }
  if (req.query.to) { params.push(req.query.to); sql += ` AND spent_on <= $${params.length}`; }
  sql += ' ORDER BY spent_on DESC, created_at DESC';
  const { rows } = await query(sql, params);
  ok(res, rows.map(serialize));
});

const summary = asyncHandler(async (req, res) => {
  const { rows } = await query(
    `SELECT COALESCE(SUM(amount),0) AS total_spent FROM expenses WHERE project_id = $1`,
    [req.params.projectId]
  );
  const pay = await query(
    'SELECT quotation_amount FROM payments WHERE project_id = $1', [req.params.projectId]
  );
  const quotation = Number(pay.rows[0]?.quotation_amount ?? 0);
  const spent = Number(rows[0].total_spent);
  ok(res, { totalSpent: spent, quotationAmount: quotation, profitMargin: quotation - spent });
});

const create = asyncHandler(async (req, res) => {
  const { stage, category, description, amount, spentOn } = req.body;
  const { rows } = await query(
    `INSERT INTO expenses (project_id, stage, category, description, amount, spent_on, recorded_by)
     VALUES ($1,$2,$3,$4,$5,$6,$7) RETURNING *`,
    [req.params.projectId, stage || null, category, description, amount,
     spentOn || new Date().toISOString().slice(0, 10), req.user.id]
  );
  await logActivity({
    userId: req.user.id, projectId: req.params.projectId,
    action: 'expense.add', entityType: 'expense', entityId: rows[0].id,
    description: `Recorded expense: ${description} (${amount})`,
  });
  ok(res, serialize(rows[0]), 201);
});

const remove = asyncHandler(async (req, res) => {
  const { rows } = await query('SELECT * FROM expenses WHERE id = $1', [req.params.id]);
  if (!rows[0]) throw ApiError.notFound('Expense not found');
  await query('DELETE FROM expenses WHERE id = $1', [req.params.id]);
  await logActivity({
    userId: req.user.id, projectId: rows[0].project_id,
    action: 'expense.delete', entityType: 'expense', entityId: req.params.id,
    description: `Deleted expense of ${rows[0].amount}`,
  });
  res.status(204).send();
});

function serialize(r) {
  return { id: r.id, projectId: r.project_id, stage: r.stage, category: r.category,
    description: r.description, amount: Number(r.amount), spentOn: r.spent_on,
    receiptKey: r.receipt_key, recordedBy: r.recorded_by, createdAt: r.created_at };
}

module.exports = { list, summary, create, remove };
