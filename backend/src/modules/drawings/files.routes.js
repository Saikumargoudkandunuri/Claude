'use strict';

const express = require('express');
const multer = require('multer');
const controller = require('./files.controller');
const config = require('../../config');

// In-memory upload buffer; storage service persists to disk/S3.
const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: config.storage.maxUploadMb * 1024 * 1024 },
});

// Mounted at /api root (behind authenticate + requireApproved).
const router = express.Router();

router.get('/projects/:projectId/files', controller.list);
router.post('/projects/:projectId/files', upload.single('file'), controller.upload);
router.post('/projects/:projectId/files/batch', upload.array('files', 20), controller.uploadBatch);

router.get('/files/:fileId/meta', controller.getMeta);
router.get('/files/:fileId/download', controller.download);
router.delete('/files/:fileId', controller.remove);

const { requireRole } = require('../../middleware/rbac');

// Approve a drawing
router.put('/files/:fileId/approve', requireRole('admin', 'supervisor'), async (req, res, next) => {
  try {
    const { query: dbQuery } = require('../../db/pool');
    const { fileId } = req.params;

    const result = await dbQuery(
      `UPDATE files
       SET approval_status = 'approved',
           approved_by = $1,
           approved_at = NOW(),
           revision_note = NULL
       WHERE id = $2
       RETURNING id, original_name, approval_status, approved_at`,
      [req.user.id, fileId]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: { code: 'NOT_FOUND', message: 'File not found' } });
    }

    await dbQuery(
      `INSERT INTO activity_logs (user_id, project_id, action, entity_type, entity_id, description)
       SELECT $1, project_id, 'drawing.approved', 'file', $2,
              'Drawing approved: ' || original_name
       FROM files WHERE id = $2`,
      [req.user.id, fileId]
    );

    res.json({ data: result.rows[0], message: 'Drawing approved.' });
  } catch (err) { next(err); }
});

// Request revision on a drawing
router.put('/files/:fileId/request-revision', requireRole('admin', 'supervisor'), async (req, res, next) => {
  try {
    const { query: dbQuery } = require('../../db/pool');
    const { note } = req.body;
    const { fileId } = req.params;

    if (!note || note.trim().length === 0) {
      return res.status(400).json({ error: { code: 'BAD_REQUEST', message: 'Revision note is required.' } });
    }

    const result = await dbQuery(
      `UPDATE files
       SET approval_status = 'revision_requested',
           revision_note = $1,
           approved_by = NULL,
           approved_at = NULL
       WHERE id = $2
       RETURNING id, original_name, approval_status, revision_note`,
      [note.trim(), fileId]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: { code: 'NOT_FOUND', message: 'File not found' } });
    }

    await dbQuery(
      `INSERT INTO activity_logs (user_id, project_id, action, entity_type, entity_id, description)
       SELECT $1, project_id, 'drawing.revision_requested', 'file', $2,
              'Revision requested: ' || original_name
       FROM files WHERE id = $2`,
      [req.user.id, fileId]
    );

    res.json({ data: result.rows[0], message: 'Revision requested.' });
  } catch (err) { next(err); }
});

module.exports = router;
