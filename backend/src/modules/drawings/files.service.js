'use strict';

const { query, withTransaction } = require('../../db/pool');
const { ApiError } = require('../../utils/http');
const { logActivity } = require('../../utils/activity');
const { createNotification, notifyAdmins, notifyUsers } = require('../../utils/notify');
const storage = require('../../services/fileStorage');
const projects = require('../projects/projects.service');

// Only the quotation keeps a single active file. Drawings (2D/Working/3D),
// site measurements, photos, videos, voice notes and documents allow MANY files.
const SINGLE_INSTANCE = new Set(['quotation']);

const DRAWING_CATEGORIES = new Set([
  '2d_drawing', 'working_drawing', '3d_design', 'site_measurement', 'quotation',
  // legacy
  'measurement_drawing', 'site_drawing', 'pdf_drawing',
]);
const MEDIA_CATEGORIES = new Set(['photo', 'video', 'voice_note', 'document']);

function serialize(row, fileBaseUrl) {
  return {
    id: row.id,
    projectId: row.project_id,
    reportId: row.report_id,
    category: row.category,
    originalName: row.original_name,
    mimeType: row.mime_type,
    sizeBytes: row.size_bytes ? Number(row.size_bytes) : null,
    caption: row.caption,
    uploadedBy: row.uploaded_by,
    createdAt: row.created_at,
    downloadUrl: `${fileBaseUrl}/files/${row.id}/download`,
  };
}

/** Permission to upload depends on category, enforced beyond route RBAC. */
function assertCanUpload(role, category) {
  if (DRAWING_CATEGORIES.has(category)) {
    if (role !== 'admin' && role !== 'designer') {
      throw ApiError.forbidden('Only Admin or Designer can upload drawings, 3D or quotations');
    }
  } else if (MEDIA_CATEGORIES.has(category)) {
    if (!['admin', 'supervisor', 'worker', 'designer'].includes(role)) {
      throw ApiError.forbidden('Your role cannot upload media');
    }
  } else {
    throw ApiError.badRequest('Unknown file category');
  }
}

function notificationTypeFor(category) {
  switch (category) {
    case '3d_design':
      return { type: 'design3d.uploaded', label: '3D design' };
    case 'photo':
      return { type: 'photo.uploaded', label: 'photo' };
    case 'video':
      return { type: 'video.uploaded', label: 'video' };
    case 'quotation':
      return { type: 'drawing.uploaded', label: 'quotation' };
    default:
      return { type: 'drawing.uploaded', label: 'drawing' };
  }
}

async function listForProject(user, projectId, category) {
  await projects.getAccessibleProject(user, projectId);
  const params = [projectId];
  let sql = 'SELECT * FROM files WHERE project_id = $1';
  if (category) {
    params.push(category);
    sql += ` AND category = $2`;
  }
  sql += ' ORDER BY created_at DESC';
  const { rows } = await query(sql, params);
  return rows;
}

async function upload(user, projectId, { category, caption, file }, fileBaseUrl) {
  const project = await projects.getAccessibleProject(user, projectId);
  assertCanUpload(user.role, category);
  if (!file) throw ApiError.badRequest('No file provided');

  const isReplacement = SINGLE_INSTANCE.has(category);

  const created = await withTransaction(async (client) => {
    let removedKey = null;

    if (isReplacement) {
      // Lock existing row to prevent concurrent duplicate uploads (FIX-02).
      await client.query(
        `SELECT id FROM files WHERE project_id = $1 AND category = $2 FOR UPDATE`,
        [projectId, category]
      );
      const existing = await client.query(
        `SELECT id, storage_key FROM files WHERE project_id = $1 AND category = $2`,
        [projectId, category]
      );
      if (existing.rows.length > 0) {
        removedKey = existing.rows[0].storage_key;
        await client.query(`DELETE FROM files WHERE project_id = $1 AND category = $2`, [
          projectId,
          category,
        ]);
      }
    }

    const saved = await storage.save(file.buffer, {
      projectId,
      category,
      originalName: file.originalname,
    });

    const { rows } = await client.query(
      `INSERT INTO files
        (project_id, category, original_name, storage_key, mime_type, size_bytes, caption, uploaded_by)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8)
       RETURNING *`,
      [
        projectId,
        category,
        file.originalname,
        saved.storageKey,
        file.mimetype,
        saved.sizeBytes,
        caption || null,
        user.id,
      ]
    );

    const action = isReplacement && removedKey ? 'replace' : 'upload';
    await logActivity(
      {
        userId: user.id,
        projectId,
        action: `file.${action}`,
        entityType: 'file',
        entityId: rows[0].id,
        description: `${action === 'replace' ? 'Replaced' : 'Uploaded'} ${category} (${file.originalname})`,
        metadata: { category },
      },
      client
    );

    // Remove old physical file only after the new row is committed-safe.
    if (removedKey) {
      // best-effort; run after transaction
      setImmediate(() => storage.remove(removedKey).catch(() => {}));
    }

    return { row: rows[0], replaced: !!removedKey };
  });

  // Notify relevant people (admins + project staff).
  await notifyFileEvent(user, project, category, created.replaced);

  return serialize(created.row, fileBaseUrl);
}

