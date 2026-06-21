'use strict';

const express = require('express');
const controller = require('./auth.controller');
const schema = require('./auth.schema');
const { validate } = require('../../middleware/validate');
const { authenticate } = require('../../middleware/auth');
const { authLimiter } = require('../../middleware/rateLimit');

const router = express.Router();

router.post('/register', authLimiter, validate(schema.register), controller.register);
router.post('/login', authLimiter, validate(schema.login), controller.login);
router.post('/refresh', authLimiter, validate(schema.refresh), controller.refresh);
router.post('/logout', validate(schema.refresh), controller.logout);

router.get('/me', authenticate, controller.me);
router.put('/me/push-token', authenticate, validate(schema.pushToken), controller.updatePushToken);
router.put(
  '/me/worker-status',
  authenticate,
  validate(schema.workerStatus),
  controller.updateWorkerStatus
);

module.exports = router;
