'use strict';

const express = require('express');
const controller = require('./checklists.controller');
const schema = require('./checklists.schema');
const { validate } = require('../../middleware/validate');
const { requireRole } = require('../../middleware/rbac');

const router = express.Router();

router.get('/projects/:projectId/checklists', controller.list);
router.post(
  '/projects/:projectId/checklists',
  requireRole('admin', 'supervisor'),
  validate(schema.create),
  controller.create
);
router.put(
  '/checklists/:id',
  requireRole('admin', 'supervisor'),
  validate(schema.update),
  controller.update
);
router.delete('/checklists/:id', requireRole('admin'), controller.remove);

module.exports = router;
