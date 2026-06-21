'use strict';

const { z } = require('zod');

const STAGES = [
  'discussion', '3d_design', 'drawing', 'material_purchase', 'cutting', 'making',
  'lamination', 'painting', 'packing', 'transport', 'installation', 'checking', 'completed',
];

const dateString = z
  .string()
  .regex(/^\d{4}-\d{2}-\d{2}$/, 'Expected YYYY-MM-DD')
  .optional()
  .nullable();

const create = z.object({
  projectNumber: z.string().min(1).max(60),
  customerName: z.string().min(1).max(160),
  phone: z.string().min(6).max(20),
  altPhone: z.string().max(20).optional().nullable(),
  address: z.string().max(500).optional().nullable(),
  siteLocation: z.string().max(300).optional().nullable(),
  projectName: z.string().min(1).max(200),
  projectType: z.string().max(120).optional().nullable(),
  workDescription: z.string().max(4000).optional().nullable(),
  startDate: dateString,
  expectedCompletionDate: dateString,
  quotationAmount: z.coerce.number().min(0).default(0),
  supervisorId: z.string().uuid().optional().nullable(),
  designerId: z.string().uuid().optional().nullable(),
  remarks: z.string().max(2000).optional().nullable(),
});

const update = create.partial();

const listQuery = z.object({
  stage: z.enum(STAGES).optional(),
  q: z.string().optional(),
  assigned: z.literal('me').optional(),
  page: z.coerce.number().int().min(1).default(1),
  limit: z.coerce.number().int().min(1).max(100).default(20),
});

const setStage = z.object({
  stage: z.enum(STAGES),
  status: z.enum(['pending', 'in_progress', 'completed']).default('in_progress'),
  note: z.string().max(1000).optional().nullable(),
});

const assign = z.object({
  userId: z.string().uuid(),
  role: z.enum(['supervisor', 'designer', 'worker']),
  task: z.string().max(300).optional().nullable(),
});

module.exports = { STAGES, create, update, listQuery, setStage, assign };
