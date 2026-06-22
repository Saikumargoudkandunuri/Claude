'use strict';

const { asyncHandler, ok, paginated } = require('../../utils/http');
const service = require('./projects.service');

const list = asyncHandler(async (req, res) => {
  const { data, meta } = await service.list(req.user, req.query);
  paginated(res, data, meta);
});

const getOne = asyncHandler(async (req, res) => {
  ok(res, await service.getOne(req.user, req.params.id));
});

const create = asyncHandler(async (req, res) => {
  ok(res, await service.create(req.user.id, req.body), 201);
});

const update = asyncHandler(async (req, res) => {
  ok(res, await service.update(req.user.id, req.params.id, req.body));
});

const remove = asyncHandler(async (req, res) => {
  await service.remove(req.user.id, req.params.id);
  res.status(204).send();
});

const unarchive = asyncHandler(async (req, res) => {
  await service.unarchive(req.user.id, req.params.id);
  res.status(204).send();
});

const getStages = asyncHandler(async (req, res) => {
  ok(res, await service.getStages(req.user, req.params.id));
});

const setStage = asyncHandler(async (req, res) => {
  ok(res, await service.setStage(req.user, req.params.id, req.body));
});

const listAssignments = asyncHandler(async (req, res) => {
  ok(res, await service.listAssignments(req.user, req.params.id));
});

const addAssignment = asyncHandler(async (req, res) => {
  ok(res, await service.addAssignment(req.user, req.params.id, req.body), 201);
});

const removeAssignment = asyncHandler(async (req, res) => {
  await service.removeAssignment(req.user, req.params.id, req.params.assignmentId);
  res.status(204).send();
});

module.exports = {
  list,
  getOne,
  create,
  update,
  remove,
  unarchive,
  getStages,
  setStage,
  listAssignments,
  addAssignment,
  removeAssignment,
};
