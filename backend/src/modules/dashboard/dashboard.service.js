'use strict';

const { query } = require('../../db/pool');
const { serialize: serializeActivity } = require('../activity/activity.service');

const today = () => new Date().toISOString().slice(0, 10);

async function recentUpdates(limit = 10, projectFilterSql = '', params = []) {
  const { rows } = await query(
    `SELECT a.*, u.full_name AS user_name
       FROM activity_logs a LEFT JOIN users u ON u.id = a.user_id
       ${projectFilterSql}
       ORDER BY a.created_at DESC LIMIT ${limit}`,
    params
  );
  return rows.map(serializeActivity);
}

async function admin() {
  const [sites, workersToday, pendingReports, pendingApprovals, payments] = await Promise.all([
    query(`
      SELECT
        COUNT(*)::int AS total,
        COUNT(*) FILTER (WHERE current_stage <> 'completed')::int AS active,
        COUNT(*) FILTER (WHERE current_stage = 'completed')::int AS completed
      FROM projects WHERE is_archived = false`),
    query(
      `SELECT COUNT(DISTINCT user_id)::int AS c
         FROM work_plan_workers wpw
         JOIN work_plans wp ON wp.id = wpw.work_plan_id
        WHERE wp.plan_date = $1`,
      [today()]
    ),
    // Assigned workers without a worker report today.
    query(
      `SELECT COUNT(*)::int AS c FROM (
         SELECT DISTINCT pa.user_id, pa.project_id
           FROM project_assignments pa
          WHERE pa.role = 'worker' AND pa.active = true
       ) a
       WHERE NOT EXISTS (
         SELECT 1 FROM daily_reports dr
          WHERE dr.author_id = a.user_id AND dr.project_id = a.project_id
            AND dr.type = 'worker' AND dr.report_date = $1
       )`,
      [today()]
    ),
    query(`SELECT COUNT(*)::int AS c FROM users WHERE status = 'pending'`),
    query(`
      SELECT
        COALESCE(SUM(total_received),0) AS received,
        COALESCE(SUM(quotation_amount - total_received),0) AS outstanding,
        COUNT(*) FILTER (WHERE quotation_amount - total_received > 0)::int AS pending_count
      FROM payments`),
  ]);

  // Stage distribution for the dashboard graph.
  const stageRows = await query(
    `SELECT current_stage AS stage, COUNT(*)::int AS count
       FROM projects WHERE is_archived = false
      GROUP BY current_stage`
  );
  const stageDistribution = {};
  for (const r of stageRows.rows) stageDistribution[r.stage] = r.count;

  // Active workers (currently at a site) + count of assignments planned today.
  const activeWorkersRes = await query(
    `SELECT COUNT(*)::int AS c FROM users WHERE role = 'worker' AND worker_status = 'at_site'`
  );
  const todaysAssignmentsRes = await query(
    `SELECT COUNT(*)::int AS c FROM work_plans WHERE plan_date = $1`,
    [today()]
  );

  // Project summary cards (most recent active projects).
  const recentProjects = await query(
    `SELECT p.id, p.project_number, p.project_name, p.customer_name, p.current_stage,
            COALESCE(pay.quotation_amount,0) AS quotation_amount,
            COALESCE(pay.total_received,0) AS total_received
       FROM projects p
       LEFT JOIN payments pay ON pay.project_id = p.id
      WHERE p.is_archived = false
      ORDER BY p.created_at DESC LIMIT 8`
  );

  return {
    totalSites: sites.rows[0].total,
    activeSites: sites.rows[0].active,
    completedSites: sites.rows[0].completed,
    workersToday: workersToday.rows[0].c,
    activeWorkers: activeWorkersRes.rows[0].c,
    todaysAssignments: todaysAssignmentsRes.rows[0].c,
    pendingReports: pendingReports.rows[0].c,
    pendingApprovals: pendingApprovals.rows[0].c,
    pendingPayments: payments.rows[0].pending_count,
    amountReceived: Number(payments.rows[0].received),
    outstandingAmount: Number(payments.rows[0].outstanding),
    stageDistribution,
    projects: recentProjects.rows.map((r) => ({
      id: r.id,
      projectNumber: r.project_number,
      projectName: r.project_name,
      customerName: r.customer_name,
      currentStage: r.current_stage,
      quotationAmount: Number(r.quotation_amount),
      totalReceived: Number(r.total_received),
    })),
    recentUpdates: await recentUpdates(10),
  };
}

