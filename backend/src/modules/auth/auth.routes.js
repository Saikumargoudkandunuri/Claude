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
router.post('/forgot-password', authLimiter, validate(schema.forgotPassword), controller.forgotPassword);
router.post('/reset-password', authLimiter, validate(schema.resetPassword), controller.resetPassword);
router.post('/pin-login', authLimiter, validate(schema.pinLogin), controller.pinLoginCtrl);
router.post('/reset-pin-by-id', authLimiter, validate(schema.resetPinById), controller.resetPinByIdCtrl);
router.put('/me/pin', authenticate, validate(schema.changePin), controller.changePinCtrl);

router.get('/me', authenticate, controller.me);
router.put('/me', authenticate, validate(schema.updateProfile), controller.updateProfile);
router.put('/me/password', authenticate, validate(schema.changePassword), controller.changePassword);
router.put('/me/push-token', authenticate, validate(schema.pushToken), controller.updatePushToken);
router.put(
  '/me/worker-status',
  authenticate,
  validate(schema.workerStatus),
  controller.updateWorkerStatus
);

module.exports = router;
