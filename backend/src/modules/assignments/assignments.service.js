'use strict';

const { query, withTransaction } = require('../../db/pool');
const { ApiError } = require('../../utils/http');
const { logActivity } = require('../../utils/activity');
const { notifyUsers } = require('../../utils/notify');
const projects = require('../projects/projects.service');

function endOfDay(dateStr) {
  // Expire at 23:59:59 of the valid date (server time).
  return new Date(`${dateStr}T23:59:59`);
}

/**
 * Create an assignment brief: assigns a worker for a day, posts a WhatsApp-style
 * message that is auto-injected into the project report timeline as an
 * 'assignment_brief', visible to the worker only until 23:59:59 of that day.
 */
async function createBrief(user, projectId, { workerId, date, body, tasks }) {
  const project = await projects.getAccessibleProject(user, projectId);
  if (!['admin', 'supervisor'].includes(user.role)) {
    throw ApiError.forbidden('Only admin or supervisor can create assignments');
  }
  const validDate = date || new Date().toISOString().slice(0, 10);
  const taskText = Array.isArray(tasks) && tasks.length ? tasks.join('\n• ') : null;
  const fullBody = [body, taskText ? `• ${taskText}` : null].filter(Boolean).join('\n');

  const result = await withTransaction(async (client) => {
    // 1. Ensure the worker is assigned to the project.
    const assignRes = await client.query(
      `INSERT INTO project_assignments (project_id, user_id, role, task, assigned_by, active)
       VALUES ($1,$2,'worker',$3,$4,true)
       ON CONFLICT (project_id, user_id, role)
       DO UPDATE SET active = true, task = EXCLUDED.task, assigned_by = EXCLUDED.assigned_by
       RETURNING id`,
      [projectId, workerId, taskText, user.id]
    );
    const assignmentId = assignRes.rows[0].id;

    // 2. Inject an assignment-brief report into the timeline.
    const reportRes = await client.query(
      `INSERT INTO daily_reports
        (project_id, author_id, type, report_date, work_done, is_assignment_brief, assignment_id)
       VALUES ($1,$2,'assignment_brief',$3,$4,true,$5)
       RETURNING *`,
      [projectId, user.id, validDate, fullBody || null, assignmentId]
    );
    const report = reportRes.rows[0];

    // 3. Store the assignment message with daily expiry.
    const msgRes = await client.query(
      `INSERT INTO assignment_messages
        (project_id, assignment_id, report_id, author_id, worker_id, body, valid_date, expires_at)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8)
       RETURNING *`,
      [projectId, assignmentId, report.id, user.id, workerId, fullBody || null, validDate, endOfDay(validDate)]
    );

    await logActivity(
      {
        userId: user.id,
        projectId,
        action: 'assignment.brief',
        entityType: 'assignment',
        entityId: assignmentId,
        description: `Assigned worker for ${validDate}`,
        metadata: { workerId, validDate },
      },
      client
    );

    return { reportId: report.id, messageId: msgRes.rows[0].id, assignmentId };
  });

  // 4. Push notification to the worker.
  await notifyUsers([workerId], {
    type: 'assignment.brief',
    title: `New task for ${validDate}`,
    body: fullBody ? fullBody.slice(0, 120) : `${project.project_name}: new assignment`,
    projectId,
    data: { route: `/worker/sites/${projectId}`, project_id: projectId },
  });

  return result;
}

/**
 * List assignment messages for a project/date.
 * Worker: only their own brief AND only while it is still valid (today + not expired).
 * Admin/Supervisor: all briefs for the date (full history, no expiry filter).
 */
async function listBriefs(user, projectId, { date }) {
  await projects.getAccessibleProject(user, projectId);
  const targetDate = date || new Date().toISOString().slice(0, 10);
  const params = [projectId, targetDate];
  let sql = `
    SELECT am.*, u.full_name AS author_name, w.full_name AS worker_name
      FROM assignment_messages am
      JOIN users u ON u.id = am.author_id
      LEFT JOIN users w ON w.id = am.worker_id
     WHERE am.project_id = $1 AND am.valid_date = $2 AND am.is_deleted = false`;

  if (user.role === 'worker') {
    params.push(user.id);
    sql += ` AND am.worker_id = $${params.length} AND am.expires_at > now()`;
  }
  sql += ' ORDER BY am.created_at DESC';

  const { rows } = await query(sql, params);
  return rows.map((r) => ({
    id: r.id,
    projectId: r.project_id,
    assignmentId: r.assignment_id,
    reportId: r.report_id,
    authorId: r.author_id,
    authorName: r.author_name,
    workerId: r.worker_id,
    workerName: r.worker_name,
    body: r.body,
    validDate: r.valid_date,
    expiresAt: r.expires_at,
    isExpired: new Date(r.expires_at) <= new Date(),
    createdAt: r.created_at,
  }));
}

module.exports = { createBrief, listBriefs };
