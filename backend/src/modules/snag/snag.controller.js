'use strict';

const service = require('./snag.service');

async function create(req, res, next) {
  try {
    const item = await service.createSnagItem(req.params.projectId, req.body, req.user.id);
    res.status(201).json({ data: item });
  } catch (err) { next(err); }
}

async function list(req, res, next) {
  try {
    const items = await service.getSnagItems(req.params.projectId, req.query.status);
    const summary = await service.getProjectSnagSummary(req.params.projectId);
    res.json({ data: items, summary });
  } catch (err) { next(err); }
}

async function resolve(req, res, next) {
  try {
    const item = await service.resolveSnagItem(req.params.itemId, req.body, req.user.id);
    res.json({ data: item, message: 'Marked as resolved.' });
  } catch (err) {
    if (err.statusCode === 400) return res.status(400).json({ error: { message: err.message } });
    next(err);
  }
}

async function close(req, res, next) {
  try {
    const item = await service.closeSnagItem(req.params.itemId, req.user.id);
    res.json({ data: item, message: 'Snag item closed.' });
  } catch (err) {
    if (err.statusCode === 400) return res.status(400).json({ error: { message: err.message } });
    next(err);
  }
}

async function summary(req, res, next) {
  try {
    const s = await service.getProjectSnagSummary(req.params.projectId);
    res.json({ data: s });
  } catch (err) { next(err); }
}

module.exports = { create, list, resolve, close, summary };
