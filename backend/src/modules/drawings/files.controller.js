'use strict';

const fs = require('fs');
const { asyncHandler, ok, ApiError } = require('../../utils/http');
const service = require('./files.service');
const storage = require('../../services/fileStorage');

function fileBaseUrl(req) {
  const proto = req.headers['x-forwarded-proto'] || req.protocol;
  return `${proto}://${req.get('host')}${req.baseUrl || ''}`.replace(/\/$/, '') + '';
}

const list = asyncHandler(async (req, res) => {
  const rows = await service.listForProject(req.user, req.params.projectId, req.query.category);
  const base = `${req.protocol}://${req.get('host')}${process.env.API_PREFIX || '/api/v1'}`;
  ok(res, rows.map((r) => service.serialize(r, base)));
});

const upload = asyncHandler(async (req, res) => {
  const base = `${req.protocol}://${req.get('host')}${process.env.API_PREFIX || '/api/v1'}`;
  const result = await service.upload(
    req.user,
    req.params.projectId,
    { category: req.body.category, caption: req.body.caption, file: req.file },
    base
  );
  ok(res, result, 201);
});

// BUG-01: upload many files at once (multipart field name "files").
const uploadBatch = asyncHandler(async (req, res) => {
  const base = `${req.protocol}://${req.get('host')}${process.env.API_PREFIX || '/api/v1'}`;
  const files = req.files || [];
  if (files.length === 0) throw ApiError.badRequest('No files provided');
  const results = [];
  for (const file of files) {
    const result = await service.upload(
      req.user,
      req.params.projectId,
      { category: req.body.category, caption: req.body.caption, file },
      base
    );
    results.push(result);
  }
  ok(res, results, 201);
});

const getMeta = asyncHandler(async (req, res) => {
  const base = `${req.protocol}://${req.get('host')}${process.env.API_PREFIX || '/api/v1'}`;
  ok(res, await service.getMeta(req.user, req.params.fileId, base));
});

const remove = asyncHandler(async (req, res) => {
  await service.remove(req.user, req.params.fileId);
  res.status(204).send();
});

/** Streams the file, supporting HTTP Range requests (videos / large PDFs). */
const download = asyncHandler(async (req, res) => {
  if (req.log) req.log.info({ fileId: req.params.fileId, userId: req.user?.id }, 'file download requested');
  const file = await service.resolveForDownload(req.user, req.params.fileId);
  const stat = await storage.stat(file.storage_key);
  const total = stat.size;
  const range = req.headers.range;

  res.setHeader('Content-Type', file.mime_type || 'application/octet-stream');
  res.setHeader('Accept-Ranges', 'bytes');
  res.setHeader(
    'Content-Disposition',
    `inline; filename="${encodeURIComponent(file.original_name)}"`
  );

  if (range) {
    const match = /bytes=(\d*)-(\d*)/.exec(range);
    if (!match) throw ApiError.badRequest('Invalid Range header');
    const start = match[1] ? parseInt(match[1], 10) : 0;
    const end = match[2] ? parseInt(match[2], 10) : total - 1;
    if (start >= total || end >= total) {
      res.setHeader('Content-Range', `bytes */${total}`);
      return res.status(416).end();
    }
    res.status(206);
    res.setHeader('Content-Range', `bytes ${start}-${end}/${total}`);
    res.setHeader('Content-Length', end - start + 1);
    return storage.createReadStream(file.storage_key, { start, end }).pipe(res);
  }

  res.setHeader('Content-Length', total);
  return storage.createReadStream(file.storage_key).pipe(res);
});

module.exports = { list, upload, uploadBatch, getMeta, remove, download };
