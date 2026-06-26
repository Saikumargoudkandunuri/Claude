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

module.exports = { checkIn, checkOut, myToday, listAttendance, monthlySummary };
