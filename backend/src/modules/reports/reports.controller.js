'use strict';

const { asyncHandler, ok, ApiError } = require('../../utils/http');
const service = require('./reports.service');
const filesService = require('../drawings/files.service');
const storage = require('../../services/fileStorage');
const { query } = require('../../db/pool');
const { logActivity } = require('../../utils/activity');

const list = asyncHandler(async (req, res) => {
  ok(res, await service.list(req.user, req.params.projectId, req.query));
});

// All reports across projects (admin: all, supervisor: own projects).
const listAll = asyncHandler(async (req, res) => {
  const { data, meta } = await service.listAll(req.user, req.query);
  res.status(200).json({ data, meta });
});

const create = asyncHandler(async (req, res) => {
  const result = await service.create(req.user, req.params.projectId, req.body);
  // Emit real-time event to all project members
  const io = req.app.get('io');
  if (io) {
    io.to(`project:${req.params.projectId}`).emit('new_message', result);
  }
  ok(res, result, 201);
});

const todayForMe = asyncHandler(async (req, res) => {
  ok(res, await service.todayForMe(req.user));
});

// NEW-02: mark a report as read by the current viewer.
const markRead = asyncHandler(async (req, res) => {
  ok(res, await service.markRead(req.user, req.params.id));
});

/** Attach a media file (photo/video/voice_note) to a report authored by the user. */
const addMedia = asyncHandler(async (req, res) => {
  const report = await service.getRecord(req.user, req.params.id);
  if (report.author_id !== req.user.id && req.user.role !== 'admin') {
    throw ApiError.forbidden('You can only attach media to your own report');
  }
  if (!req.file) throw ApiError.badRequest('No file provided');

  const category = req.body.category;
  if (!filesService.MEDIA_CATEGORIES.has(category)) {
    throw ApiError.badRequest('category must be photo, video or voice_note');
  }

  const saved = await storage.save(req.file.buffer, {
    projectId: report.project_id,
    category,
    originalName: req.file.originalname,
  });
  const base = `${req.protocol}://${req.get('host')}${process.env.API_PREFIX || '/api/v1'}`;
  const { rows } = await query(
    `INSERT INTO files
       (project_id, report_id, category, original_name, storage_key, mime_type, size_bytes, uploaded_by)
     VALUES ($1,$2,$3,$4,$5,$6,$7,$8) RETURNING *`,
    [
      report.project_id,
      report.id,
      category,
      req.file.originalname,
      saved.storageKey,
      req.file.mimetype,
      saved.sizeBytes,
      req.user.id,
    ]
  );
  await logActivity({
    userId: req.user.id,
    projectId: report.project_id,
    action: 'report.media',
    entityType: 'file',
    entityId: rows[0].id,
    description: `Attached ${category} to report`,
  });
  ok(res, filesService.serialize(rows[0], base), 201);
});

module.exports = { list, listAll, create, todayForMe, markRead, addMedia };
