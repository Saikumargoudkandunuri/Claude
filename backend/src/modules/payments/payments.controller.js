'use strict';

const { asyncHandler, ok } = require('../../utils/http');
const service = require('./payments.service');

const get = asyncHandler(async (req, res) => {
  ok(res, await service.get(req.params.projectId));
});

const updateSummary = asyncHandler(async (req, res) => {
  ok(res, await service.updateSummary(req.user.id, req.params.projectId, req.body));
});

const addHistory = asyncHandler(async (req, res) => {
  ok(res, await service.addHistory(req.user.id, req.params.projectId, req.body), 201);
});

const removeHistory = asyncHandler(async (req, res) => {
  await service.removeHistory(req.user.id, req.params.id);
  res.status(204).send();
});

module.exports = { get, updateSummary, addHistory, removeHistory };
