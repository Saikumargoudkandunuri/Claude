'use strict';

const { z } = require('zod');

const create = z.object({
  stage: z.string().optional().nullable(),
  category: z.enum(['material', 'labour', 'transport', 'equipment', 'other']).default('material'),
  description: z.string().min(1).max(500),
  amount: z.coerce.number().positive(),
  spentOn: z.string().regex(/^\d{4}-\d{2}-\d{2}$/).optional(),
});

module.exports = { create };
