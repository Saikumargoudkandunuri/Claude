'use strict';

const express = require('express');
const controller = require('./chat.controller');
const { z } = require('zod');
const { validate } = require('../../middleware/validate');

const createSchema = z.object({
  body: z.string().min(1).max(2000),
});

const router = express.Router();

router.get('/projects/:projectId/messages', controller.list);
router.post('/projects/:projectId/messages', validate(createSchema), controller.create);
router.delete('/messages/:id', controller.remove);

module.exports = router;
