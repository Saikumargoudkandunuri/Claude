'use strict';

const { query } = require('../../db/pool');

// ─── ATTENDANCE ──────────────────────────────────────────────

async function markAttendance(userId, workMode, projectId, notes) {
  if (workMode === 'at_site' && !projectId) {
    throw Object.assign(new Error('Project ID required for at-site attendance.'), { statusCode: 400 });
  }
  if (workMode === 'workshop') projectId = null;

  const result = await query(
    `INSERT INTO worker_attendance
       (user_id, date, work_mode, project_id, check_in_time, notes, marked_by)
     VALUES ($1, CURRENT_DATE, $2, $3, NOW(), $4, $1)
     ON CONFLICT (user_id, date)
     DO UPDATE SET
       work_mode = EXCLUDED.work_mode,
       project_id = EXCLUDED.project_id,
       notes = EXCLUDED.notes,
       check_in_time = COALESCE(worker_attendance.check_in_time, NOW()),
       updated_at = NOW()
     RETURNING *`,
    [userId, workMode, projectId || null, notes || null]
  );

  const statusMap = { at_site: 'at_site', workshop: 'workshop' };
  await query(
    `UPDATE users SET worker_status = $1, updated_at = NOW() WHERE id = $2`,
    [statusMap[workMode] || 'workshop', userId]
  );

  await query(
    `INSERT INTO activity_logs (user_id, project_id, action, entity_type, entity_id, description)
     VALUES ($1, $2, 'attendance.marked', 'user', $1, $3)`,
    [userId, projectId || null, `Marked ${workMode.replace('_', ' ')} for today`]
  ).catch(() => {});

  return result.rows[0];
}

async function checkOut(userId) {
  const existing = await query(
    `SELECT * FROM worker_attendance WHERE user_id = $1 AND date = CURRENT_DATE`,
    [userId]
  );
  if (existing.rows.length === 0 || !existing.rows[0].check_in_time) {
    throw Object.assign(new Error('No check-in found for today.'), { statusCode: 400 });
  }
  if (existing.rows[0].check_out_time) {
    throw Object.assign(new Error('Already checked out today.'), { statusCode: 400 });
  }

  const checkIn = new Date(existing.rows[0].check_in_time);
  const hours = Math.round(((Date.now() - checkIn.getTime()) / (1000 * 60 * 60)) * 100) / 100;

  const result = await query(
    `UPDATE worker_attendance
     SET check_out_time = NOW(), hours_worked = $1, updated_at = NOW()
     WHERE user_id = $2 AND date = CURRENT_DATE
     RETURNING *`,
    [hours, userId]
  );
  return { ...result.rows[0], hours_worked: hours };
}

async function adminMarkAttendance(targetUserId, date, workMode, notes, adminId) {
  const result = await query(
    `INSERT INTO worker_attendance
       (user_id, date, work_mode, notes, marked_by)
     VALUES ($1, $2, $3, $4, $5)
     ON CONFLICT (user_id, date)
     DO UPDATE SET
       work_mode = EXCLUDED.work_mode,
       notes = EXCLUDED.notes,
       marked_by = EXCLUDED.marked_by,
       updated_at = NOW()
     RETURNING *`,
    [targetUserId, date, workMode, notes || null, adminId]
  );
  return result.rows[0];
}

async function getWorkerAttendance(userId, fromDate, toDate) {
  const result = await query(
    `SELECT wa.*, p.project_name
     FROM worker_attendance wa
     LEFT JOIN projects p ON p.id = wa.project_id
     WHERE wa.user_id = $1 AND wa.date BETWEEN $2 AND $3
     ORDER BY wa.date DESC`,
    [userId, fromDate, toDate]
  );
  return result.rows;
}

async function getTodayAttendance(userId) {
  const result = await query(
    `SELECT wa.*, p.project_name
     FROM worker_attendance wa
     LEFT JOIN projects p ON p.id = wa.project_id
     WHERE wa.user_id = $1 AND wa.date = CURRENT_DATE`,
    [userId]
  );
  return result.rows[0] || null;
}

