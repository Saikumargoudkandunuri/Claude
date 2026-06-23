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

module.exports = router;
