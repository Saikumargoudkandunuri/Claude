'use strict';

const { query, withTransaction } = require('../../db/pool');
const { ApiError } = require('../../utils/http');
const { logActivity } = require('../../utils/activity');
const { createNotification, notifyAdmins, notifyUsers } = require('../../utils/notify');
const { STAGES } = require('./projects.schema');

const DESIGN_STAGES = ['discussion', '3d_design', 'drawing'];
const EXECUTION_STAGES = STAGES.filter((s) => !DESIGN_STAGES.includes(s));

/** Serialize a project row to API shape; strips staff contacts for workers. */
function serializeProject(row, viewerRole) {
  const isWorker = viewerRole === 'worker';
  const base = {
    id: row.id,
    projectNumber: row.project_number,
    customerName: row.customer_name,
    // Workers must NOT see customer phone numbers / sensitive contact details.
    phone: isWorker ? null : row.phone,
    altPhone: isWorker ? null : row.alt_phone,
    address: row.address,
    siteLocation: row.site_location,
    projectName: row.project_name,
    projectType: row.project_type,
    workDescription: row.work_description,
    startDate: row.start_date,
    expectedCompletionDate: row.expected_completion_date,
    currentStage: row.current_stage,
    supervisorId: row.supervisor_id,
    designerId: row.designer_id,
    remarks: row.remarks,
    isArchived: row.is_archived,
    createdAt: row.created_at,
    progress: stageProgress(row.current_stage),
  };
  if (!isWorker) {
    base.quotationAmount = Number(row.quotation_amount);
  }
  return base;
}

function stageProgress(stage) {
  const idx = STAGES.indexOf(stage);
  if (idx < 0) return 0;
  return Math.round(((idx + 1) / STAGES.length) * 100);
}

/** Whether a role may move a project into a given stage. */
function canControlStage(role, stage) {
  if (role === 'admin') return true;
  if (role === 'designer') return DESIGN_STAGES.includes(stage);
  if (role === 'supervisor') return EXECUTION_STAGES.includes(stage);
  return false;
}

async function isWorkerAssigned(projectId, userId) {
  const { rows } = await query(
    `SELECT 1 FROM project_assignments
      WHERE project_id = $1 AND user_id = $2 AND active = true LIMIT 1`,
    [projectId, userId]
  );
  return rows.length > 0;
}

/**
 * Load a project the viewer is allowed to see, else throw 403/404.
 * Workers may only see projects they are assigned to.
 */
async function getAccessibleProject(user, projectId) {
  const { rows } = await query('SELECT * FROM projects WHERE id = $1', [projectId]);
  const project = rows[0];
  if (!project) throw ApiError.notFound('Project not found');

  if (user.role === 'worker') {
    const allowed = await isWorkerAssigned(projectId, user.id);
    if (!allowed) throw ApiError.forbidden('Not assigned to this project');
  }
  return project;
}

/** Contacts visible to a worker: admin + the project's supervisor only. */
async function contactsForWorker(project) {
  const { rows } = await query(
    `SELECT id, full_name, phone, role FROM users
      WHERE (role = 'admin' AND status = 'approved')
         OR id = $1`,
    [project.supervisor_id]
  );
  const admin = rows.find((r) => r.role === 'admin');
  const supervisor = rows.find((r) => r.id === project.supervisor_id);
  return {
    adminName: admin?.full_name || null,
    adminPhone: admin?.phone || null,
    supervisorName: supervisor?.full_name || null,
    supervisorPhone: supervisor?.phone || null,
  };
}

async function list(user, { stage, q, assigned, status, sort, page, limit }) {
  const where = [];
  const params = [];

  // FIX-07: Workers ALWAYS scoped to assigned projects regardless of query params.
  if (user.role === 'worker') {
    params.push(user.id);
    where.push(
      `EXISTS (SELECT 1 FROM project_assignments pa
                WHERE pa.project_id = projects.id AND pa.user_id = $${params.length} AND pa.active = true)`
    );
  } else if (assigned === 'me') {
    params.push(user.id);
    where.push(
      `EXISTS (SELECT 1 FROM project_assignments pa
                WHERE pa.project_id = projects.id AND pa.user_id = $${params.length} AND pa.active = true)`
    );
  }

  // NEW-08: status filter (archived projects hidden by default).
  if (status === 'archived') {
    where.push('is_archived = true');
  } else if (status === 'completed') {
    where.push("is_archived = false AND current_stage = 'completed'");
  } else if (status === 'active') {
    where.push("is_archived = false AND current_stage <> 'completed'");
  } else {
    where.push('is_archived = false');
  }

  if (stage) {
    params.push(stage);
    where.push(`current_stage = $${params.length}`);
  }
  if (q) {
    params.push(`%${q}%`);
    where.push(
      `(project_name ILIKE $${params.length} OR customer_name ILIKE $${params.length} OR project_number ILIKE $${params.length})`
    );
  }
  const whereSql = where.length ? `WHERE ${where.join(' AND ')}` : '';

  // NEW-08: sort options.
  let orderSql = 'ORDER BY created_at DESC';
  if (sort === 'created_at_asc') orderSql = 'ORDER BY created_at ASC';
  else if (sort === 'stage') orderSql = 'ORDER BY current_stage ASC, created_at DESC';
  else if (sort === 'payment') orderSql = 'ORDER BY quotation_amount DESC';

  const offset = (page - 1) * limit;

  const totalRes = await query(`SELECT COUNT(*)::int AS total FROM projects ${whereSql}`, params);
  const { rows } = await query(
    `SELECT * FROM projects ${whereSql} ${orderSql} LIMIT ${limit} OFFSET ${offset}`,
    params
  );
  return {
    data: rows.map((r) => serializeProject(r, user.role)),
    meta: { page, limit, total: totalRes.rows[0].total },
  };
}

