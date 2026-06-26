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

// Worker reports GPS location (geofence check)
router.post('/attendance/report-location', controller.reportLocation);

// Worker checks if they have a pending geofence alert
router.get('/attendance/me/geofence-alert', controller.getPendingAlert);

// Admin: get all pending geofence alerts
router.get('/attendance/geofence-alerts', requireRole('admin'), controller.getPendingAlerts);

// Admin: resolve (approve/decline) a geofence alert
router.put('/attendance/geofence-alerts/:alertId', requireRole('admin'), controller.resolveAlert);

module.exports = router;
