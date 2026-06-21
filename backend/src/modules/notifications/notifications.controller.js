'use strict';

const { z } = require('zod');
const { asyncHandler, ok, paginated } = require('../../utils/http');
const service = require('./notifications.service');

const listQuery = z.object({
  unread: z
    .union([z.literal('true'), z.literal('false')])
    .optional()
    .transform((v) => v === 'true'),
  page: z.coerce.number().int().min(1).default(1),
  limit: z.coerce.number().int().min(1).max(100).default(20),
});

const list = asyncHandler(async (req, res) => {
  const parsed = listQuery.parse(req.query);
  const { data, meta } = await service.list(req.user.id, parsed);
  paginated(res, data, meta);
});

const unreadCount = asyncHandler(async (req, res) => {
  ok(res, await service.unreadCount(req.user.id));
});

const markRead = asyncHandler(async (req, res) => {
  ok(res, await service.markRead(req.user.id, req.params.id));
});

const markAllRead = asyncHandler(async (req, res) => {
  await service.markAllRead(req.user.id);
  res.status(204).send();
});

module.exports = { list, unreadCount, markRead, markAllRead };
