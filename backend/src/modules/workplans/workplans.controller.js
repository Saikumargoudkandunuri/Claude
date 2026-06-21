'use strict';

const { asyncHandler, ok } = require('../../utils/http');
const service = require('./workplans.service');

const list = asyncHandler(async (req, res) => {
  ok(res, await service.listForProject(req.user, req.params.projectId, req.query));
});

const create = asyncHandler(async (req, res) => {
  ok(res, await service.create(req.user, req.params.projectId, req.body), 201);
});

const forMe = asyncHandler(async (req, res) => {
  ok(res, await service.forMe(req.user, req.query.date));
});

const remove = asyncHandler(async (req, res) => {
  await service.remove(req.user, req.params.id);
  res.status(204).send();
});

module.exports = { list, create, forMe, remove };
