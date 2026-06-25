'use strict';

const express = require('express');
const controller = require('./dashboard.controller');
const workforceController = require('./workforce.controller');
const { requireRole } = require('../../middleware/rbac');

// Mounted at /dashboard (behind authenticate + requireApproved).
const router = express.Router();

router.get('/admin', requireRole('admin'), controller.admin);
router.get('/supervisor', requireRole('supervisor', 'admin'), controller.supervisor);
router.get('/designer', requireRole('designer', 'admin'), controller.designer);
router.get('/worker', requireRole('worker', 'admin'), controller.worker);
router.get('/workforce', requireRole('admin', 'supervisor'), workforceController.getWorkforceData);

module.exports = router;
