'use strict';

const { asyncHandler, ok } = require('../../utils/http');
const service = require('./attendance.service');

const checkIn = asyncHandler(async (req, res) => {
  const result = await service.checkIn(req.user.id, req.body);
  ok(res, result, 201);
});

const checkOut = asyncHandler(async (req, res) => {
  const result = await service.checkOut(req.user.id, req.body);
  ok(res, result);
});

const myToday = asyncHandler(async (req, res) => {
  ok(res, await service.myToday(req.user.id));
});

const listAttendance = asyncHandler(async (req, res) => {
  ok(res, await service.listAttendance(req.query));
});

const monthlySummary = asyncHandler(async (req, res) => {
  ok(res, await service.monthlySummary(req.params.userId, req.query.month));
});

const todayStatus = asyncHandler(async (req, res) => {
  ok(res, await service.getTodayStatus(req.user.id));
});

const workerHistory = asyncHandler(async (req, res) => {
  ok(res, await service.getWorkerHistory(req.user.id));
});

const reportLocation = asyncHandler(async (req, res) => {
  ok(res, await service.reportLocation(req.user.id, req.body));
});

const getPendingAlert = asyncHandler(async (req, res) => {
  ok(res, await service.getPendingAlert(req.user.id));
});

const resolveAlert = asyncHandler(async (req, res) => {
  ok(res, await service.resolveAlert(req.user.id, req.params.alertId, req.body.action));
});

const getPendingAlerts = asyncHandler(async (req, res) => {
  ok(res, await service.getPendingAlerts());
});

module.exports = { checkIn, checkOut, myToday, todayStatus, workerHistory, listAttendance, monthlySummary, reportLocation, getPendingAlert, resolveAlert, getPendingAlerts };
