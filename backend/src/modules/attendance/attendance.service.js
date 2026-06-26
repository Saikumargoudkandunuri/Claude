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

module.exports = { checkIn, checkOut, myToday, getTodayStatus, getWorkerHistory, listAttendance, monthlySummary, reportLocation, getPendingAlert, resolveAlert, getPendingAlerts };

/**
 * Worker reports their current location periodically.
 * If outside geofence, creates an alert for admin.
 */
async function reportLocation(userId, { latitude, longitude, projectId }) {
  if (!latitude || !longitude || !projectId) {
    return { withinGeofence: true, alert: null };
  }

  const { rows: projects } = await query(
    'SELECT site_latitude, site_longitude, site_radius_meters, project_name FROM projects WHERE id = $1',
    [projectId]
  );
  const project = projects[0];
  if (!project || !project.site_latitude || !project.site_longitude) {
    return { withinGeofence: true, alert: null };
  }

  const distance = haversineMeters(latitude, longitude, project.site_latitude, project.site_longitude);
  const radius = project.site_radius_meters || 300;
  const withinGeofence = distance <= radius;

  if (withinGeofence) {
    // Worker is back in range — auto-resolve any pending declined alerts
    await query(
      `UPDATE geofence_alerts SET status = 'resolved', resolved_at = now()
       WHERE user_id = $1 AND project_id = $2 AND status = 'declined'`,
      [userId, projectId]
    );
    return { withinGeofence: true, alert: null };
  }

  // Worker is outside geofence — check if there's already a pending alert
  const { rows: existing } = await query(
    `SELECT id, status FROM geofence_alerts
     WHERE user_id = $1 AND project_id = $2 AND status IN ('pending', 'declined')
     ORDER BY created_at DESC LIMIT 1`,
    [userId, projectId]
  );

  if (existing.length > 0) {
    // Alert already exists
    return { withinGeofence: false, alert: existing[0], distanceMeters: Math.round(distance) };
  }

  // Get active attendance record
  const { rows: attendance } = await query(
    `SELECT id FROM attendance_records
     WHERE user_id = $1 AND check_out_at IS NULL
     ORDER BY check_in_at DESC LIMIT 1`,
    [userId]
  );

  // Create new geofence alert
  const { rows: alerts } = await query(
    `INSERT INTO geofence_alerts (user_id, project_id, attendance_id, latitude, longitude, distance_meters)
     VALUES ($1, $2, $3, $4, $5, $6) RETURNING *`,
    [userId, projectId, attendance[0]?.id || null, latitude, longitude, Math.round(distance)]
  );

  // Notify admin via socket and push
  const { notifyAdmins } = require('../../utils/notify');
  const { rows: users } = await query('SELECT full_name FROM users WHERE id = $1', [userId]);
  const workerName = users[0]?.full_name || 'Worker';

  await notifyAdmins({
    type: 'geofence.violation',
    title: '⚠️ Worker left site',
    body: `${workerName} is ${Math.round(distance)}m from ${project.project_name}`,
    data: {
      route: 'icms://geofence-alert',
      alertId: alerts[0].id,
      userId,
      projectId,
      workerName,
      distance: Math.round(distance),
    },
  });

  // Socket emit for real-time admin notification
  const io = global.__io;
  if (io) {
    io.to('admin_room').emit('geofence_alert', {
      alertId: alerts[0].id,
      userId,
      workerName,
      projectId,
      projectName: project.project_name,
      distance: Math.round(distance),
      latitude,
      longitude,
    });
  }

  return { withinGeofence: false, alert: alerts[0], distanceMeters: Math.round(distance) };
}

/** Worker checks if they have any pending/declined geofence alert. */
async function getPendingAlert(userId) {
  const { rows } = await query(
    `SELECT ga.*, p.project_name
     FROM geofence_alerts ga
     JOIN projects p ON p.id = ga.project_id
     WHERE ga.user_id = $1 AND ga.status IN ('pending', 'declined')
     ORDER BY ga.created_at DESC LIMIT 1`,
    [userId]
  );
  return rows[0] || null;
}

/** Admin resolves a geofence alert (approve/decline). */
async function resolveAlert(adminId, alertId, action) {
  const { rows } = await query(
    'SELECT * FROM geofence_alerts WHERE id = $1', [alertId]
  );
  if (!rows[0]) throw ApiError.notFound('Alert not found');
  const alert = rows[0];

  const newStatus = action === 'approve' ? 'approved' : 'declined';
  await query(
    `UPDATE geofence_alerts SET status = $1, admin_id = $2, resolved_at = $3 WHERE id = $4`,
    [newStatus, adminId, action === 'approve' ? new Date() : null, alertId]
  );

  // Socket emit to worker
  const io = global.__io;
  if (io) {
    io.to(`user_${alert.user_id}`).emit('geofence_resolved', {
      alertId,
      status: newStatus,
      action,
    });
  }

  await logActivity({
    userId: adminId,
    action: `geofence.${action}`,
    entityType: 'geofence_alert',
    entityId: alertId,
    description: `Admin ${action}d geofence alert for worker`,
  });

  return { alertId, status: newStatus };
}

/** Admin gets all pending geofence alerts. */
async function getPendingAlerts() {
  const { rows } = await query(
    `SELECT ga.*, u.full_name AS worker_name, u.phone AS worker_phone, p.project_name
     FROM geofence_alerts ga
     JOIN users u ON u.id = ga.user_id
     JOIN projects p ON p.id = ga.project_id
     WHERE ga.status = 'pending'
     ORDER BY ga.created_at DESC`
  );
  return rows;
}
