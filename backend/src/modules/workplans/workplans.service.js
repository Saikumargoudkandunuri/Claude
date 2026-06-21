'use strict';

const { query, withTransaction } = require('../../db/pool');
const { ApiError } = require('../../utils/http');
const { logActivity } = require('../../utils/activity');
const { notifyUsers } = require('../../utils/notify');
const projects = require('../projects/projects.service');

async function listForProject(user, projectId, { date }) {
  await projects.getAccessibleProject(user, projectId);
  const params = [projectId];
  let sql = `
    SELECT wp.*, COALESCE(json_agg(
              json_build_object('userId', u.id, 'fullName', u.full_name)
            ) FILTER (WHERE u.id IS NOT NULL), '[]') AS workers
      FROM work_plans wp
      LEFT JOIN work_plan_workers wpw ON wpw.work_plan_id = wp.id
      LEFT JOIN users u ON u.id = wpw.user_id
     WHERE wp.project_id = $1`;
  if (date) {
    params.push(date);
    sql += ` AND wp.plan_date = $2`;
  }
  sql += ' GROUP BY wp.id ORDER BY wp.plan_date DESC';
  const { rows } = await query(sql, params);
  return rows.map((r) => ({
    id: r.id,
    projectId: r.project_id,
    planDate: r.plan_date,
    task: r.task,
    workers: r.workers,
    createdAt: r.created_at,
  }));
}

async function create(user, projectId, { planDate, task, workerIds }) {
  const project = await projects.getAccessibleProject(user, projectId);

  return withTransaction(async (client) => {
    const { rows } = await client.query(
      `INSERT INTO work_plans (project_id, plan_date, task, created_by)
       VALUES ($1,$2,$3,$4) RETURNING *`,
      [projectId, planDate, task || null, user.id]
    );
    const plan = rows[0];

    for (const workerId of [...new Set(workerIds)]) {
      await client.query(
        `INSERT INTO work_plan_workers (work_plan_id, user_id)
         VALUES ($1,$2) ON CONFLICT DO NOTHING`,
        [plan.id, workerId]
      );
    }

    await logActivity(
      {
        userId: user.id,
        projectId,
        action: 'workplan.create',
        entityType: 'work_plan',
        entityId: plan.id,
        description: `Planned work for ${planDate}`,
        metadata: { planDate, task, workerIds },
      },
      client
    );

    // Notify workers + supervisor.
    const recipients = [...workerIds];
    if (project.supervisor_id) recipients.push(project.supervisor_id);
    await notifyUsers(
      recipients,
      {
        type: 'workplan.assigned',
        title: 'Work planned',
        body: `${project.project_name} on ${planDate}${task ? ` — ${task}` : ''}`,
        projectId,
        data: { route: `icms://project/${projectId}`, planDate },
      },
      client
    );

    return { id: plan.id, projectId, planDate: plan.plan_date, task: plan.task, workerIds };
  });
}

/** Work plans assigned to the current user for a date (default tomorrow). */
async function forMe(user, date) {
  const target =
    date ||
    (() => {
      const d = new Date();
      d.setDate(d.getDate() + 1);
      return d.toISOString().slice(0, 10);
    })();

  const { rows } = await query(
    `SELECT wp.id, wp.plan_date, wp.task, p.id AS project_id, p.project_name, p.site_location
       FROM work_plan_workers wpw
       JOIN work_plans wp ON wp.id = wpw.work_plan_id
       JOIN projects p ON p.id = wp.project_id
      WHERE wpw.user_id = $1 AND wp.plan_date = $2
      ORDER BY p.project_name`,
    [user.id, target]
  );
  return {
    date: target,
    plans: rows.map((r) => ({
      id: r.id,
      planDate: r.plan_date,
      task: r.task,
      projectId: r.project_id,
      projectName: r.project_name,
      siteLocation: r.site_location,
    })),
  };
}

async function remove(user, planId) {
  const { rows } = await query('SELECT * FROM work_plans WHERE id = $1', [planId]);
  if (!rows[0]) throw ApiError.notFound('Work plan not found');
  await query('DELETE FROM work_plans WHERE id = $1', [planId]);
  await logActivity({
    userId: user.id,
    projectId: rows[0].project_id,
    action: 'workplan.delete',
    entityType: 'work_plan',
    entityId: planId,
    description: 'Deleted work plan',
  });
}

module.exports = { listForProject, create, forMe, remove };
