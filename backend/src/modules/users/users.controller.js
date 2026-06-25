'use strict';

const { asyncHandler, ok, paginated } = require('../../utils/http');
const service = require('./users.service');

const list = asyncHandler(async (req, res) => {
  const { data, meta } = await service.list(req.query);
  paginated(res, data, meta);
});

const listPending = asyncHandler(async (req, res) => {
  ok(res, await service.listPending());
});

const approve = asyncHandler(async (req, res) => {
  ok(res, await service.approve(req.user.id, req.params.id, req.body.role));
});

const reject = asyncHandler(async (req, res) => {
  ok(res, await service.reject(req.user.id, req.params.id));
});

const setRole = asyncHandler(async (req, res) => {
  ok(res, await service.setRole(req.user.id, req.params.id, req.body.role));
});

const disable = asyncHandler(async (req, res) => {
  ok(res, await service.disable(req.user.id, req.params.id));
});

const assignable = asyncHandler(async (req, res) => {
  ok(res, await service.assignable(req.query.role));
});

const resetPin = asyncHandler(async (req, res) => {
  const authService = require('../auth/auth.service');
  await authService.adminSetPin(req.user.id, req.params.id, req.body.pin);
  res.status(204).send();
});

module.exports = { list, listPending, approve, reject, setRole, disable, assignable, resetPin };
