'use strict';

const { z } = require('zod');

const create = z.object({
  type: z.enum(['worker', 'supervisor']),
  reportDate: z
    .string()
    .regex(/^\d{4}-\d{2}-\d{2}$/, 'Expected YYYY-MM-DD')
    .optional(),
  workDone: z.string().max(4000).optional().nullable(),
  pendingWork: z.string().max(4000).optional().nullable(),
  problems: z.string().max(4000).optional().nullable(),
  materialsNeeded: z.string().max(4000).optional().nullable(),
  tomorrowNotes: z.string().max(4000).optional().nullable(),
  // Supervisor-only
  siteProgress: z.string().max(4000).optional().nullable(),
});

const listQuery = z.object({
  date: z.string().regex(/^\d{4}-\d{2}-\d{2}$/).optional(),
  type: z.enum(['worker', 'supervisor']).optional(),
});

module.exports = { create, listQuery };
