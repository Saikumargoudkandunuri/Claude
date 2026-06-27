'use strict';

const { asyncHandler, ok } = require('../../utils/http');
const service = require('./customer.service');

const checkMobile = asyncHandler(async (req, res) => {
  const result = await service.checkMobile(req.body.mobile);
  ok(res, result);
});

const setPin = asyncHandler(async (req, res) => {
  await service.setPin(req.body.mobile, req.body.pin);
  ok(res, { success: true });
});

const login = asyncHandler(async (req, res) => {
  const result = await service.login(req.body.mobile, req.body.pin);
  ok(res, result);
});

const getOverview = asyncHandler(async (req, res) => {
  const data = await service.getOverview(req.customer.projectId);
  ok(res, data);
});

const getTimeline = asyncHandler(async (req, res) => {
  const data = await service.getTimeline(req.customer.projectId);
  ok(res, data);
});

const getPhotos = asyncHandler(async (req, res) => {
  const data = await service.getPhotos(req.customer.projectId);
  ok(res, data);
});

const getDrawings = asyncHandler(async (req, res) => {
  const data = await service.getDrawings(req.customer.projectId);
  ok(res, data);
});

const getPayments = asyncHandler(async (req, res) => {
  const data = await service.getPayments(req.customer.projectId);
  ok(res, data);
});

const getNotifications = asyncHandler(async (req, res) => {
  const data = await service.getNotifications(req.customer.projectId);
  ok(res, data);
});

const markNotificationRead = asyncHandler(async (req, res) => {
  await service.markNotificationRead(req.params.id, req.customer.projectId);
  ok(res, { success: true });
});

const getMessages = asyncHandler(async (req, res) => {
  const data = await service.getMessages(req.customer.projectId);
  ok(res, data);
});

const postAnnouncement = asyncHandler(async (req, res) => {
  const { projectId, title, body } = req.body;
  await service.postAnnouncement(projectId, title, body, req.user.id);
  ok(res, { success: true }, 201);
});

const resetPin = asyncHandler(async (req, res) => {
  await service.resetPin(req.body.customerId);
  ok(res, { success: true });
});

const createCustomer = asyncHandler(async (req, res) => {
  const { fullName, mobile, projectId } = req.body;
  const result = await service.createCustomer(fullName, mobile, projectId);
  ok(res, result, 201);
});

module.exports = {
  checkMobile,
  setPin,
  login,
  getOverview,
  getTimeline,
  getPhotos,
  getDrawings,
  getPayments,
  getNotifications,
  markNotificationRead,
  getMessages,
  postAnnouncement,
  resetPin,
  createCustomer,
};