async function getAllTodayAttendance() {
  const result = await query(
    `SELECT
       u.id, u.full_name, u.worker_status, u.monthly_salary,
       wa.work_mode, wa.check_in_time, wa.check_out_time,
       wa.hours_worked, wa.project_id, p.project_name
     FROM users u
     LEFT JOIN worker_attendance wa ON wa.user_id = u.id AND wa.date = CURRENT_DATE
     LEFT JOIN projects p ON p.id = wa.project_id
     WHERE u.role = 'worker' AND u.status = 'approved'
     ORDER BY u.full_name ASC`
  );
  return result.rows;
}

async function getMonthAttendanceSummary(userId, monthYear) {
  const result = await query(
    `SELECT
       COUNT(*) FILTER (WHERE work_mode = 'at_site')::int AS days_at_site,
       COUNT(*) FILTER (WHERE work_mode = 'workshop')::int AS days_workshop,
       COUNT(*) FILTER (WHERE work_mode = 'leave')::int AS days_leave,
       COUNT(*) FILTER (WHERE work_mode = 'absent')::int AS days_absent,
       COUNT(*) FILTER (WHERE work_mode IN ('at_site', 'workshop', 'leave'))::int AS days_present,
       COALESCE(SUM(hours_worked), 0)::numeric AS total_hours
     FROM worker_attendance
     WHERE user_id = $1 AND TO_CHAR(date, 'YYYY-MM') = $2`,
    [userId, monthYear]
  );
  return result.rows[0];
}

// ─── SALARY PROFILE ──────────────────────────────────────────────

async function setWorkerSalary(workerId, monthlySalary, workingDaysPerMonth) {
  const result = await query(
    `UPDATE users
     SET monthly_salary = $1, working_days_per_month = COALESCE($2, 26), updated_at = NOW()
     WHERE id = $3 AND role = 'worker'
     RETURNING id, full_name, monthly_salary, working_days_per_month`,
    [monthlySalary, workingDaysPerMonth || 26, workerId]
  );
  if (result.rows.length === 0) {
    throw Object.assign(new Error('Worker not found'), { statusCode: 404 });
  }
  return result.rows[0];
}

// ─── PAYMENTS ────────────────────────────────────────────────────

async function calculateMonthlySalary(userId, monthYear) {
  const [workerResult, attendanceResult, paymentsResult] = await Promise.all([
    query(`SELECT full_name, monthly_salary, working_days_per_month FROM users WHERE id = $1`, [userId]),
    getMonthAttendanceSummary(userId, monthYear),
    query(
      `SELECT payment_type, SUM(amount)::numeric as total
       FROM worker_payments
       WHERE user_id = $1 AND month_year = $2
       GROUP BY payment_type`,
      [userId, monthYear]
    ),
  ]);

  if (workerResult.rows.length === 0) throw Object.assign(new Error('Worker not found'), { statusCode: 404 });

  const worker = workerResult.rows[0];
  const attendance = attendanceResult;
  const monthlyRate = parseFloat(worker.monthly_salary) || 0;
  const workingDays = worker.working_days_per_month || 26;
  const dailyRate = workingDays > 0 ? monthlyRate / workingDays : 0;
  const daysPresent = parseInt(attendance.days_present) || 0;
  const grossEarned = Math.round(dailyRate * daysPresent * 100) / 100;

  const paymentsMap = {};
  paymentsResult.rows.forEach(r => { paymentsMap[r.payment_type] = parseFloat(r.total) || 0; });

  const totalAdvances = paymentsMap['advance'] || 0;
  const totalBonuses = paymentsMap['bonus'] || 0;
  const netPayable = Math.round((grossEarned - totalAdvances + totalBonuses) * 100) / 100;

  return {
    worker_name: worker.full_name,
    month_year: monthYear,
    monthly_rate: monthlyRate,
    daily_rate: Math.round(dailyRate * 100) / 100,
    working_days_setting: workingDays,
    days_at_site: parseInt(attendance.days_at_site) || 0,
    days_workshop: parseInt(attendance.days_workshop) || 0,
    days_leave: parseInt(attendance.days_leave) || 0,
    days_absent: parseInt(attendance.days_absent) || 0,
    days_present: daysPresent,
    total_hours: parseFloat(attendance.total_hours) || 0,
    gross_earned: grossEarned,
    total_advances: totalAdvances,
    total_bonuses: totalBonuses,
    net_payable: netPayable,
  };
}