async function getOne(user, projectId) {
  const project = await getAccessibleProject(user, projectId);
  const result = serializeProject(project, user.role);
  if (user.role === 'worker') {
    result.contacts = await contactsForWorker(project);
  }
  return result;
}

function mapCreateFields(body) {
  // PROJ-01: only customer name is required; auto-generate the rest.
  const projectNumber =
    body.projectNumber || `PRJ-${Date.now().toString(36).toUpperCase()}`;
  const projectName = body.projectName || body.customerName;
  return [
    projectNumber,
    body.customerName,
    body.phone || null,
    body.altPhone || null,
    body.address || null,
    body.siteLocation || null,
    projectName,
    body.projectType || null,
    body.workDescription || null,
    body.startDate || null,
    body.expectedCompletionDate || null,
    body.quotationAmount ?? 0,
    body.supervisorId || null,
    body.designerId || null,
    body.remarks || null,
  ];
}

async function create(adminId, body) {
  return withTransaction(async (client) => {
    const { rows } = await client.query(
      `INSERT INTO projects
        (project_number, customer_name, phone, alt_phone, address, site_location,
         project_name, project_type, work_description, start_date, expected_completion_date,
         quotation_amount, supervisor_id, designer_id, remarks, created_by)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16)
       RETURNING *`,
      [...mapCreateFields(body), adminId]
    );
    const project = rows[0];

    // Initialize payment summary + first stage history.
    await client.query(
      `INSERT INTO payments (project_id, quotation_amount, total_received)
       VALUES ($1,$2,0) ON CONFLICT (project_id) DO NOTHING`,
      [project.id, project.quotation_amount]
    );
    await client.query(
      `INSERT INTO project_stage_history (project_id, stage, status, changed_by, note)
       VALUES ($1,'discussion','in_progress',$2,'Project created')`,
      [project.id, adminId]
    );

    // Auto-create assignment rows for supervisor/designer if provided.
    if (project.supervisor_id) {
      await client.query(
        `INSERT INTO project_assignments (project_id, user_id, role, assigned_by)
         VALUES ($1,$2,'supervisor',$3) ON CONFLICT DO NOTHING`,
        [project.id, project.supervisor_id, adminId]
      );
    }
    if (project.designer_id) {
      await client.query(
        `INSERT INTO project_assignments (project_id, user_id, role, assigned_by)
         VALUES ($1,$2,'designer',$3) ON CONFLICT DO NOTHING`,
        [project.id, project.designer_id, adminId]
      );
    }

    await logActivity(
      {
        userId: adminId,
        projectId: project.id,
        action: 'project.create',
        entityType: 'project',
        entityId: project.id,
        description: `Created project ${project.project_number} - ${project.project_name}`,
      },
      client
    );

    // Notify assigned supervisor + designer.
    const recipients = [project.supervisor_id, project.designer_id].filter(Boolean);
    await notifyUsers(
      recipients,
      {
        type: 'project.created',
        title: 'New project assigned',
        body: `${project.project_name} (${project.project_number})`,
        projectId: project.id,
        data: { route: `icms://project/${project.id}` },
      },
      client
    );

    return serializeProject(project, 'admin');
  });
}

