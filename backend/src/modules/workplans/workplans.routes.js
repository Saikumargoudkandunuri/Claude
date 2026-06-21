'use strict';

const express = require('express');
const controller = require('./workplans.controller');
const schema = require('./workplans.schema');
const { validate } = require('../../middleware/validate');
const { requireRole } = require('../../middleware/rbac');

// Mounted at /api root (behind authenticate + requireApproved).
const router = express.Router();

router.get(
  '/projects/:projectId/workplans',
  validate(schema.listQuery, 'query'),
  controller.list
);
router.post(
  '/projects/:projectId/workplans',
  requireRole('admin', 'supervisor'),
  validate(schema.create),
  controller.create
);

router.get('/workplans/me', validate(schema.listQuery, 'query'), controller.forMe);
router.delete('/workplans/:id', requireRole('admin', 'supervisor'), controller.remove);

module.exports = router;
