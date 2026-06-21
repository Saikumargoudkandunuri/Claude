'use strict';

const express = require('express');
const controller = require('./activity.controller');

// Mounted at /api root (behind authenticate + requireApproved).
const router = express.Router();

router.get('/activity', controller.list);
router.get('/projects/:projectId/activity', controller.forProject);

module.exports = router;
