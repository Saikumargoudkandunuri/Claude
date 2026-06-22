'use strict';

const express = require('express');
const crypto = require('crypto');
const { asyncHandler, ok } = require('../../utils/http');
const { query } = require('../../db/pool');
const { ApiError } = require('../../utils/http');
const { requireRole } = require('../../middleware/rbac');
const { authenticate, requireApproved } = require('../../middleware/auth');

const router = express.Router();

// Admin: generate/regenerate client token for a project.
router.post(
  '/projects/:projectId/client-token',
  authenticate, requireApproved, requireRole('admin'),
  asyncHandler(async (req, res) => {
    const token = crypto.randomBytes(16).toString('hex');
    await query(
      `INSERT INTO client_tokens (project_id, token, created_by)
       VALUES ($1,$2,$3)
       ON CONFLICT (project_id) DO UPDATE SET token = EXCLUDED.token, enabled = true`,
      [req.params.projectId, token, req.user.id]
    );
    ok(res, { token, url: `/client/${token}` }, 201);
  })
);

// Admin: disable client token.
router.delete(
  '/projects/:projectId/client-token',
  authenticate, requireApproved, requireRole('admin'),
  asyncHandler(async (req, res) => {
    await query('UPDATE client_tokens SET enabled = false WHERE project_id = $1', [req.params.projectId]);
    res.status(204).send();
  })
);

// Public: client progress view (no auth required).
router.get(
  '/client/:token',
  asyncHandler(async (req, res) => {
    const { rows } = await query(
      `SELECT ct.*, p.project_name, p.customer_name, p.current_stage,
              p.start_date, p.expected_completion_date
         FROM client_tokens ct
         JOIN projects p ON p.id = ct.project_id
        WHERE ct.token = $1 AND ct.enabled = true`,
      [req.params.token]
    );
    if (!rows[0]) throw ApiError.notFound('Invalid or disabled link');
    const r = rows[0];

    const stages = await query(
      `SELECT stage, status, changed_at FROM project_stage_history
        WHERE project_id = $1 ORDER BY changed_at ASC`,
      [r.project_id]
    );
    const photos = await query(
      `SELECT id, original_name, created_at FROM files
        WHERE project_id = $1 AND category = 'photo'
        ORDER BY created_at DESC LIMIT 10`,
      [r.project_id]
    );
    const pay = await query('SELECT * FROM payments WHERE project_id = $1', [r.project_id]);
    const payment = pay.rows[0];

    ok(res, {
      projectName: r.project_name,
      customerName: r.customer_name,
      currentStage: r.current_stage,
      startDate: r.start_date,
      expectedCompletionDate: r.expected_completion_date,
      stageProgress: stages.rows,
      recentPhotos: photos.rows.map((p) => ({ id: p.id, name: p.original_name, date: p.created_at })),
      paymentSummary: payment ? {
        quotationAmount: Number(payment.quotation_amount),
        totalReceived: Number(payment.total_received),
        balance: Number(payment.quotation_amount) - Number(payment.total_received),
      } : null,
    });
  })
);

module.exports = router;
