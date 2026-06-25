'use strict';

const { asyncHandler, ok } = require('../../utils/http');
const { query } = require('../../db/pool');

const getWorkforceData = asyncHandler(async (req, res) => {
  // All approved staff
  const { rows: staff } = await query(`
    SELECT u.id, u.full_name, u.phone, u.role, u.status, u.worker_status, u.created_at,
           (SELECT COUNT(*) FROM project_assignments pa WHERE pa.user_id = u.id AND pa.active = true) AS active_projects,
           (SELECT COUNT(*) FROM daily_reports dr WHERE dr.submitted_by = u.id AND dr.created_at > now() - interval '30 days') AS reports_30d
    FROM users u
    WHERE u.status = 'approved' AND u.role IN ('worker', 'supervisor', 'designer')
    ORDER BY u.role, u.full_name
  `);

  // Workers with current site assignments
  const { rows: assignments } = await query(`
    SELECT pa.user_id, pa.role AS assignment_role, pa.task, pa.active,
           p.id AS project_id, p.project_name, p.customer_name, p.current_stage
    FROM project_assignments pa
    JOIN projects p ON p.id = pa.project_id
    WHERE pa.active = true AND p.is_archived = false
    ORDER BY p.project_name
  `);

  // Projects with worker counts
  const { rows: projectWorkforce } = await query(`
    SELECT p.id, p.project_name, p.customer_name, p.current_stage,
           COUNT(CASE WHEN pa.role = 'worker' THEN 1 END) AS worker_count,
           COUNT(CASE WHEN pa.role = 'supervisor' THEN 1 END) AS supervisor_count,
           COUNT(CASE WHEN pa.role = 'designer' THEN 1 END) AS designer_count
    FROM projects p
    LEFT JOIN project_assignments pa ON pa.project_id = p.id AND pa.active = true
    WHERE p.is_archived = false
    GROUP BY p.id
    ORDER BY p.project_name
  `);

  // Recent reports (last 7 days)
  const { rows: recentReports } = await query(`
    SELECT dr.id, dr.work_done, dr.pending_work, dr.problems, dr.materials_used,
           dr.progress_percent, dr.created_at, dr.type,
           u.full_name AS author_name, u.role AS author_role,
           p.project_name, p.customer_name
    FROM daily_reports dr
    JOIN users u ON u.id = dr.submitted_by
    JOIN projects p ON p.id = dr.project_id
    WHERE dr.created_at > now() - interval '7 days'
    ORDER BY dr.created_at DESC
    LIMIT 20
  `);

  // Summary stats
  const totalWorkers = staff.filter(s => s.role === 'worker').length;
  const atSite = staff.filter(s => s.worker_status === 'at_site').length;
  const onLeave = staff.filter(s => s.worker_status === 'leave').length;
  const inWorkshop = staff.filter(s => s.worker_status === 'workshop').length;

  ok(res, {
    summary: { totalWorkers, atSite, onLeave, inWorkshop, totalStaff: staff.length },
    staff: staff.map(s => ({
      id: s.id,
      fullName: s.full_name,
      phone: s.phone,
      role: s.role,
      workerStatus: s.worker_status,
      activeProjects: Number(s.active_projects),
      reports30d: Number(s.reports_30d),
      joinedAt: s.created_at,
    })),
    assignments: assignments.map(a => ({
      userId: a.user_id,
      assignmentRole: a.assignment_role,
      task: a.task,
      projectId: a.project_id,
      projectName: a.project_name,
      customerName: a.customer_name,
      currentStage: a.current_stage,
    })),
    projectWorkforce: projectWorkforce.map(p => ({
      id: p.id,
      projectName: p.project_name,
      customerName: p.customer_name,
      currentStage: p.current_stage,
      workerCount: Number(p.worker_count),
      supervisorCount: Number(p.supervisor_count),
      designerCount: Number(p.designer_count),
    })),
    recentReports: recentReports.map(r => ({
      id: r.id,
      workDone: r.work_done,
      pendingWork: r.pending_work,
      problems: r.problems,
      materialsUsed: r.materials_used,
      progressPercent: r.progress_percent,
      createdAt: r.created_at,
      type: r.type,
      authorName: r.author_name,
      authorRole: r.author_role,
      projectName: r.project_name,
      customerName: r.customer_name,
    })),
  });
});

module.exports = { getWorkforceData };
