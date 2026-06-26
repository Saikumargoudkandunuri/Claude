'use strict';

const express = require('express');
const controller = require('./attendance.controller');
const { requireRole } = require('../../middleware/rbac');

const router = express.Router();

// Worker checks in
router.post('/attendance/check-in', controller.checkIn);

// Worker checks out
router.post('/attendance/check-out', controller.checkOut);

// Get today's attendance status for current user
router.get('/attendance/me/today', controller.myToday);

// Worker: enhanced today status with hours
router.get('/attendance/me/status', controller.todayStatus);

// Worker: attendance history (last 30 days)
router.get('/attendance/me/history', controller.workerHistory);

// Admin/supervisor: get attendance list
router.get('/attendance', requireRole('admin', 'supervisor'), controller.listAttendance);

// Admin: get monthly summary for a worker
router.get('/attendance/summary/:userId', requireRole('admin'), controller.monthlySummary);

module.exports = router;
