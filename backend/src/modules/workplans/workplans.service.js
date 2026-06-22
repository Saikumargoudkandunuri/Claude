'use strict';

const { query, withTransaction } = require('../../db/pool');
const { ApiError } = require('../../utils/http');
const { logActivity } = require('../../utils/activity');
const { notifyUsers, notifyAdmins } = require('../../utils/notify');
const projects = require('../projects/projects.service');

const WORKERS_JSON = `
  COALESCE(json_agg(
    json_build_object(
      'userId', u.id, 'fullName', u.full_name,
      'status', wpw.status, 'startedAt', wpw.started_at, 'completedAt', wpw.completed_at
    ) ORDER BY u.full_name
  ) FILTER (WHERE u.id IS NOT NULL), '[]') AS workers`;

function serializePlan(r) {
  return {
    id: r.id,
    projectId: r.project_id,
    projectName: r.project_name,
    planDate: r.plan_date,
    task: r.task,
    workers: r.workers,
    createdAt: r.created_at,
  };
}

async function listForProject(user, projectId, { date }) {
  await projects.getAccessibleProject(user, projectId);
  const params = [projectId];
  let sql = `
    SELECT wp.*, ${WORKERS_JSON}
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
  return rows.map(serializePlan);
}

/**
 * Task panel for admin/supervisor: all work plans on a date.
 * Supervisor is scoped to projects they supervise.
 */
async function listAll(user, { date }) {
  const params = [];
  const where = [];
  const target = date || new Date().toISOString().slice(0, 10);
  params.push(target);
  where.push(`wp.plan_date = $${params.length}`);

  if (user.role === 'supervisor') {
    params.push(user.id);
    where.push(`p.supervisor_id = $${params.length}`);
  }

  const { rows } = await query(
    `SELECT wp.*, p.project_name, ${WORKERS_JSON}
       FROM work_plans wp
       JOIN projects p ON p.id = wp.project_id
       LEFT JOIN work_plan_workers wpw ON wpw.work_plan_id = wp.id
       LEFT JOIN users u ON u.id = wpw.user_id
      WHERE ${where.join(' AND ')}
      GROUP BY wp.id, p.project_name
      ORDER BY p.project_name`,
    params
  );
  return { date: target, plans: rows.map(serializePlan) };
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
        description: `Assigned task for ${planDate}${task ? `: ${task}` : ''}`,
        metadata: { planDate, task, workerIds },
      },
      client
    );

    const recipients = [...workerIds];
    if (project.supervisor_id) recipients.push(project.supervisor_id);
    await notifyUsers(
      recipients,
      {
        type: 'workplan.assigned',
        title: 'Work assigned',
        body: `${project.project_name} on ${planDate}${task ? ` — ${task}` : ''}`,
        projectId,
        data: { route: `icms://project/${projectId}`, planDate },
      },
      client
    );

    return { id: plan.id, projectId, planDate: plan.plan_date, task: plan.task, workerIds };
  });
}

/** Work plans assigned to the current user for a date (default today). */
async function forMe(user, date) {
  const target = date || new Date().toISOString().slice(0, 10);
  const { rows } = await query(
    `SELECT wp.id, wp.plan_date, wp.task, wpw.status, wpw.started_at, wpw.completed_at,
            p.id AS project_id, p.project_name, p.site_location
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
      status: r.status,
      startedAt: r.started_at,
      completedAt: r.completed_at,
      projectId: r.project_id,
      projectName: r.project_name,
      siteLocation: r.site_location,
    })),
  };
}

/** A worker marks their own task started/completed. */
async function updateStatus(user, planId, status) {
  const { rows } = await query(
    `SELECT wp.*, p.project_name, p.supervisor_id
       FROM work_plans wp JOIN projects p ON p.id = wp.project_id
      WHERE wp.id = $1`,
    [planId]
  );
  const plan = rows[0];
  if (!plan) throw ApiError.notFound('Task not found');

  const member = await query(
    `SELECT 1 FROM work_plan_workers WHERE work_plan_id = $1 AND user_id = $2`,
    [planId, user.id]
  );
  if (member.rows.length === 0 && user.role !== 'admin') {
    throw ApiError.forbidden('This task is not assigned to you');
  }

  const tsCol = status === 'started' ? 'started_at' : status === 'completed' ? 'completed_at' : null;
  await query(
    `UPDATE work_plan_workers
        SET status = $1${tsCol ? `, ${tsCol} = now()` : ''}
      WHERE work_plan_id = $2 AND user_id = $3`,
    [status, planId, user.id]
  );

  await logActivity({
    userId: user.id,
    projectId: plan.project_id,
    action: `task.${status}`,
    entityType: 'work_plan',
    entityId: planId,
    description: `Marked task ${status}${plan.task ? `: ${plan.task}` : ''}`,
    metadata: { status },
  });

  // Notify supervisor + admins when work is completed.
  if (status === 'completed') {
    await notifyUsers([plan.supervisor_id].filter(Boolean), {
      type: 'work.completed',
      title: 'Task completed',
      body: `${plan.project_name}: a worker completed their task`,
      projectId: plan.project_id,
      data: { route: `icms://project/${plan.project_id}` },
    });
    await notifyAdmins({
      type: 'work.completed',
      title: 'Task completed',
      body: `${plan.project_name}: a task was completed`,
      projectId: plan.project_id,
      data: { route: `icms://project/${plan.project_id}` },
    });
  }

  return { id: planId, status };
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
    description: 'Deleted task',
  });
}

module.exports = { listForProject, listAll, create, forMe, updateStatus, remove };