async function supervisor(userId) {
  const [mySites, todaysWork, pendingReports, workersRows] = await Promise.all([
    query(
      `SELECT COUNT(*)::int AS c FROM projects WHERE supervisor_id = $1 AND is_archived = false`,
      [userId]
    ),
    query(
      `SELECT wp.id, wp.task, wp.plan_date, p.id AS project_id, p.project_name, p.site_location
         FROM work_plans wp JOIN projects p ON p.id = wp.project_id
        WHERE p.supervisor_id = $1 AND wp.plan_date = $2
        ORDER BY p.project_name`,
      [userId, today()]
    ),
    query(
      `SELECT COUNT(*)::int AS c FROM daily_reports
        WHERE author_id = $1 AND type = 'supervisor' AND report_date = $2`,
      [userId, today()]
    ),
    // Workers assigned to this supervisor's projects.
    query(
      `SELECT DISTINCT u.id AS user_id, u.full_name, u.worker_status,
              p.project_name, p.site_location, pa.task
         FROM project_assignments pa
         JOIN projects p ON p.id = pa.project_id
         JOIN users u ON u.id = pa.user_id
        WHERE p.supervisor_id = $1 AND pa.role = 'worker' AND pa.active = true
        ORDER BY u.full_name`,
      [userId]
    ),
  ]);

  return {
    mySites: mySites.rows[0].c,
    todaysWork: todaysWork.rows.map((r) => ({
      id: r.id,
      task: r.task,
      planDate: r.plan_date,
      projectId: r.project_id,
      projectName: r.project_name,
      siteLocation: r.site_location,
    })),
    reportSubmittedToday: pendingReports.rows[0].c > 0,
    workers: workersRows.rows.map((r) => ({
      userId: r.user_id,
      fullName: r.full_name,
      status: r.worker_status,
      projectName: r.project_name,
      siteLocation: r.site_location,
      task: r.task,
    })),
    recentUpdates: await recentUpdates(
      10,
      `WHERE a.project_id IN (SELECT id FROM projects WHERE supervisor_id = $1)`,
      [userId]
    ),
  };
}

async function designer(userId) {
  const needingDesign = await query(
    `SELECT id, project_number, project_name, current_stage
       FROM projects
      WHERE current_stage IN ('discussion','3d_design','drawing')
        AND is_archived = false
      ORDER BY created_at DESC LIMIT 25`
  );
  const recentUploads = await query(
    `SELECT f.id, f.category, f.original_name, f.created_at, p.project_name
       FROM files f JOIN projects p ON p.id = f.project_id
      WHERE f.uploaded_by = $1
        AND f.category IN ('3d_design','working_drawing','measurement_drawing','site_drawing','pdf_drawing','quotation')
      ORDER BY f.created_at DESC LIMIT 10`,
    [userId]
  );
  return {
    sitesNeedingDesign: needingDesign.rows.map((r) => ({
      id: r.id,
      projectNumber: r.project_number,
      projectName: r.project_name,
      currentStage: r.current_stage,
    })),
    recentUploads: recentUploads.rows.map((r) => ({
      id: r.id,
      category: r.category,
      originalName: r.original_name,
      projectName: r.project_name,
      createdAt: r.created_at,
    })),
  };
}

