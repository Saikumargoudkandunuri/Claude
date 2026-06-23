'use strict';

const { z } = require('zod');

const create = z.object({
  type: z.enum(['worker', 'supervisor', 'designer']),
  reportDate: z
    .string()
    .regex(/^\d{4}-\d{2}-\d{2}$/, 'Expected YYYY-MM-DD')
    .optional(),
  workDone: z.string().max(4000).optional().nullable(),
  pendingWork: z.string().max(4000).optional().nullable(),
  // "Issues faced" maps to problems
  problems: z.string().max(4000).optional().nullable(),
  materialsNeeded: z.string().max(4000).optional().nullable(),
  materialsUsed: z.string().max(4000).optional().nullable(),
  tomorrowNotes: z.string().max(4000).optional().nullable(),
  progressPercent: z.coerce.number().int().min(0).max(100).optional().nullable(),
  // Supervisor-only
  siteProgress: z.string().max(4000).optional().nullable(),
});

const listQuery = z.object({
  date: z.string().regex(/^\d{4}-\d{2}-\d{2}$/).optional(),
  type: z.enum(['worker', 'supervisor']).optional(),
});

const listAllQuery = z.object({
  date: z.string().regex(/^\d{4}-\d{2}-\d{2}$/).optional(),
  type: z.enum(['worker', 'supervisor']).optional(),
  projectId: z.string().uuid().optional(),
  page: z.coerce.number().int().min(1).default(1),
  limit: z.coerce.number().int().min(1).max(100).default(30),
});

module.exports = { create, listQuery, listAllQuery };
