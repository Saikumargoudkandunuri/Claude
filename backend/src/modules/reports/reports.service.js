'use strict';

const { query, withTransaction } = require('../../db/pool');
const { ApiError } = require('../../utils/http');
const { logActivity } = require('../../utils/activity');
const { notifyAdmins, notifyUsers } = require('../../utils/notify');
const projects = require('../projects/projects.service');

function serialize(row) {
  return {
    id: row.id,
    projectId: row.project_id,
    authorId: row.author_id,
    authorName: row.author_name,
    type: row.type,
    reportDate: row.report_date,
    workDone: row.work_done,
    pendingWork: row.pending_work,
    problems: row.problems,
    materialsNeeded: row.materials_needed,
    tomorrowNotes: row.tomorrow_notes,
    siteProgress: row.site_progress,
    createdAt: row.created_at,
  };
}

async function list(user, projectId, { date, type }) {
  const project = await projects.getAccessibleProject(user, projectId);
  const params = [projectId];
  const where = ['dr.project_id = $1'];

  if (date) {
    params.push(date);
    where.push(`dr.report_date = $${params.length}`);
  }
  if (type) {
    params.push(type);
    where.push(`dr.type = $${params.length}`);
  }

  // Workers see only their own worker reports + supervisor reports.
  if (user.role === 'worker') {
    params.push(user.id);
    where.push(`(dr.type = 'supervisor' OR dr.author_id = $${params.length})`);
  }

  const { rows } = await query(
    `SELECT dr.*, u.full_name AS author_name
       FROM daily_reports dr
       JOIN users u ON u.id = dr.author_id
      WHERE ${where.join(' AND ')}
      ORDER BY dr.report_date DESC, dr.created_at DESC`,
    params
  );
  // project reference kept for potential future scoping
  void project;
  return rows.map(serialize);
}

async function create(user, projectId, body) {
  const project = await projects.getAccessibleProject(user, projectId);

  // Role must match report type.
  if (body.type === 'worker' && user.role !== 'worker' && user.role !== 'admin') {
    throw ApiError.forbidden('Only workers submit worker reports');
  }
  if (body.type === 'supervisor' && user.role !== 'supervisor' && user.role !== 'admin') {
    throw ApiError.forbidden('Only supervisors submit supervisor reports');
  }

  const reportDate = body.reportDate || new Date().toISOString().slice(0, 10);

  return withTransaction(async (client) => {
    const { rows } = await client.query(
      `INSERT INTO daily_reports
        (project_id, author_id, type, report_date, work_done, pending_work, problems,
         materials_needed, tomorrow_notes, site_progress)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10)
       ON CONFLICT (project_id, author_id, report_date, type)
       DO UPDATE SET work_done = EXCLUDED.work_done,
                     pending_work = EXCLUDED.pending_work,
                     problems = EXCLUDED.problems,
                     materials_needed = EXCLUDED.materials_needed,
                     tomorrow_notes = EXCLUDED.tomorrow_notes,
                     site_progress = EXCLUDED.site_progress
       RETURNING *`,
      [
        projectId,
        user.id,
        body.type,
        reportDate,
        body.workDone || null,
        body.pendingWork || null,
        body.problems || null,
        body.materialsNeeded || null,
        body.tomorrowNotes || null,
        body.type === 'supervisor' ? body.siteProgress || null : null,
      ]
    );

    await logActivity(
      {
        userId: user.id,
        projectId,
        action: 'report.submit',
        entityType: 'daily_report',
        entityId: rows[0].id,
        description: `Submitted ${body.type} report for ${reportDate}`,
        metadata: { type: body.type, reportDate },
      },
      client
    );

    // Notify admins; if a worker reported, also notify the supervisor.
    await notifyAdmins(
      {
        type: 'report.submitted',
        title: 'Daily report submitted',
        body: `${project.project_name}: ${body.type} report`,
        projectId,
        data: { route: `icms://project/${projectId}` },
      },
      client
    );
    if (body.type === 'worker' && project.supervisor_id) {
      await notifyUsers(
        [project.supervisor_id],
        {
          type: 'report.submitted',
          title: 'Worker report submitted',
          body: `${project.project_name}: a worker submitted their EOD report`,
          projectId,
          data: { route: `icms://project/${projectId}` },
        },
        client
      );
    }

    return { ...serialize(rows[0]), authorName: user.full_name };
  });
}

/** Today's report status for the current user. */
async function todayForMe(user) {
  const today = new Date().toISOString().slice(0, 10);
  const type = user.role === 'supervisor' ? 'supervisor' : 'worker';
  const { rows } = await query(
    `SELECT dr.*, u.full_name AS author_name
       FROM daily_reports dr JOIN users u ON u.id = dr.author_id
      WHERE dr.author_id = $1 AND dr.report_date = $2 AND dr.type = $3`,
    [user.id, today, type]
  );
  return { date: today, submitted: rows.length > 0, reports: rows.map(serialize) };
}

async function getRecord(user, reportId) {
  const { rows } = await query('SELECT * FROM daily_reports WHERE id = $1', [reportId]);
  if (!rows[0]) throw ApiError.notFound('Report not found');
  return rows[0];
}

module.exports = { serialize, list, create, todayForMe, getRecord };