async function worker(userId) {
  const tomorrow = (() => {
    const d = new Date();
    d.setDate(d.getDate() + 1);
    return d.toISOString().slice(0, 10);
  })();

  const [assigned, todays, tomorrowRows, reportToday, recentDrawings] = await Promise.all([
    query(
      `SELECT DISTINCT p.id, p.project_name, p.site_location, p.current_stage, pa.task
         FROM project_assignments pa JOIN projects p ON p.id = pa.project_id
        WHERE pa.user_id = $1 AND pa.role = 'worker' AND pa.active = true
        ORDER BY p.project_name`,
      [userId]
    ),
    query(
      `SELECT wp.id, wp.task, wpw.status, wpw.started_at, wpw.completed_at,
              p.id AS project_id, p.project_name, p.site_location
         FROM work_plan_workers wpw
         JOIN work_plans wp ON wp.id = wpw.work_plan_id
         JOIN projects p ON p.id = wp.project_id
        WHERE wpw.user_id = $1 AND wp.plan_date = $2`,
      [userId, today()]
    ),
    query(
      `SELECT wp.id, wp.task, wpw.status,
              p.id AS project_id, p.project_name, p.site_location
         FROM work_plan_workers wpw
         JOIN work_plans wp ON wp.id = wpw.work_plan_id
         JOIN projects p ON p.id = wp.project_id
        WHERE wpw.user_id = $1 AND wp.plan_date = $2`,
      [userId, tomorrow]
    ),
    query(
      `SELECT COUNT(*)::int AS c FROM daily_reports
        WHERE author_id = $1 AND type = 'worker' AND report_date = $2`,
      [userId, today()]
    ),
    query(
      `SELECT f.id, f.category, f.original_name, p.project_name
         FROM files f JOIN projects p ON p.id = f.project_id
        WHERE f.project_id IN (
                SELECT project_id FROM project_assignments
                 WHERE user_id = $1 AND role = 'worker' AND active = true)
          AND f.category IN ('working_drawing','measurement_drawing','site_drawing','pdf_drawing')
        ORDER BY f.created_at DESC LIMIT 10`,
      [userId]
    ),
  ]);

  const mapTask = (r) => ({
    id: r.id,
    task: r.task,
    status: r.status,
    startedAt: r.started_at,
    completedAt: r.completed_at,
    projectId: r.project_id,
    projectName: r.project_name,
    siteLocation: r.site_location,
  });

  // Supervisor + admin contacts the worker is allowed to see.
  const contactsRes = await query(
    `SELECT DISTINCT u.full_name, u.phone, u.role
       FROM users u
      WHERE (u.role = 'admin' AND u.status = 'approved')
         OR u.id IN (
              SELECT p.supervisor_id FROM projects p
               JOIN project_assignments pa ON pa.project_id = p.id
              WHERE pa.user_id = $1 AND pa.role = 'worker' AND pa.active = true
                AND p.supervisor_id IS NOT NULL
            )
      ORDER BY u.role`,
    [userId]
  );

  // Recent work history for this worker (their own activity).
  const historyRes = await query(
    `SELECT a.action, a.description, a.created_at, p.project_name
       FROM activity_logs a
       LEFT JOIN projects p ON p.id = a.project_id
      WHERE a.user_id = $1
      ORDER BY a.created_at DESC LIMIT 15`,
    [userId]
  );

  return {
    assignedSites: assigned.rows.map((r) => ({
      id: r.id,
      projectName: r.project_name,
      siteLocation: r.site_location,
      currentStage: r.current_stage,
      task: r.task,
    })),
    todaysWork: todays.rows.map(mapTask),
    tomorrowWork: tomorrowRows.rows.map(mapTask),
    reportDueToday: reportToday.rows[0].c === 0,
    contacts: contactsRes.rows.map((r) => ({
      name: r.full_name,
      phone: r.phone,
      role: r.role,
    })),
    recentWork: historyRes.rows.map((r) => ({
      action: r.action,
      description: r.description,
      projectName: r.project_name,
      createdAt: r.created_at,
    })),
    recentDrawings: recentDrawings.rows.map((r) => ({
      id: r.id,
      category: r.category,
      originalName: r.original_name,
      projectName: r.project_name,
    })),
  };
}

module.exports = { admin, supervisor, designer, worker };
