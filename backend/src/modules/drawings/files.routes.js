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

module.exports = router;