async function addPayment(userId, { paymentType, amount, monthYear, notes, proofImageUrl }, adminId) {
  let days_present = null, days_absent = null, daily_rate = null,
      gross_earned = null, total_advances = null, total_bonuses = null, net_payable = null;

  if (paymentType === 'salary') {
    const calc = await calculateMonthlySalary(userId, monthYear);
    days_present = calc.days_present;
    days_absent = calc.days_absent;
    daily_rate = calc.daily_rate;
    gross_earned = calc.gross_earned;
    total_advances = calc.total_advances;
    total_bonuses = calc.total_bonuses;
    net_payable = calc.net_payable;
  }

  const result = await query(
    `INSERT INTO worker_payments
       (user_id, payment_type, amount, month_year, days_present, days_absent,
        daily_rate, gross_earned, total_advances, total_bonuses, net_payable,
        proof_image_url, notes, paid_by)
     VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14)
     RETURNING *`,
    [userId, paymentType, amount, monthYear, days_present, days_absent,
     daily_rate, gross_earned, total_advances, total_bonuses, net_payable,
     proofImageUrl || null, notes || null, adminId]
  );

  await query(
    `INSERT INTO activity_logs (user_id, action, entity_type, entity_id, description)
     VALUES ($1, 'payroll.payment', 'worker_payment', $2, $3)`,
    [adminId, result.rows[0].id,
     `${paymentType.charAt(0).toUpperCase()+paymentType.slice(1)} ₹${amount} recorded`]
  ).catch(() => {});

  return result.rows[0];
}

async function getWorkerPayments(userId, monthYear) {
  const params = [userId];
  let monthFilter = '';
  if (monthYear) {
    params.push(monthYear);
    monthFilter = `AND month_year = $${params.length}`;
  }
  const result = await query(
    `SELECT wp.*, u.full_name as paid_by_name
     FROM worker_payments wp
     JOIN users u ON u.id = wp.paid_by
     WHERE wp.user_id = $1 ${monthFilter}
     ORDER BY wp.paid_at DESC`,
    params
  );
  return result.rows;
}

async function getAllWorkersSalarySummary(monthYear) {
  const result = await query(
    `SELECT
       u.id, u.full_name, u.monthly_salary, u.working_days_per_month,
       COUNT(wa.id) FILTER (WHERE wa.work_mode IN ('at_site','workshop','leave'))::int AS days_present,
       COUNT(wa.id) FILTER (WHERE wa.work_mode = 'absent')::int AS days_absent,
       COALESCE(SUM(wp.amount) FILTER (WHERE wp.payment_type = 'advance'), 0)::numeric AS total_advances,
       COALESCE(SUM(wp.amount) FILTER (WHERE wp.payment_type = 'bonus'), 0)::numeric AS total_bonuses,
       COALESCE(SUM(wp.amount) FILTER (WHERE wp.payment_type = 'salary'), 0)::numeric AS salary_paid
     FROM users u
     LEFT JOIN worker_attendance wa
       ON wa.user_id = u.id AND TO_CHAR(wa.date, 'YYYY-MM') = $1
     LEFT JOIN worker_payments wp
       ON wp.user_id = u.id AND wp.month_year = $1
     WHERE u.role = 'worker' AND u.status = 'approved'
     GROUP BY u.id, u.full_name, u.monthly_salary, u.working_days_per_month
     ORDER BY u.full_name ASC`,
    [monthYear]
  );
  return result.rows;
}

module.exports = {
  markAttendance, checkOut, adminMarkAttendance,
  getWorkerAttendance, getTodayAttendance, getAllTodayAttendance,
  getMonthAttendanceSummary, setWorkerSalary, calculateMonthlySalary,
  addPayment, getWorkerPayments, getAllWorkersSalarySummary,
};
