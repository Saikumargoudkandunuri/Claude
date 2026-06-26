'use strict';

const { query } = require('../../db/pool');
const { notifyAdmins } = require('../../utils/notify');

/**
 * Calculate Monday of current ISO week as 'YYYY-MM-DD'.
 */
function getCurrentWeekMonday() {
  const now = new Date();
  const day = now.getDay(); // 0=Sun, 1=Mon ... 6=Sat
  const diff = day === 0 ? -6 : 1 - day; // shift to Monday
  const monday = new Date(now);
  monday.setDate(now.getDate() + diff);
  // Format using local date parts to avoid UTC timezone shift
  const year = monday.getFullYear();
  const month = String(monday.getMonth() + 1).padStart(2, '0');
  const date = String(monday.getDate()).padStart(2, '0');
  return `${year}-${month}-${date}`; // 'YYYY-MM-DD'
}

/**
 * Get current week status for a single project.
 * Returns the status record or null if not reviewed this week.
 */
async function getProjectCurrentStatus(projectId) {
  const weekStart = getCurrentWeekMonday();
  const { rows } = await query(
    `SELECT pws.*, u.full_name AS set_by_name, u.role AS set_by_role
       FROM project_weekly_status pws
       JOIN users u ON u.id = pws.set_by
      WHERE pws.project_id = $1 AND pws.week_start = $2`,
    [projectId, weekStart]
  );
  return rows[0] || null;
}

/**
 * Get status history for a project (last N weeks, default 12).
 */
async function getProjectStatusHistory(projectId, limit = 12) {
  const { rows } = await query(
    `SELECT pws.*, u.full_name AS set_by_name, u.role AS set_by_role
       FROM project_weekly_status pws
       JOIN users u ON u.id = pws.set_by
      WHERE pws.project_id = $1
      ORDER BY pws.week_start DESC
      LIMIT $2`,
    [projectId, limit]
  );
  return rows;
}

/**
 * Get current week statuses for ALL projects (admin overview).
 * Returns a map: { project_id: statusRow }
 */
async function getAllProjectsCurrentStatus() {
  const weekStart = getCurrentWeekMonday();
  const { rows } = await query(
    `SELECT pws.project_id, pws.status, pws.notes, pws.week_start,
            pws.created_at, u.full_name AS set_by_name
       FROM project_weekly_status pws
       JOIN users u ON u.id = pws.set_by
      WHERE pws.week_start = $1`,
    [weekStart]
  );
  const map = {};
  rows.forEach((row) => { map[row.project_id] = row; });
  return map;
}

/**
 * Set (upsert) status for a project for current week.
 * Supervisor can only set for their own projects.
 */
async function setProjectStatus(projectId, userId, userRole, { status, notes }) {
  // RBAC: supervisor can only set for projects they supervise
  if (userRole === 'supervisor') {
    const { rows } = await query(
      `SELECT id FROM projects WHERE id = $1 AND supervisor_id = $2`,
      [projectId, userId]
    );
    if (rows.length === 0) {
      const err = new Error('Forbidden: not your project');
      err.statusCode = 403;
      throw err;
    }
  }

  const weekStart = getCurrentWeekMonday();
  const { rows } = await query(
    `INSERT INTO project_weekly_status (project_id, status, notes, set_by, week_start)
     VALUES ($1, $2, $3, $4, $5)
     ON CONFLICT (project_id, week_start)
     DO UPDATE SET status = $2, notes = $3, set_by = $4, created_at = NOW()
     RETURNING *`,
    [projectId, status, notes || null, userId, weekStart]
  );

  // Log to activity_logs so dashboard recent updates shows this change
  try {
    const statusLabels = {
      on_track: 'On Track 🟢',
      normal: 'As Usual 🟡',
      slow: 'Slow / At Risk 🔴'
    };
    await query(
      `INSERT INTO activity_logs
        (user_id, project_id, action, entity_type, entity_id, description, metadata)
       VALUES ($1, $2, $3, $4, $5, $6, $7)`,
      [
        userId,
        projectId,
        'project.weekly_status',
        'project',
        projectId,
        `Weekly status set to ${statusLabels[status] || status}${notes ? ': ' + notes : ''}`,
        JSON.stringify({ status, notes: notes || null, week_start: weekStart })
      ]
    );
  } catch (logErr) {
    // Non-fatal — don't fail the main operation if logging fails
    console.error('Activity log failed for weekly_status:', logErr.message);
  }

  // Send push notification to all admins when a project is marked Slow
  if (status === 'slow') {
    try {
      const projectResult = await query(
        `SELECT project_name FROM projects WHERE id = $1`,
        [projectId]
      );
      const projectName = projectResult.rows[0]?.project_name || 'A project';

      const setterResult = await query(
        `SELECT full_name FROM users WHERE id = $1`,
        [userId]
      );
      const setterName = setterResult.rows[0]?.full_name || 'Someone';

      await notifyAdmins({
        type: 'weekly_status_slow',
        title: '⚠️ Site At Risk',
        body: `${projectName} marked Slow by ${setterName}`,
        projectId,
        data: { status: 'slow', week_start: weekStart },
      });
    } catch (pushErr) {
      // Non-fatal
      console.error('Push notification failed for weekly_status slow:', pushErr.message);
    }
  }

  return rows[0];
}

/**
 * Get projects needing review this week (no status set yet).
 * Admin sees all active projects, supervisor sees own only.
 */
async function getProjectsNeedingReview(userId, userRole) {
  const weekStart = getCurrentWeekMonday();
  let scopeClause = '';
  const params = [weekStart];

  if (userRole === 'supervisor') {
    params.push(userId);
    scopeClause = `AND p.supervisor_id = $${params.length}`;
  }

  const { rows } = await query(
    `SELECT p.id, p.project_name, p.project_number
       FROM projects p
      WHERE p.is_archived = false
        AND p.current_stage != 'completed'
        AND p.id NOT IN (
          SELECT project_id FROM project_weekly_status WHERE week_start = $1
        )
        ${scopeClause}
      ORDER BY p.project_name`,
    params
  );
  return rows;
}

module.exports = {
  getCurrentWeekMonday,
  getProjectCurrentStatus,
  getProjectStatusHistory,
  getAllProjectsCurrentStatus,
  setProjectStatus,
  getProjectsNeedingReview,
};
