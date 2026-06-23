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
  const balance = Number((quotation - received).toFixed(2));
  return {
    projectId: row.project_id,
    quotationAmount: quotation,
    totalReceived: received,
    balanceAmount: balance,
    paymentPercentage: quotation > 0 ? Math.round((received / quotation) * 1000) / 10 : 0,
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

  // FIX-06: Require quotation amount to be set before recording payments.
  const payCheck = await query('SELECT quotation_amount FROM payments WHERE project_id = $1', [projectId]);
  if (!payCheck.rows[0] || Number(payCheck.rows[0].quotation_amount) === 0) {
    throw ApiError.validation('Set the quotation amount for this project before recording payments.');
  }

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

async function updateHistory(adminId, historyId, body) {
  const existing = await query('SELECT * FROM payment_history WHERE id = $1', [historyId]);
  if (!existing.rows[0]) throw ApiError.notFound('Payment entry not found');

  const fieldMap = {
    kind: 'kind',
    amount: 'amount',
    paidOn: 'paid_on',
    method: 'method',
    referenceNumber: 'reference_number',
    remarks: 'remarks',
  };
  const set = [];
  const params = [];
  for (const [key, col] of Object.entries(fieldMap)) {
    if (key in body) {
      params.push(body[key]);
      set.push(`${col} = $${params.length}`);
    }
  }
  if (set.length === 0) throw ApiError.badRequest('No fields to update');
  params.push(historyId);

  const { rows } = await query(
    `UPDATE payment_history SET ${set.join(', ')} WHERE id = $${params.length} RETURNING *`,
    params
  );
  // Trigger recomputes payments.total_received.
  await logActivity({
    userId: adminId,
    projectId: rows[0].project_id,
    action: 'payment.update',
    entityType: 'payment_history',
    entityId: historyId,
    description: `Updated payment entry to ${rows[0].amount}`,
    metadata: { fields: Object.keys(body) },
  });
  return serializeHistory(rows[0]);
}

/** Settle the project: record a final payment equal to the remaining balance. */
async function clearBalance(adminId, projectId, body) {
  await ensureSummary(projectId);
  const summaryRes = await query('SELECT * FROM payments WHERE project_id = $1', [projectId]);
  const summary = serializeSummary(summaryRes.rows[0]);
  if (summary.balanceAmount <= 0) {
    throw ApiError.badRequest('Payment is already fully cleared');
  }
  const entry = await addHistory(adminId, projectId, {
    kind: 'final',
    amount: summary.balanceAmount,
    method: body.method || null,
    referenceNumber: body.referenceNumber || null,
    remarks: body.remarks || 'Balance cleared',
  });
  await logActivity({
    userId: adminId,
    projectId,
    action: 'payment.clear',
    entityType: 'payment',
    entityId: projectId,
    description: `Cleared remaining balance of ${summary.balanceAmount}`,
  });
  return entry;
}

/** BUG-08: record a partial received payment, validating it does not exceed the balance. */
async function addReceived(adminId, projectId, body) {
  await ensureSummary(projectId);
  const summaryRes = await query('SELECT * FROM payments WHERE project_id = $1', [projectId]);
  const summary = serializeSummary(summaryRes.rows[0]);
  if (summary.quotationAmount === 0) {
    throw ApiError.validation('Set the quotation amount for this project before recording payments.');
  }
  if (body.amount > summary.balanceAmount + 0.01) {
    throw ApiError.validation(
      `Amount exceeds the pending balance of ${summary.balanceAmount}.`
    );
  }
  return addHistory(adminId, projectId, {
    kind: body.kind || 'other',
    amount: body.amount,
    paidOn: body.paidOn,
    method: body.paymentMode || body.method || null,
    referenceNumber: body.referenceNumber || null,
    remarks: body.note || body.remarks || null,
  });
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

module.exports = { get, updateSummary, addHistory, updateHistory, clearBalance, addReceived, removeHistory };
