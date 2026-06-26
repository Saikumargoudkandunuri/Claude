'use strict';

const { query } = require('../../db/pool');
const { ApiError } = require('../../utils/http');
const { logActivity } = require('../../utils/activity');

function haversineMeters(lat1, lng1, lat2, lng2) {
  const R = 6371000;
  const dLat = (lat2 - lat1) * Math.PI / 180;
  const dLng = (lng2 - lng1) * Math.PI / 180;
  const a = Math.sin(dLat / 2) ** 2 +
    Math.cos(lat1 * Math.PI / 180) * Math.cos(lat2 * Math.PI / 180) * Math.sin(dLng / 2) ** 2;
  return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

async function checkIn(userId, { latitude, longitude, projectId }) {
  // Check if already checked in today
  const existing = await query(
    `SELECT id FROM attendance_records
     WHERE user_id = $1 AND check_out_at IS NULL AND check_in_at::date = CURRENT_DATE`,
    [userId]
  );
  if (existing.rows.length > 0) {
    throw ApiError.conflict('Already checked in today. Check out first.');
  }

  let locationType = 'unknown';
  let isWithinGeofence = false;

  if (projectId && latitude && longitude) {
    const { rows } = await query(
      'SELECT site_latitude, site_longitude, site_radius_meters FROM projects WHERE id = $1',
      [projectId]
    );
    const project = rows[0];
    if (project && project.site_latitude && project.site_longitude) {
      const distance = haversineMeters(
        latitude, longitude,
        project.site_latitude, project.site_longitude
      );
      const radius = project.site_radius_meters || 300;
      isWithinGeofence = distance <= radius;
      locationType = isWithinGeofence ? 'site' : 'unknown';
    }
  }

  // Update worker status
  const newStatus = isWithinGeofence ? 'at_site' : 'workshop';
  await query('UPDATE users SET worker_status = $1 WHERE id = $2', [newStatus, userId]);

  // Insert attendance record
  const { rows } = await query(
    `INSERT INTO attendance_records
       (user_id, project_id, check_in_lat, check_in_lng, location_type, is_within_geofence)
     VALUES ($1, $2, $3, $4, $5, $6)
     RETURNING *`,
    [userId, projectId || null, latitude || null, longitude || null, locationType, isWithinGeofence]
  );

  await logActivity({
    userId,
    projectId: projectId || null,
    action: 'attendance.check_in',
    entityType: 'attendance',
    entityId: rows[0].id,
    description: `Checked in${isWithinGeofence ? ' at site' : ''}`,
  });

  // Emit socket event
  const io = global.__io;
  if (io) {
    const userRes = await query('SELECT full_name FROM users WHERE id = $1', [userId]);
    io.to('admin_room').emit('worker_status_changed', {
      userId, status: newStatus, name: userRes.rows[0]?.full_name,
    });
  }

  return { ...rows[0], isWithinGeofence, locationType };
}

async function checkOut(userId, { latitude, longitude }) {
  const { rows: records } = await query(
    `SELECT id, project_id FROM attendance_records
     WHERE user_id = $1 AND check_out_at IS NULL
     ORDER BY check_in_at DESC LIMIT 1`,
    [userId]
  );
  if (records.length === 0) {
    throw ApiError.badRequest('No active check-in found');
  }

  const record = records[0];
  await query(
    `UPDATE attendance_records SET check_out_at = now(), check_out_lat = $1, check_out_lng = $2
     WHERE id = $3`,
    [latitude || null, longitude || null, record.id]
  );

  await query('UPDATE users SET worker_status = $1 WHERE id = $2', ['workshop', userId]);

  await logActivity({
    userId,
    projectId: record.project_id,
    action: 'attendance.check_out',
    entityType: 'attendance',
    entityId: record.id,
    description: 'Checked out',
  });

  return { id: record.id, checkedOut: true };
}

async function myToday(userId) {
  const { rows } = await query(
    `SELECT * FROM attendance_records
     WHERE user_id = $1 AND check_in_at::date = CURRENT_DATE
     ORDER BY check_in_at DESC LIMIT 1`,
    [userId]
  );
  return rows[0] || null;
}

async function listAttendance({ date, projectId, userId, page = 1, limit = 50 }) {
  const where = [];
  const params = [];

  if (date) { params.push(date); where.push(`check_in_at::date = $${params.length}`); }
  if (projectId) { params.push(projectId); where.push(`project_id = $${params.length}`); }
  if (userId) { params.push(userId); where.push(`a.user_id = $${params.length}`); }

  const whereSql = where.length ? `WHERE ${where.join(' AND ')}` : '';
  const offset = (page - 1) * limit;

  const { rows } = await query(
    `SELECT a.*, u.full_name, p.project_name
     FROM attendance_records a
     LEFT JOIN users u ON u.id = a.user_id
     LEFT JOIN projects p ON p.id = a.project_id
     ${whereSql}
     ORDER BY a.check_in_at DESC LIMIT ${limit} OFFSET ${offset}`,
    params
  );
  return rows;
}

async function monthlySummary(targetUserId, month) {
  const startDate = month || new Date().toISOString().slice(0, 7) + '-01';
  const { rows } = await query(
    `SELECT
       COUNT(*)::int AS total_days,
       COUNT(*) FILTER (WHERE is_within_geofence)::int AS days_at_site,
       COUNT(*) FILTER (WHERE NOT is_within_geofence)::int AS days_outside,
       MIN(check_in_at) AS first_check_in,
       MAX(check_out_at) AS last_check_out
     FROM attendance_records
     WHERE user_id = $1 AND check_in_at >= $2::date AND check_in_at < ($2::date + interval '1 month')`,
    [targetUserId, startDate]
  );
  return rows[0];
}

async function getWorkerHistory(userId, days = 30) {
  const { rows } = await query(
    `SELECT 
       check_in_at::date AS date,
       check_in_at,
       check_out_at,
       CASE WHEN check_out_at IS NOT NULL 
         THEN EXTRACT(EPOCH FROM (check_out_at - check_in_at)) / 3600
         ELSE NULL 
       END AS hours_worked,
       location_type,
       is_within_geofence,
       p.project_name
     FROM attendance_records a
     LEFT JOIN projects p ON p.id = a.project_id
     WHERE a.user_id = $1 AND a.check_in_at >= CURRENT_DATE - $2::int
     ORDER BY a.check_in_at DESC`,
    [userId, days]
  );
  return rows;
}

async function getTodayStatus(userId) {
  const { rows } = await query(
    `SELECT * FROM attendance_records
     WHERE user_id = $1 AND check_in_at::date = CURRENT_DATE
     ORDER BY check_in_at DESC`,
    [userId]
  );
  
  if (rows.length === 0) {
    return { checked_in: false, hours_today: 0, record: null };
  }

  const latest = rows[0];
  const checkedIn = !latest.check_out_at;
  
  // Calculate total hours today
  let hoursToday = 0;
  for (const r of rows) {
    if (r.check_out_at) {
      hoursToday += (new Date(r.check_out_at) - new Date(r.check_in_at)) / (1000 * 60 * 60);
    } else {
      // Still checked in — count time since check-in
      hoursToday += (Date.now() - new Date(r.check_in_at)) / (1000 * 60 * 60);
    }
  }

  return {
    checked_in: checkedIn,
    hours_today: Math.round(hoursToday * 10) / 10,
    record: latest,
  };
}

module.exports = { checkIn, checkOut, myToday, getTodayStatus, getWorkerHistory, listAttendance, monthlySummary };
