'use strict';

const { query } = require('../../db/pool');
const { ApiError } = require('../../utils/http');
const { logActivity } = require('../../utils/activity');
const { notifyAdmins } = require('../../utils/notify');

async function ensureSummary(projectId) {
  const proj = await query('SELECT id, quotation_amount, project_name FROM projects WHERE id = $1', [
    projectId,
  ]);
  if (!proj.rows[0]) throw ApiError.notFound('Project not found');
  await query(
    `INSERT INTO payments (project_id, quotation_amount)
     VALUES ($1,$2) ON CONFLICT (project_id) DO NOTHING`,
    [projectId, proj.rows[0].quotation_amount]
  );
  return proj.rows[0];
}

function serializeSummary(row) {
  const quotation = Number(row.quotation_amount);
  const received = Number(row.total_received);
  return {
    projectId: row.project_id,
    quotationAmount: quotation,
    totalReceived: received,
    balanceAmount: Number((quotation - received).toFixed(2)),
    updatedAt: row.updated_at,
  };
}

function serializeHistory(row) {
  return {
    id: row.id,
    projectId: row.project_id,
    kind: row.kind,
    amount: Number(row.amount),
    paidOn: row.paid_on,
    method: row.method,
    referenceNumber: row.reference_number,
    remarks: row.remarks,
    recordedBy: row.recorded_by,
    createdAt: row.created_at,
  };
}

async function get(projectId) {
  await ensureSummary(projectId);
  const summary = await query('SELECT * FROM payments WHERE project_id = $1', [projectId]);
  const history = await query(
    'SELECT * FROM payment_history WHERE project_id = $1 ORDER BY paid_on DESC, created_at DESC',
    [projectId]
  );
  return {
    summary: serializeSummary(summary.rows[0]),
    history: history.rows.map(serializeHistory),
  };
}

async function updateSummary(adminId, projectId, { quotationAmount }) {
  await ensureSummary(projectId);
  const { rows } = await query(
    `UPDATE payments SET quotation_amount = $1, updated_at = now()
      WHERE project_id = $2 RETURNING *`,
    [quotationAmount, projectId]
  );
  // Keep the project record in sync.
  await query('UPDATE projects SET quotation_amount = $1 WHERE id = $2', [
    quotationAmount,
    projectId,
  ]);
  await logActivity({
    userId: adminId,
    projectId,
    action: 'payment.quotation',
    entityType: 'payment',
    entityId: projectId,
    description: `Set quotation amount to ${quotationAmount}`,
    metadata: { quotationAmount },
  });
  return serializeSummary(rows[0]);
}

async function addHistory(adminId, projectId, body) {
  const project = await ensureSummary(projectId);
  const paidOn = body.paidOn || new Date().toISOString().slice(0, 10);
  const { rows } = await query(
    `INSERT INTO payment_history
       (project_id, kind, amount, paid_on, method, reference_number, remarks, recorded_by)
     VALUES ($1,$2,$3,$4,$5,$6,$7,$8) RETURNING *`,
    [
      projectId,
      body.kind,
      body.amount,
      paidOn,
      body.method || null,
      body.referenceNumber || null,
      body.remarks || null,
      adminId,
    ]
  );
  // Trigger recomputes payments.total_received.
  await logActivity({
    userId: adminId,
    projectId,
    action: 'payment.add',
    entityType: 'payment_history',
    entityId: rows[0].id,
    description: `Recorded ${body.kind} payment of ${body.amount}`,
    metadata: { kind: body.kind, amount: body.amount },
  });
  await notifyAdmins({
    type: 'payment.updated',
    title: 'Payment recorded',
    body: `${project.project_name}: ${body.kind} payment of ${body.amount}`,
    projectId,
    data: { route: `icms://project/${projectId}` },
  });
  return serializeHistory(rows[0]);
}

async function removeHistory(adminId, historyId) {
  const { rows } = await query('SELECT * FROM payment_history WHERE id = $1', [historyId]);
  if (!rows[0]) throw ApiError.notFound('Payment entry not found');
  await query('DELETE FROM payment_history WHERE id = $1', [historyId]);
  await logActivity({
    userId: adminId,
    projectId: rows[0].project_id,
    action: 'payment.delete',
    entityType: 'payment_history',
    entityId: historyId,
    description: `Deleted payment entry of ${rows[0].amount}`,
  });
}

module.exports = { get, updateSummary, addHistory, removeHistory };
