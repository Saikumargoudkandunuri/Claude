'use strict';

const service = require('./weekly_status.service');

// GET /projects/:id/weekly-status — current week status
async function getCurrentStatus(req, res, next) {
  try {
    const data = await service.getProjectCurrentStatus(req.params.id);
    res.json({ data }); // data=null means not reviewed yet
  } catch (err) { next(err); }
}

// GET /projects/:id/weekly-status/history — last 12 weeks
async function getHistory(req, res, next) {
  try {
    const data = await service.getProjectStatusHistory(req.params.id);
    res.json({ data });
  } catch (err) { next(err); }
}

// PUT /projects/:id/weekly-status — set/update this week's status
async function setStatus(req, res, next) {
  try {
    const { status, notes } = req.body;
    const validStatuses = ['on_track', 'normal', 'slow'];
    if (!validStatuses.includes(status)) {
      return res.status(400).json({ error: { code: 'BAD_REQUEST', message: 'Invalid status. Must be on_track, normal, or slow.' } });
    }
    if (notes && notes.length > 200) {
      return res.status(400).json({ error: { code: 'BAD_REQUEST', message: 'Notes max 200 characters.' } });
    }

    const data = await service.setProjectStatus(
      req.params.id, req.user.id, req.user.role, { status, notes }
    );
    res.json({ data, message: 'Weekly status updated.' });
  } catch (err) {
    if (err.statusCode === 403) {
      return res.status(403).json({ error: { code: 'FORBIDDEN', message: err.message } });
    }
    next(err);
  }
}

// GET /dashboard/weekly-overview — all projects' current week status (admin only)
async function weeklyOverview(req, res, next) {
  try {
    const data = await service.getAllProjectsCurrentStatus();
    res.json({ data });
  } catch (err) { next(err); }
}

// GET /dashboard/needs-review — projects with no status this week
async function needsReview(req, res, next) {
  try {
    const data = await service.getProjectsNeedingReview(req.user.id, req.user.role);
    res.json({ data });
  } catch (err) { next(err); }
}

module.exports = { getCurrentStatus, getHistory, setStatus, weeklyOverview, needsReview };
