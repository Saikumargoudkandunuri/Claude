'use strict';

const multer = require('multer');
const path = require('path');
const fs = require('fs');
const service = require('./payroll.service');

const uploadDir = path.join(__dirname, '../../../uploads/payroll');
if (!fs.existsSync(uploadDir)) fs.mkdirSync(uploadDir, { recursive: true });

const storage = multer.diskStorage({
  destination: (req, file, cb) => cb(null, uploadDir),
  filename: (req, file, cb) => {
    const ext = path.extname(file.originalname);
    cb(null, `proof_${Date.now()}_${Math.random().toString(36).slice(2)}${ext}`);
  },
});

const upload = multer({
  storage,
  limits: { fileSize: 5 * 1024 * 1024 },
  fileFilter: (req, file, cb) => {
    if (file.mimetype.startsWith('image/')) cb(null, true);
    else cb(new Error('Only images allowed for payment proof'));
  },
});

// ── ATTENDANCE ──────────────────────────────────────────────────────

async function markAttendance(req, res, next) {
  try {
    const { work_mode, project_id, notes } = req.body;
    if (!['at_site', 'workshop'].includes(work_mode)) {
      return res.status(400).json({ error: { message: 'work_mode must be at_site or workshop' } });
    }
    const record = await service.markAttendance(req.user.id, work_mode, project_id, notes);
    res.json({ data: record, message: `Attendance marked: ${work_mode}` });
  } catch (err) {
    if (err.statusCode) return res.status(err.statusCode).json({ error: { message: err.message } });
    next(err);
  }
}

async function checkOut(req, res, next) {
  try {
    const record = await service.checkOut(req.user.id);
    res.json({ data: record, message: `Checked out. Hours: ${record.hours_worked}h` });
  } catch (err) {
    if (err.statusCode) return res.status(err.statusCode).json({ error: { message: err.message } });
    next(err);
  }
}

async function getMyTodayStatus(req, res, next) {
  try {
    const record = await service.getTodayAttendance(req.user.id);
    res.json({ data: record });
  } catch (err) { next(err); }
}

async function getMyAttendance(req, res, next) {
  try {
    const { from, to } = req.query;
    const toDate = to || new Date().toISOString().split('T')[0];
    const fromDate = from || new Date(Date.now() - 30 * 86400000).toISOString().split('T')[0];
    const records = await service.getWorkerAttendance(req.user.id, fromDate, toDate);
    res.json({ data: records });
  } catch (err) { next(err); }
}

async function getAllTodayAttendance(req, res, next) {
  try {
    const records = await service.getAllTodayAttendance();
    res.json({ data: records });
  } catch (err) { next(err); }
}

async function adminMarkAttendance(req, res, next) {
  try {
    const { target_user_id, date, work_mode, notes } = req.body;
    if (!target_user_id || !date || !work_mode) {
      return res.status(400).json({ error: { message: 'target_user_id, date, work_mode required' } });
    }
    if (!['at_site','workshop','leave','absent'].includes(work_mode)) {
      return res.status(400).json({ error: { message: 'Invalid work_mode' } });
    }
    const record = await service.adminMarkAttendance(target_user_id, date, work_mode, notes, req.user.id);
    res.json({ data: record });
  } catch (err) { next(err); }
}

// ── SALARY PROFILE ───────────────────────────────────────────────────────

async function setSalary(req, res, next) {
  try {
    const { worker_id, monthly_salary, working_days_per_month } = req.body;
    if (!worker_id || !monthly_salary) {
      return res.status(400).json({ error: { message: 'worker_id and monthly_salary required' } });
    }
    const result = await service.setWorkerSalary(worker_id, monthly_salary, working_days_per_month);
    res.json({ data: result, message: 'Salary updated.' });
  } catch (err) {
    if (err.statusCode) return res.status(err.statusCode).json({ error: { message: err.message } });
    next(err);
  }
}

async function getSalaryPreview(req, res, next) {
  try {
    const monthYear = req.query.month || new Date().toISOString().slice(0, 7);
    const calc = await service.calculateMonthlySalary(req.params.workerId, monthYear);
    res.json({ data: calc });
  } catch (err) {
    if (err.statusCode) return res.status(err.statusCode).json({ error: { message: err.message } });
    next(err);
  }
}

async function getMySalaryPreview(req, res, next) {
  try {
    const monthYear = req.query.month || new Date().toISOString().slice(0, 7);
    const calc = await service.calculateMonthlySalary(req.user.id, monthYear);
    res.json({ data: calc });
  } catch (err) {
    if (err.statusCode) return res.status(err.statusCode).json({ error: { message: err.message } });
    next(err);
  }
}

// ── PAYMENTS ────────────────────────────────────────────────────────────

async function addPayment(req, res, next) {
  try {
    const { payment_type, amount, month_year, notes } = req.body;
    if (!payment_type || !amount || !month_year) {
      return res.status(400).json({ error: { message: 'payment_type, amount, month_year required' } });
    }
    if (!['salary','advance','bonus'].includes(payment_type)) {
      return res.status(400).json({ error: { message: 'payment_type must be salary, advance, or bonus' } });
    }
    if (parseFloat(amount) <= 0) {
      return res.status(400).json({ error: { message: 'Amount must be positive' } });
    }

    let proofImageUrl = null;
    if (req.file) {
      proofImageUrl = `/uploads/payroll/${req.file.filename}`;
    }

    const result = await service.addPayment(req.params.workerId, {
      paymentType: payment_type,
      amount: parseFloat(amount),
      monthYear: month_year,
      notes,
      proofImageUrl,
    }, req.user.id);

    res.status(201).json({ data: result, message: 'Payment recorded.' });
  } catch (err) {
    if (err.statusCode) return res.status(err.statusCode).json({ error: { message: err.message } });
    next(err);
  }
}

async function getMyPayments(req, res, next) {
  try {
    const payments = await service.getWorkerPayments(req.user.id, req.query.month || null);
    res.json({ data: payments });
  } catch (err) { next(err); }
}

async function getWorkerPayments(req, res, next) {
  try {
    const payments = await service.getWorkerPayments(req.params.workerId, req.query.month || null);
    res.json({ data: payments });
  } catch (err) { next(err); }
}

async function getAllSalarySummary(req, res, next) {
  try {
    const monthYear = req.query.month || new Date().toISOString().slice(0, 7);
    const data = await service.getAllWorkersSalarySummary(monthYear);
    res.json({ data });
  } catch (err) { next(err); }
}

module.exports = {
  markAttendance, checkOut, getMyTodayStatus, getMyAttendance,
  getAllTodayAttendance, adminMarkAttendance,
  setSalary, getSalaryPreview, getMySalaryPreview,
  addPayment, getMyPayments, getWorkerPayments, getAllSalarySummary,
  upload,
};
