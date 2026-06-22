'use strict';

const { z } = require('zod');
const { asyncHandler, ok, paginated } = require('../../utils/http');
const service = require('./activity.service');

const listQuery = z.object({
  projectId: z.string().uuid().optional(),
  userId: z.string().uuid().optional(),
  from: z.string().optional(),
  to: z.string().optional(),
  page: z.coerce.number().int().min(1).default(1),
  limit: z.coerce.number().int().min(1).max(100).default(30),
});

const list = asyncHandler(async (req, res) => {
  const parsed = listQuery.parse(req.query);
  const { data, meta } = await service.list(req.user, parsed);
  paginated(res, data, meta);
});

const forProject = asyncHandler(async (req, res) => {
  const page = parseInt(req.query.page || '1', 10);
  const limit = Math.min(parseInt(req.query.limit || '30', 10), 100);
  ok(res, await service.forProject(req.user, req.params.projectId, { page, limit }));
});

const timeline = asyncHandler(async (req, res) => {
  const limit = parseInt(req.query.limit || '300', 10);
  ok(res, await service.timeline(req.user, req.params.projectId, { limit }));
});

module.exports = { list, forProject, timeline };
