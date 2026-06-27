'use strict';

const express = require('express');
const { validate } = require('../../middleware/validate');
const { authenticateCustomer } = require('../../middleware/customerAuth');
const { customerLoginLimiter, customerCheckMobileLimiter } = require('../../middleware/rateLimit');
const { authenticate } = require('../../middleware/auth');
const { requireRole } = require('../../middleware/rbac');
const schema = require('./customer.schema');
const controller = require('./customer.controller');

const router = express.Router();

// --- Public auth routes (no auth middleware) ---
router.post('/customer/auth/check-mobile', customerCheckMobileLimiter, validate(schema.checkMobile), controller.checkMobile);
router.post('/customer/auth/set-pin', validate(schema.setPin), controller.setPin);
router.post('/customer/auth/login', customerLoginLimiter, validate(schema.login), controller.login);

// --- Customer-authenticated routes ---
router.get('/customer/overview', authenticateCustomer, controller.getOverview);
router.get('/customer/timeline', authenticateCustomer, controller.getTimeline);
router.get('/customer/photos', authenticateCustomer, controller.getPhotos);
router.get('/customer/drawings', authenticateCustomer, controller.getDrawings);
router.get('/customer/payments', authenticateCustomer, controller.getPayments);
router.get('/customer/notifications', authenticateCustomer, controller.getNotifications);
router.put('/customer/notifications/:id/read', authenticateCustomer, controller.markNotificationRead);
router.get('/customer/messages', authenticateCustomer, controller.getMessages);

// --- Admin routes (staff auth + admin role) ---
router.post('/customer/admin/announce', authenticate, requireRole('admin'), validate(schema.announce), controller.postAnnouncement);
router.post('/customer/admin/reset-pin', authenticate, requireRole('admin'), validate(schema.resetPin), controller.resetPin);
router.post('/customer/admin/create', authenticate, requireRole('admin'), validate(schema.createCustomer), controller.createCustomer);

module.exports = router;
