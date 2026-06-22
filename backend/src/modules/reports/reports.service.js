'use strict';

const { query, withTransaction } = require('../../db/pool');
const { ApiError } = require('../../utils/http');
const { logActivity } = require('../../utils/activity');
const { notifyAdmins, notifyUsers } = require('../../utils/notify');
const projects = require('../projects/projects.service');

function fileBaseUrl() {
  return process.env.API_PREFIX || '/api/v1';
}

function serialize(row, media = []) {
  return {
    id: row.id,
    projectId: row.project_id,
    projectName: row.project_name,
    authorId: row.author_id,
    authorName: row.author_name,
    authorRole: row.author_role,
    type: row.type,
    reportDate: row.report_date,
    workDone: row.work_done,
    pendingWork: row.pending_work,
    problems: row.problems,
    materialsNeeded: row.materials_needed,
    materialsUsed: row.materials_used,
    tomorrowNotes: row.tomorrow_notes,
    progressPercent: row.progress_percent,
    siteProgress: row.site_progress,
    createdAt: row.created_at,
    media,
  };
}

/** Fetch media files attached to a set of report ids, grouped by report. */
async function mediaForReports(reportIds) {
  if (reportIds.length === 0) return {};
  const { rows } = await query(
    `SELECT id, report_id, category, original_name, mime_type, size_bytes, created_at
       FROM files WHERE report_id = ANY($1::uuid[]) ORDER BY created_at ASC`,
    [reportIds]
  );
  const base = fileBaseUrl();
  const grouped = {};
  for (const f of rows) {
    (grouped[f.report_id] ||= []).push({
      id: f.id,
      category: f.category,
      originalName: f.original_name,
      mimeType: f.mime_type,
      sizeBytes: f.size_bytes ? Number(f.size_bytes) : null,
      downloadUrl: `${base}/files/${f.id}/download`,
      createdAt: f.created_at,
    });
  }
  return grouped;
}

async function attachMedia(rows) {
  const media = await mediaForReports(rows.map((r) => r.id));
  return rows.map((r) => serialize(r, media[r.id] || []));
}

async function list(user, projectId, { date, type }) {
  await projects.getAccessibleProject(user, projectId);
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
    `SELECT dr.*, u.full_name AS author_name, u.role AS author_role
       FROM daily_reports dr
       JOIN users u ON u.id = dr.author_id
      WHERE ${where.join(' AND ')}
      ORDER BY dr.report_date DESC, dr.created_at DESC`,
    params
  );
  return attachMedia(rows);
}

/**
 * All reports across projects (admin sees everything, supervisor sees reports
 * for projects they supervise). Paginated.
 */
async function listAll(user, { date, type, projectId, page, limit }) {
  const params = [];
  const where = [];

  if (user.role === 'supervisor') {
    params.push(user.id);
    where.push(`p.supervisor_id = $${params.length}`);
  }
  if (projectId) {
    params.push(projectId);
    where.push(`dr.project_id = $${params.length}`);
  }
  if (date) {
    params.push(date);
    where.push(`dr.report_date = $${params.length}`);
  }
  if (type) {
    params.push(type);
    where.push(`dr.type = $${params.length}`);
  }
  const whereSql = where.length ? `WHERE ${where.join(' AND ')}` : '';
  const offset = (page - 1) * limit;

  const total = await query(
    `SELECT COUNT(*)::int AS total
       FROM daily_reports dr JOIN projects p ON p.id = dr.project_id ${whereSql}`,
    params
  );
  const { rows } = await query(
    `SELECT dr.*, u.full_name AS author_name, u.role AS author_role, p.project_name
       FROM daily_reports dr
       JOIN users u ON u.id = dr.author_id
       JOIN projects p ON p.id = dr.project_id
       ${whereSql}
      ORDER BY dr.report_date DESC, dr.created_at DESC
      LIMIT ${limit} OFFSET ${offset}`,
    params
  );
  return { data: await attachMedia(rows), meta: { page, limit, total: total.rows[0].total } };
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

  const created = await withTransaction(async (client) => {
    const { rows } = await client.query(
      `INSERT INTO daily_reports
        (project_id, author_id, type, report_date, work_done, pending_work, problems,
         materials_needed, materials_used, tomorrow_notes, progress_percent, site_progress)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12)
       ON CONFLICT (project_id, author_id, report_date, type)
       DO UPDATE SET work_done = EXCLUDED.work_done,
                     pending_work = EXCLUDED.pending_work,
                     problems = EXCLUDED.problems,
                     materials_needed = EXCLUDED.materials_needed,
                     materials_used = EXCLUDED.materials_used,
                     tomorrow_notes = EXCLUDED.tomorrow_notes,
                     progress_percent = EXCLUDED.progress_percent,
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
        body.materialsUsed || null,
        body.tomorrowNotes || null,
        body.progressPercent ?? null,
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
        metadata: { type: body.type, reportDate, progressPercent: body.progressPercent ?? null },
      },
      client
    );

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
          body: `${project.project_name}: a worker submitted their report`,
          projectId,
          data: { route: `icms://project/${projectId}` },
        },
        client
      );
    }

    return rows[0];
  });

  return {
    ...serialize(created),
    authorName: user.full_name,
    authorRole: user.role,
  };
}

/** Today's report status for the current user. */
async function todayForMe(user) {
  const today = new Date().toISOString().slice(0, 10);
  const type = user.role === 'supervisor' ? 'supervisor' : 'worker';
  const { rows } = await query(
    `SELECT dr.*, u.full_name AS author_name, u.role AS author_role
       FROM daily_reports dr JOIN users u ON u.id = dr.author_id
      WHERE dr.author_id = $1 AND dr.report_date = $2 AND dr.type = $3`,
    [user.id, today, type]
  );
  return { date: today, submitted: rows.length > 0, reports: await attachMedia(rows) };
}

async function getRecord(user, reportId) {
  const { rows } = await query('SELECT * FROM daily_reports WHERE id = $1', [reportId]);
  if (!rows[0]) throw ApiError.notFound('Report not found');
  return rows[0];
}

module.exports = { serialize, list, listAll, create, todayForMe, getRecord };
