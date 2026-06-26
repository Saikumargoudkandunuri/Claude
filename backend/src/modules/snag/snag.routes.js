'use strict';

const { Router } = require('express');
const { requireRole } = require('../../middleware/rbac');
const ctrl = require('./snag.controller');

const router = Router();

// List snag items for a project (all authenticated roles can see)
router.get('/projects/:projectId/snags', ctrl.list);

// Summary counts only
router.get('/projects/:projectId/snags/summary', ctrl.summary);

// Create snag item — supervisor and admin only
router.post('/projects/:projectId/snags',
  requireRole('admin', 'supervisor'),
  ctrl.create
);

// Worker resolves (marks their assigned item done with note/photo)
router.put('/snags/:itemId/resolve',
  requireRole('admin', 'supervisor', 'worker'),
  ctrl.resolve
);

// Admin or supervisor closes (after reviewing worker's resolution)
router.put('/snags/:itemId/close',
  requireRole('admin', 'supervisor'),
  ctrl.close
);

module.exports = router;
