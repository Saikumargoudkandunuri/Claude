'use strict';

const express = require('express');
const controller = require('./activity.controller');

// Mounted at /api root (behind authenticate + requireApproved).
const router = express.Router();

router.get('/activity', controller.list);
router.get('/projects/:projectId/activity', controller.forProject);
router.get('/projects/:projectId/timeline', controller.timeline);

module.exports = router;
