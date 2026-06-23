'use strict';

const express = require('express');
const { z } = require('zod');
const controller = require('./assignments.controller');
const { validate } = require('../../middleware/validate');
const { requireRole } = require('../../middleware/rbac');

const createSchema = z.object({
  workerId: z.string().uuid(),
  date: z.string().regex(/^\d{4}-\d{2}-\d{2}$/).optional(),
  body: z.string().max(2000).optional().nullable(),
  tasks: z.array(z.string().max(300)).optional(),
});

const listSchema = z.object({
  date: z.string().regex(/^\d{4}-\d{2}-\d{2}$/).optional(),
});

const router = express.Router();

router.post(
  '/projects/:projectId/assignment-messages',
  requireRole('admin', 'supervisor'),
  validate(createSchema),
  controller.createBrief
);
router.get(
  '/projects/:projectId/assignment-messages',
  validate(listSchema, 'query'),
  controller.listBriefs
);

module.exports = router;
