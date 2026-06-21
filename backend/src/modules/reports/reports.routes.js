'use strict';

const express = require('express');
const multer = require('multer');
const controller = require('./reports.controller');
const schema = require('./reports.schema');
const { validate } = require('../../middleware/validate');
const config = require('../../config');

const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: config.storage.maxUploadMb * 1024 * 1024 },
});

// Mounted at /api root (behind authenticate + requireApproved).
const router = express.Router();

router.get(
  '/projects/:projectId/reports',
  validate(schema.listQuery, 'query'),
  controller.list
);
router.post('/projects/:projectId/reports', validate(schema.create), controller.create);

router.get('/reports/today/me', controller.todayForMe);
router.post('/reports/:id/media', upload.single('file'), controller.addMedia);

module.exports = router;
