'use strict';

const { asyncHandler, ok } = require('../../utils/http');
const service = require('./dashboard.service');

const admin = asyncHandler(async (req, res) => ok(res, await service.admin()));
const supervisor = asyncHandler(async (req, res) => ok(res, await service.supervisor(req.user.id)));
const designer = asyncHandler(async (req, res) => ok(res, await service.designer(req.user.id)));
const worker = asyncHandler(async (req, res) => ok(res, await service.worker(req.user.id)));

module.exports = { admin, supervisor, designer, worker };
