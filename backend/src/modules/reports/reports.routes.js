'use strict';

const express = require('express');
const multer = require('multer');
const controller = require('./reports.controller');
const schema = require('./reports.schema');
const { validate } = require('../../middleware/validate');
const { requireRole } = require('../../middleware/rbac');
const config = require('../../config');

const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: config.storage.maxUploadMb * 1024 * 1024 },
});

// Mounted at /api root (behind authenticate + requireApproved).
const router = express.Router();

// All reports across projects — admin & supervisor only.
router.get(
  '/reports',
  requireRole('admin', 'supervisor'),
  validate(schema.listAllQuery, 'query'),
  controller.listAll
);

router.get(
  '/projects/:projectId/reports',
  validate(schema.listQuery, 'query'),
  controller.list
);
router.post('/projects/:projectId/reports', validate(schema.create), controller.create);

router.get('/reports/today/me', controller.todayForMe);
router.patch('/reports/:id/read', controller.markRead);
router.post('/reports/:id/media', upload.single('file'), controller.addMedia);

// Site photo timeline gallery — collect photos from files table
router.get(
  '/projects/:projectId/photos',
  requireRole('admin', 'supervisor', 'designer'),
  async (req, res, next) => {
    try {
      const { query: dbQuery } = require('../../db/pool');
      const limit = parseInt(req.query.limit) || 50;
      const offset = parseInt(req.query.offset) || 0;

      // Fetch photos from files table (media categories)
      const base = process.env.PUBLIC_BASE_URL
        ? `${process.env.PUBLIC_BASE_URL.replace(/\/$/, '')}${process.env.API_PREFIX || '/api/v1'}`
        : `${req.protocol}://${req.get('host')}${process.env.API_PREFIX || '/api/v1'}`;

      const filesResult = await dbQuery(
        `SELECT
           f.id,
           f.original_name,
           f.category,
           f.created_at,
           f.uploaded_by,
           u.full_name as uploader_name
         FROM files f
         JOIN users u ON u.id = f.uploaded_by
         WHERE f.project_id = $1
           AND f.category IN ('photo', 'video', 'voice_note', 'document', '3d_design')
           AND f.mime_type LIKE 'image/%'
         ORDER BY f.created_at DESC
         LIMIT $2 OFFSET $3`,
        [req.params.projectId, limit, offset]
      );

      const photos = filesResult.rows.map(f => ({
        ...f,
        url: `${base}/files/${f.id}/download`,
      }));

      res.json({
        data: {
          file_photos: photos,
          total: photos.length,
        },
      });
    } catch (err) { next(err); }
  }
);

module.exports = router;
