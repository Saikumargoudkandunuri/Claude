'use strict';

const { asyncHandler, ok } = require('../../utils/http');
const service = require('./auth.service');

const register = asyncHandler(async (req, res) => {
  const user = await service.register(req.body);
  ok(res, { user, message: 'Registration received. Awaiting admin approval.' }, 201);
});

const login = asyncHandler(async (req, res) => {
  const result = await service.login(req.body);
  ok(res, result);
});

const refresh = asyncHandler(async (req, res) => {
  const tokens = await service.refresh(req.body);
  ok(res, tokens);
});

const logout = asyncHandler(async (req, res) => {
  await service.logout(req.body);
  res.status(204).send();
});

const me = asyncHandler(async (req, res) => {
  const user = await service.me(req.user.id);
  ok(res, user);
});

const updatePushToken = asyncHandler(async (req, res) => {
  await service.updatePushToken(req.user.id, req.body.pushToken);
  res.status(204).send();
});

const updateWorkerStatus = asyncHandler(async (req, res) => {
  const user = await service.updateWorkerStatus(req.user.id, req.body.status);
  ok(res, user);
});

module.exports = { register, login, refresh, logout, me, updatePushToken, updateWorkerStatus };
