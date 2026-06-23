'use strict';

const express = require('express');
const controller = require('./payments.controller');
const schema = require('./payments.schema');
const { validate } = require('../../middleware/validate');
const { requireRole, requirePermission } = require('../../middleware/rbac');

// Mounted at /api root (behind authenticate + requireApproved).
// Payments are admin-only.
const router = express.Router();

router.use(requireRole('admin'));

router.get(
  '/projects/:projectId/payments',
  requirePermission('payments:read'),
  controller.get
);
router.put(
  '/projects/:projectId/payments',
  requirePermission('payments:write'),
  validate(schema.updateSummary),
  controller.updateSummary
);
router.post(
  '/projects/:projectId/payments/history',
  requirePermission('payments:write'),
  validate(schema.addHistory),
  controller.addHistory
);
router.post(
  '/projects/:projectId/payments/received',
  requirePermission('payments:write'),
  validate(schema.received),
  controller.addReceived
);
router.post(
  '/projects/:projectId/payments/clear',
  requirePermission('payments:write'),
  validate(schema.clear),
  controller.clearBalance
);
router.put(
  '/payments/history/:id',
  requirePermission('payments:write'),
  validate(schema.updateHistory),
  controller.updateHistory
);
router.delete(
  '/payments/history/:id',
  requirePermission('payments:write'),
  controller.removeHistory
);

module.exports = router;
