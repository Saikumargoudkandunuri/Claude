'use strict';

const { z } = require('zod');

const create = z.object({
  planDate: z.string().regex(/^\d{4}-\d{2}-\d{2}$/, 'Expected YYYY-MM-DD'),
  task: z.string().max(500).optional().nullable(),
  workerIds: z.array(z.string().uuid()).min(1),
});

const listQuery = z.object({
  date: z.string().regex(/^\d{4}-\d{2}-\d{2}$/).optional(),
});

module.exports = { create, listQuery };
