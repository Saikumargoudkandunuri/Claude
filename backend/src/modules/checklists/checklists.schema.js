'use strict';

const { z } = require('zod');
const { STAGES } = require('../projects/projects.schema');

const create = z.object({
  stage: z.enum(STAGES),
  itemName: z.string().min(1).max(300),
  quantity: z.string().max(60).optional().nullable(),
  unit: z.string().max(30).optional().nullable(),
});

const update = z.object({
  status: z.enum(['pending', 'ordered', 'received', 'not_needed']).optional(),
  notes: z.string().max(1000).optional().nullable(),
  itemName: z.string().min(1).max(300).optional(),
  quantity: z.string().max(60).optional().nullable(),
  unit: z.string().max(30).optional().nullable(),
});

module.exports = { create, update };
