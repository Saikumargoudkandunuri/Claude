'use strict';

const { Router } = require('express');
const { requireRole } = require('../../middleware/rbac');
const ctrl = require('./payroll.controller');

const router = Router();

// ── ATTENDANCE — Worker self-service ────────────────────────────
router.post('/payroll/attendance/mark', requireRole('worker'), ctrl.markAttendance);
router.post('/payroll/attendance/checkout', requireRole('worker'), ctrl.checkOut);
router.get('/payroll/attendance/today', requireRole('worker'), ctrl.getMyTodayStatus);
router.get('/payroll/attendance/my', requireRole('worker'), ctrl.getMyAttendance);

// ── ATTENDANCE — Admin ─────────────────────────────────────────
router.get('/payroll/attendance/all-today', requireRole('admin'), ctrl.getAllTodayAttendance);
router.post('/payroll/attendance/admin-mark', requireRole('admin'), ctrl.adminMarkAttendance);

// ── SALARY PROFILE ─────────────────────────────────────────────
router.post('/payroll/salary/set', requireRole('admin'), ctrl.setSalary);
router.get('/payroll/workers/:workerId/salary-preview', requireRole('admin'), ctrl.getSalaryPreview);

// ── PAYMENTS ─────────────────────────────────────────────────────
router.post('/payroll/workers/:workerId/payments',
  requireRole('admin'),
  ctrl.upload.single('proof_image'),
  ctrl.addPayment
);
router.get('/payroll/workers/:workerId/payments', requireRole('admin'), ctrl.getWorkerPayments);
router.get('/payroll/summary', requireRole('admin'), ctrl.getAllSalarySummary);

// ── WORKER SELF-VIEW ─────────────────────────────────────────────
router.get('/payroll/my/salary-preview', requireRole('worker'), ctrl.getMySalaryPreview);
router.get('/payroll/my/payments', requireRole('worker'), ctrl.getMyPayments);

module.exports = router;