async function notifyFileEvent(user, project, category, replaced) {
  const meta = notificationTypeFor(category);
  const type = replaced && DRAWING_CATEGORIES.has(category) ? 'drawing.replaced' : meta.type;
  const verb = replaced ? 'replaced' : 'uploaded';

  // Workers assigned to the project should know when drawings change.
  const recipients = new Set();
  if (project.supervisor_id) recipients.add(project.supervisor_id);
  if (project.designer_id) recipients.add(project.designer_id);

  if (DRAWING_CATEGORIES.has(category)) {
    const { rows } = await query(
      `SELECT user_id FROM project_assignments
        WHERE project_id = $1 AND role = 'worker' AND active = true`,
      [project.id]
    );
    rows.forEach((r) => recipients.add(r.user_id));
  }
  recipients.delete(user.id);

  await notifyUsers([...recipients], {
    type,
    title: `${meta.label} ${verb}`,
    body: `${project.project_name}: ${meta.label} ${verb}`,
    projectId: project.id,
    data: { route: `icms://project/${project.id}`, category },
  });

  // Admins get notified for design/drawing/quotation changes.
  if (DRAWING_CATEGORIES.has(category)) {
    await notifyAdmins({
      type,
      title: `${meta.label} ${verb}`,
      body: `${project.project_name}: ${meta.label} ${verb}`,
      projectId: project.id,
      data: { route: `icms://project/${project.id}`, category },
    });
  }
}

async function getFileRecord(user, fileId) {
  const { rows } = await query('SELECT * FROM files WHERE id = $1', [fileId]);
  const file = rows[0];
  if (!file) throw ApiError.notFound('File not found');
  // Reuse project access check.
  await projects.getAccessibleProject(user, file.project_id);
  return file;
}

async function getMeta(user, fileId, fileBaseUrl) {
  const file = await getFileRecord(user, fileId);
  return serialize(file, fileBaseUrl);
}

async function remove(user, fileId) {
  const file = await getFileRecord(user, fileId);

  const canDelete =
    DRAWING_CATEGORIES.has(file.category)
      ? user.role === 'admin' || user.role === 'designer'
      : user.role === 'admin' || file.uploaded_by === user.id; // media: admin or uploader

  if (!canDelete) throw ApiError.forbidden('You cannot delete this file');

  await query('DELETE FROM files WHERE id = $1', [fileId]);
  await storage.remove(file.storage_key).catch(() => {});
  await logActivity({
    userId: user.id,
    projectId: file.project_id,
    action: 'file.delete',
    entityType: 'file',
    entityId: fileId,
    description: `Deleted ${file.category} (${file.original_name})`,
  });
}

/** Returns the raw record + storage info for streaming. */
async function resolveForDownload(user, fileId) {
  const file = await getFileRecord(user, fileId);
  if (!storage.exists(file.storage_key)) {
    throw ApiError.notFound('File data missing on server');
  }
  return file;
}

module.exports = {
  SINGLE_INSTANCE,
  DRAWING_CATEGORIES,
  MEDIA_CATEGORIES,
  serialize,
  listForProject,
  upload,
  getMeta,
  remove,
  resolveForDownload,
};
