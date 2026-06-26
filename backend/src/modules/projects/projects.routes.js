'use strict';

const express = require('express');
const controller = require('./projects.controller');
const schema = require('./projects.schema');
const { validate } = require('../../middleware/validate');
const { requireRole } = require('../../middleware/rbac');

// Mounted at /projects (router already behind authenticate + requireApproved).
const router = express.Router();

router.get('/', validate(schema.listQuery, 'query'), controller.list);
router.post('/', requireRole('admin'), validate(schema.create), controller.create);

router.get('/:id', controller.getOne);
router.put('/:id', requireRole('admin'), validate(schema.update), controller.update);
router.delete('/:id', requireRole('admin'), controller.remove);
router.post('/:id/archive', requireRole('admin'), controller.remove);
router.post('/:id/unarchive', requireRole('admin'), controller.unarchive);

// Stages
router.get('/:id/stages', controller.getStages);
router.put(
  '/:id/stage',
  requireRole('admin', 'supervisor', 'designer'),
  validate(schema.setStage),
  controller.setStage
);

// Assignments
router.get('/:id/assignments', controller.listAssignments);
router.post(
  '/:id/assignments',
  requireRole('admin', 'supervisor'),
  validate(schema.assign),
  controller.addAssignment
);
router.delete(
  '/:id/assignments/:assignmentId',
  requireRole('admin', 'supervisor'),
  controller.removeAssignment
);

// Stage timeline for project detail (any authenticated user)
router.get('/:id/stage-timeline', async (req, res, next) => {
  try {
    const { query: dbQuery } = require('../../db/pool');

    const stageOrder = [
      'discussion', '3d_design', 'drawing', 'material_purchase', 'cutting',
      'making', 'lamination', 'painting', 'packing', 'transport',
      'installation', 'checking', 'completed'
    ];

    // Get current stage from projects
    const projectResult = await dbQuery(
      'SELECT current_stage FROM projects WHERE id = $1',
      [req.params.id]
    );
    if (projectResult.rows.length === 0) {
      return res.status(404).json({ error: { code: 'NOT_FOUND', message: 'Project not found' } });
    }
    const currentStage = projectResult.rows[0].current_stage;

    // Get stage history entries
    const historyResult = await dbQuery(
      `SELECT stage, status, changed_at
       FROM project_stage_history
       WHERE project_id = $1
       ORDER BY changed_at ASC`,
      [req.params.id]
    );

    // Build map of stage → history entry (latest per stage)
    const historyMap = {};
    historyResult.rows.forEach(row => { historyMap[row.stage] = row; });

    // Build timeline array
    const currentIndex = stageOrder.indexOf(currentStage);
    const timeline = stageOrder.map((stage, index) => {
      const history = historyMap[stage];
      let stageStatus;
      if (stage === currentStage) {
        stageStatus = 'current';
      } else if (index < currentIndex) {
        stageStatus = 'completed';
      } else {
        stageStatus = 'pending';
      }
      return {
        stage,
        index,
        status: stageStatus,
        changed_at: history?.changed_at || null,
        display_name: stage.replace(/_/g, ' ').replace(/\b\w/g, c => c.toUpperCase()),
      };
    });

    res.json({ data: { timeline, current_stage: currentStage } });
  } catch (err) { next(err); }
});

module.exports = router;
