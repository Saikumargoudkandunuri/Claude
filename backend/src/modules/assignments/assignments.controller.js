'use strict';

const { asyncHandler, ok } = require('../../utils/http');
const service = require('./assignments.service');

const createBrief = asyncHandler(async (req, res) => {
  ok(res, await service.createBrief(req.user, req.params.projectId, req.body), 201);
});

const listBriefs = asyncHandler(async (req, res) => {
  ok(res, await service.listBriefs(req.user, req.params.projectId, req.query));
});

module.exports = { createBrief, listBriefs };
