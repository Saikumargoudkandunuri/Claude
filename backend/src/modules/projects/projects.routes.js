'use strict';

const express = require('express');
const controller = require('./projects.controller');
const schema = require('./projects.schema');
const { validate } = require('../../middleware/validate');
const { requireRole } = require('../../middleware/rbac');

// Mounted at /projects (router already behind authenticate + requireApproved).
const router = express.Router();

router.get('/', validate(schema.listQuery, 'query'), controller.list);
router.post('/', requireRole('admin'), validate(schema.create), controller.create);

router.get('/:id', controller.getOne);
router.put('/:id', requireRole('admin'), validate(schema.update), controller.update);
router.delete('/:id', requireRole('admin'), controller.remove);

// Stages
router.get('/:id/stages', controller.getStages);
router.put(
  '/:id/stage',
  requireRole('admin', 'supervisor', 'designer'),
  validate(schema.setStage),
  controller.setStage
);

// Assignments
router.get('/:id/assignments', controller.listAssignments);
router.post(
  '/:id/assignments',
  requireRole('admin', 'supervisor'),
  validate(schema.assign),
  controller.addAssignment
);
router.delete(
  '/:id/assignments/:assignmentId',
  requireRole('admin', 'supervisor'),
  controller.removeAssignment
);

module.exports = router;
