'use strict';

const { z } = require('zod');

const approve = z.object({
  role: z.enum(['admin', 'supervisor', 'designer', 'worker']),
});

const setRole = z.object({
  role: z.enum(['admin', 'supervisor', 'designer', 'worker']),
});

const listQuery = z.object({
  status: z.enum(['pending', 'approved', 'rejected', 'disabled']).optional(),
  role: z.enum(['admin', 'supervisor', 'designer', 'worker']).optional(),
  q: z.string().optional(),
  page: z.coerce.number().int().min(1).default(1),
  limit: z.coerce.number().int().min(1).max(100).default(20),
});

const assignableQuery = z.object({
  role: z.enum(['supervisor', 'designer', 'worker']),
});

const resetPin = z.object({
  pin: z.string().length(4),
});

module.exports = { approve, setRole, listQuery, assignableQuery, resetPin };
