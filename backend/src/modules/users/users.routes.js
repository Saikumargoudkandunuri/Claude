'use strict';

const express = require('express');
const controller = require('./users.controller');
const schema = require('./users.schema');
const { validate } = require('../../middleware/validate');
const { requireRole, requirePermission } = require('../../middleware/rbac');

const router = express.Router();

// Assignment picker list is available to admin and supervisor.
router.get(
  '/assignable',
  requireRole('admin', 'supervisor'),
  validate(schema.assignableQuery, 'query'),
  controller.assignable
);

// Everything below is admin-only.
router.use(requireRole('admin'));

router.get('/', requirePermission('users:read'), validate(schema.listQuery, 'query'), controller.list);
router.get('/pending', requirePermission('users:read'), controller.listPending);
router.post('/:id/approve', requirePermission('users:approve'), validate(schema.approve), controller.approve);
router.post('/:id/reject', requirePermission('users:approve'), controller.reject);
router.put('/:id/role', requirePermission('users:assign-role'), validate(schema.setRole), controller.setRole);
router.put('/:id/disable', requirePermission('users:assign-role'), controller.disable);

module.exports = router;
