'use strict';

const { Router } = require('express');
const { requireRole } = require('../../middleware/rbac');
const ctrl = require('./weekly_status.controller');

const router = Router();

// Per-project routes
router.get('/projects/:id/weekly-status', requireRole('admin', 'supervisor', 'designer'), ctrl.getCurrentStatus);
router.get('/projects/:id/weekly-status/history', requireRole('admin', 'supervisor'), ctrl.getHistory);
router.put('/projects/:id/weekly-status', requireRole('admin', 'supervisor'), ctrl.setStatus);

// Dashboard-level routes
router.get('/dashboard/weekly-overview', requireRole('admin'), ctrl.weeklyOverview);
router.get('/dashboard/needs-review', requireRole('admin', 'supervisor'), ctrl.needsReview);

module.exports = router;