async function update(adminId, projectId, body) {
  const existing = await query('SELECT id FROM projects WHERE id = $1', [projectId]);
  if (!existing.rows[0]) throw ApiError.notFound('Project not found');

  const fieldMap = {
    projectNumber: 'project_number',
    customerName: 'customer_name',
    phone: 'phone',
    altPhone: 'alt_phone',
    address: 'address',
    siteLocation: 'site_location',
    projectName: 'project_name',
    projectType: 'project_type',
    workDescription: 'work_description',
    startDate: 'start_date',
    expectedCompletionDate: 'expected_completion_date',
    quotationAmount: 'quotation_amount',
    supervisorId: 'supervisor_id',
    designerId: 'designer_id',
    remarks: 'remarks',
  };

  const set = [];
  const params = [];
  for (const [key, col] of Object.entries(fieldMap)) {
    if (key in body) {
      params.push(body[key]);
      set.push(`${col} = $${params.length}`);
    }
  }
  if (set.length === 0) throw ApiError.badRequest('No fields to update');
  params.push(projectId);

  const { rows } = await query(
    `UPDATE projects SET ${set.join(', ')} WHERE id = $${params.length} RETURNING *`,
    params
  );

  // Keep payments.quotation_amount in sync if changed.
  if ('quotationAmount' in body) {
    await query(
      `INSERT INTO payments (project_id, quotation_amount)
       VALUES ($1,$2)
       ON CONFLICT (project_id) DO UPDATE SET quotation_amount = EXCLUDED.quotation_amount, updated_at = now()`,
      [projectId, body.quotationAmount]
    );
  }

  await logActivity({
    userId: adminId,
    projectId,
    action: 'project.update',
    entityType: 'project',
    entityId: projectId,
    description: 'Updated project details',
    metadata: { fields: Object.keys(body) },
  });

  return serializeProject(rows[0], 'admin');
}

async function remove(adminId, projectId) {
  const { rows } = await query('SELECT * FROM projects WHERE id = $1', [projectId]);
  if (!rows[0]) throw ApiError.notFound('Project not found');
  // FIX-10: Archive instead of hard delete to preserve all data.
  await query(
    'UPDATE projects SET is_archived = true, archived_at = now() WHERE id = $1',
    [projectId]
  );
  await logActivity({
    userId: adminId,
    projectId,
    action: 'project.archive',
    entityType: 'project',
    entityId: projectId,
    description: `Archived project ${rows[0].project_number}`,
  });
}

/** Unarchive a previously archived project (admin only). */
async function unarchive(adminId, projectId) {
  await query(
    'UPDATE projects SET is_archived = false, archived_at = NULL WHERE id = $1',
    [projectId]
  );
  await logActivity({
    userId: adminId,
    projectId,
    action: 'project.unarchive',
    entityType: 'project',
    entityId: projectId,
    description: 'Unarchived project',
  });
}

async function getStages(user, projectId) {
  await getAccessibleProject(user, projectId);
  const { rows } = await query(
    `SELECT id, stage, status, note, changed_by, changed_at
       FROM project_stage_history
      WHERE project_id = $1 ORDER BY changed_at ASC`,
    [projectId]
  );
  return rows;
}

async function setStage(user, projectId, { stage, status, note }) {
  const project = await getAccessibleProject(user, projectId);
  if (!canControlStage(user.role, stage)) {
    throw ApiError.forbidden('Your role cannot control this stage');
  }

  // FIX-03: Enforce sequential stage transitions (non-admins must advance one step at a time).
  const currentIndex = STAGES.indexOf(project.current_stage);
  const newIndex = STAGES.indexOf(stage);
  if (user.role !== 'admin' && newIndex !== currentIndex + 1 && newIndex !== currentIndex) {
    throw ApiError.validation(
      `Cannot move from '${project.current_stage}' to '${stage}'. Stages must advance one at a time.`
    );
  }

  return withTransaction(async (client) => {
    await client.query('UPDATE projects SET current_stage = $1 WHERE id = $2', [stage, projectId]);
    await client.query(
      `INSERT INTO project_stage_history (project_id, stage, status, changed_by, note)
       VALUES ($1,$2,$3,$4,$5)`,
      [projectId, stage, status, user.id, note || null]
    );
    await logActivity(
      {
        userId: user.id,
        projectId,
        action: 'project.stage',
        entityType: 'project',
        entityId: projectId,
        description: `Stage set to ${stage} (${status})`,
        metadata: { stage, status },
      },
      client
    );

    if (stage === 'completed' && status === 'completed') {
      await notifyAdmins(
        {
          type: 'project.stage',
          title: 'Project completed',
          body: `${project.project_name} marked completed`,
          projectId,
          data: { route: `icms://project/${projectId}`, stage },
        },
        client
      );
    }

    // Notify everyone connected to the project on any stage change.
    const stageLabel = String(stage).replace(/_/g, ' ');
    const recipients = new Set();
    if (project.supervisor_id) recipients.add(project.supervisor_id);
    if (project.designer_id) recipients.add(project.designer_id);
    const workers = await client.query(
      `SELECT user_id FROM project_assignments
        WHERE project_id = $1 AND role = 'worker' AND active = true`,
      [projectId]
    );
    workers.rows.forEach((w) => recipients.add(w.user_id));
    recipients.delete(user.id);
    await notifyUsers(
      [...recipients],
      {
        type: 'project.stage',
        title: 'Project stage updated',
        body: `${project.project_name}: now ${stageLabel}`,
        projectId,
        data: { route: `icms://project/${projectId}`, stage },
      },
      client
    );
    // Admins always get stage updates (completion already handled above).
    if (!(stage === 'completed' && status === 'completed')) {
      await notifyAdmins(
        {
          type: 'project.stage',
          title: 'Project stage updated',
          body: `${project.project_name}: now ${stageLabel}`,
          projectId,
          data: { route: `icms://project/${projectId}`, stage },
        },
        client
      );
    }

    return serializeProject({ ...project, current_stage: stage }, user.role);
  });
}

