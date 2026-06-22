'use strict';

const express = require('express');
const controller = require('./expenses.controller');
const schema = require('./expenses.schema');
const { validate } = require('../../middleware/validate');
const { requireRole } = require('../../middleware/rbac');

const router = express.Router();

router.use(requireRole('admin'));
router.get('/projects/:projectId/expenses', controller.list);
router.get('/projects/:projectId/expenses/summary', controller.summary);
router.post('/projects/:projectId/expenses', validate(schema.create), controller.create);
router.delete('/expenses/:id', controller.remove);

module.exports = router;
