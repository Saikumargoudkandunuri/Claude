'use strict';

const express = require('express');
const controller = require('./notifications.controller');

// Mounted at /notifications (behind authenticate + requireApproved).
const router = express.Router();

router.get('/', controller.list);
router.get('/unread-count', controller.unreadCount);
router.post('/:id/read', controller.markRead);
router.post('/read-all', controller.markAllRead);

module.exports = router;
