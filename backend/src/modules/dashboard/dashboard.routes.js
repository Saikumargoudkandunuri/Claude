'use strict';

const express = require('express');
const controller = require('./dashboard.controller');
const { requireRole } = require('../../middleware/rbac');

// Mounted at /dashboard (behind authenticate + requireApproved).
const router = express.Router();

router.get('/admin', requireRole('admin'), controller.admin);
router.get('/supervisor', requireRole('supervisor', 'admin'), controller.supervisor);
router.get('/designer', requireRole('designer', 'admin'), controller.designer);
router.get('/worker', requireRole('worker', 'admin'), controller.worker);

module.exports = router;
