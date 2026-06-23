'use strict';

const { z } = require('zod');

const updateSummary = z.object({
  quotationAmount: z.coerce.number().min(0),
});

const addHistory = z.object({
  kind: z.enum(['advance', 'second', 'third', 'final', 'other']).default('other'),
  amount: z.coerce.number().min(0),
  paidOn: z.string().regex(/^\d{4}-\d{2}-\d{2}$/).optional(),
  method: z.string().max(60).optional().nullable(),
  referenceNumber: z.string().max(120).optional().nullable(),
  remarks: z.string().max(1000).optional().nullable(),
});

const updateHistory = z.object({
  kind: z.enum(['advance', 'second', 'third', 'final', 'other']).optional(),
  amount: z.coerce.number().min(0).optional(),
  paidOn: z.string().regex(/^\d{4}-\d{2}-\d{2}$/).optional(),
  method: z.string().max(60).optional().nullable(),
  referenceNumber: z.string().max(120).optional().nullable(),
  remarks: z.string().max(1000).optional().nullable(),
});

const clear = z.object({
  method: z.string().max(60).optional().nullable(),
  referenceNumber: z.string().max(120).optional().nullable(),
  remarks: z.string().max(1000).optional().nullable(),
});

const received = z.object({
  amount: z.coerce.number().positive(),
  paidOn: z.string().regex(/^\d{4}-\d{2}-\d{2}$/).optional(),
  paymentMode: z.enum(['cash', 'bank_transfer', 'cheque', 'upi', 'other']).optional(),
  kind: z.enum(['advance', 'second', 'third', 'final', 'other']).optional(),
  referenceNumber: z.string().max(120).optional().nullable(),
  note: z.string().max(1000).optional().nullable(),
});

module.exports = { updateSummary, addHistory, updateHistory, clear, received };