async function listAssignments(user, projectId) {
  await getAccessibleProject(user, projectId);
  // Workers never see other workers' contact info; expose name/role/task only.
  const includeContact = user.role !== 'worker';
  const { rows } = await query(
    `SELECT pa.id, pa.role, pa.task, pa.active, pa.created_at,
            u.id AS user_id, u.full_name,
            ${includeContact ? 'u.phone' : 'NULL AS phone'}
       FROM project_assignments pa
       JOIN users u ON u.id = pa.user_id
      WHERE pa.project_id = $1 AND pa.active = true
      ORDER BY pa.role, u.full_name`,
    [projectId]
  );
  return rows.map((r) => ({
    id: r.id,
    userId: r.user_id,
    fullName: r.full_name,
    phone: r.phone,
    role: r.role,
    task: r.task,
    active: r.active,
  }));
}

async function addAssignment(user, projectId, { userId, role, task }) {
  const project = await getAccessibleProject(user, projectId);

  // Supervisors may only assign workers; admins may assign anyone.
  if (user.role === 'supervisor' && role !== 'worker') {
    throw ApiError.forbidden('Supervisors can only assign workers');
  }

  const target = await query(`SELECT id, role, status FROM users WHERE id = $1`, [userId]);
  if (!target.rows[0]) throw ApiError.notFound('User not found');
  if (target.rows[0].status !== 'approved') throw ApiError.badRequest('User is not approved');

  return withTransaction(async (client) => {
    const { rows } = await client.query(
      `INSERT INTO project_assignments (project_id, user_id, role, task, assigned_by)
       VALUES ($1,$2,$3,$4,$5)
       ON CONFLICT (project_id, user_id, role)
       DO UPDATE SET task = EXCLUDED.task, active = true
       RETURNING *`,
      [projectId, userId, role, task || null, user.id]
    );

    // Mirror supervisor/designer onto the project record.
    if (role === 'supervisor') {
      await client.query('UPDATE projects SET supervisor_id = $1 WHERE id = $2', [userId, projectId]);
    } else if (role === 'designer') {
      await client.query('UPDATE projects SET designer_id = $1 WHERE id = $2', [userId, projectId]);
    } else if (role === 'worker') {
      await client.query(`UPDATE users SET worker_status = 'at_site' WHERE id = $1`, [userId]);
    }

    await logActivity(
      {
        userId: user.id,
        projectId,
        action: 'assignment.add',
        entityType: 'assignment',
        entityId: rows[0].id,
        description: `Assigned ${role}${task ? ` for ${task}` : ''}`,
        metadata: { userId, role, task },
      },
      client
    );

    await createNotification(
      {
        userId,
        type: 'worker.assigned',
        title: 'You have a new assignment',
        body: `${project.project_name}${task ? ` — ${task}` : ''}`,
        projectId,
        data: { route: `icms://project/${projectId}` },
      },
      client
    );

    return rows[0];
  });
}

async function removeAssignment(user, projectId, assignmentId) {
  await getAccessibleProject(user, projectId);
  const { rows } = await query(
    `UPDATE project_assignments SET active = false
      WHERE id = $1 AND project_id = $2 RETURNING *`,
    [assignmentId, projectId]
  );
  if (!rows[0]) throw ApiError.notFound('Assignment not found');
  await logActivity({
    userId: user.id,
    projectId,
    action: 'assignment.remove',
    entityType: 'assignment',
    entityId: assignmentId,
    description: 'Removed assignment',
  });
}

module.exports = {
  DESIGN_STAGES,
  EXECUTION_STAGES,
  serializeProject,
  canControlStage,
  isWorkerAssigned,
  getAccessibleProject,
  list,
  getOne,
  create,
  update,
  remove,
  getStages,
  setStage,
  listAssignments,
  addAssignment,
  removeAssignment,
};
