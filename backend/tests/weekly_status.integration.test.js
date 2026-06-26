'use strict';

/**
 * Integration tests for Weekly Status module endpoints.
 * Validates all 5 API endpoints work correctly.
 */

const { createApp } = require('../src/app');
const { pool } = require('../src/db/pool');
const request = require('supertest');

let app;
let adminToken;
let supervisorToken;
let testProjectId;
let adminUserId;
let supervisorUserId;
let hasSupervisor = false;

beforeAll(async () => {
  app = createApp();

  // Get an admin user for testing
  const { rows: admins } = await pool.query(
    `SELECT id FROM users WHERE role = 'admin' AND status = 'approved' LIMIT 1`
  );

  if (!admins.length) {
    throw new Error('Need at least one admin user in DB for tests');
  }

  adminUserId = admins[0].id;

  // Check if a supervisor exists
  const { rows: supervisors } = await pool.query(
    `SELECT id FROM users WHERE role = 'supervisor' AND status = 'approved' LIMIT 1`
  );
  if (supervisors.length) {
    hasSupervisor = true;
    supervisorUserId = supervisors[0].id;
  }

  // Generate JWT tokens for testing (matches utils/jwt.js signAccessToken format)
  const jwt = require('jsonwebtoken');
  const config = require('../src/config');

  adminToken = jwt.sign(
    { sub: adminUserId, role: 'admin' },
    config.jwt.accessSecret,
    { expiresIn: '1h' }
  );

  if (hasSupervisor) {
    supervisorToken = jwt.sign(
      { sub: supervisorUserId, role: 'supervisor' },
      config.jwt.accessSecret,
      { expiresIn: '1h' }
    );
  }

  // Get a test project
  const { rows: projects } = await pool.query(
    `SELECT id FROM projects LIMIT 1`
  );
  if (!projects.length) {
    throw new Error('Need at least one project in DB for tests');
  }
  testProjectId = projects[0].id;

  // Clean up any existing weekly status for this project's current week
  const { getCurrentWeekMonday } = require('../src/modules/weekly_status/weekly_status.service');
  const weekStart = getCurrentWeekMonday();
  await pool.query(
    `DELETE FROM project_weekly_status WHERE project_id = $1 AND week_start = $2`,
    [testProjectId, weekStart]
  );
});

afterAll(async () => {
  // Clean up test data
  const { getCurrentWeekMonday } = require('../src/modules/weekly_status/weekly_status.service');
  const weekStart = getCurrentWeekMonday();
  await pool.query(
    `DELETE FROM project_weekly_status WHERE project_id = $1 AND week_start = $2`,
    [testProjectId, weekStart]
  );
  await pool.end();
});

describe('Weekly Status API Endpoints', () => {
  const apiPrefix = '/api/v1';

  describe('GET /projects/:id/weekly-status', () => {
    it('should return null when no status is set for current week', async () => {
      const res = await request(app)
        .get(`${apiPrefix}/projects/${testProjectId}/weekly-status`)
        .set('Authorization', `Bearer ${adminToken}`);

      expect(res.status).toBe(200);
      expect(res.body).toHaveProperty('data');
      expect(res.body.data).toBeNull();
    });
  });

  describe('PUT /projects/:id/weekly-status', () => {
    it('should set status with valid values and return 200', async () => {
      const res = await request(app)
        .put(`${apiPrefix}/projects/${testProjectId}/weekly-status`)
        .set('Authorization', `Bearer ${adminToken}`)
        .send({ status: 'on_track', notes: 'All good this week' });

      expect(res.status).toBe(200);
      expect(res.body).toHaveProperty('data');
      expect(res.body.data.status).toBe('on_track');
      expect(res.body.data.notes).toBe('All good this week');
      expect(res.body.data.project_id).toBe(testProjectId);
    });

    it('should return 400 for invalid status value', async () => {
      const res = await request(app)
        .put(`${apiPrefix}/projects/${testProjectId}/weekly-status`)
        .set('Authorization', `Bearer ${adminToken}`)
        .send({ status: 'invalid_status' });

      expect(res.status).toBe(400);
      expect(res.body).toHaveProperty('error');
    });

    it('should return 400 for notes exceeding 200 chars', async () => {
      const res = await request(app)
        .put(`${apiPrefix}/projects/${testProjectId}/weekly-status`)
        .set('Authorization', `Bearer ${adminToken}`)
        .send({ status: 'on_track', notes: 'x'.repeat(201) });

      expect(res.status).toBe(400);
      expect(res.body).toHaveProperty('error');
    });

    it('should upsert (update) when setting status again in the same week', async () => {
      const res = await request(app)
        .put(`${apiPrefix}/projects/${testProjectId}/weekly-status`)
        .set('Authorization', `Bearer ${adminToken}`)
        .send({ status: 'slow', notes: 'Changed my mind' });

      expect(res.status).toBe(200);
      expect(res.body.data.status).toBe('slow');
      expect(res.body.data.notes).toBe('Changed my mind');
    });
  });

  describe('GET /projects/:id/weekly-status (after set)', () => {
    it('should return the current week status after it has been set', async () => {
      const res = await request(app)
        .get(`${apiPrefix}/projects/${testProjectId}/weekly-status`)
        .set('Authorization', `Bearer ${adminToken}`);

      expect(res.status).toBe(200);
      expect(res.body.data).not.toBeNull();
      expect(res.body.data.status).toBe('slow');
    });
  });

  describe('GET /projects/:id/weekly-status/history', () => {
    it('should return an array of status records', async () => {
      const res = await request(app)
        .get(`${apiPrefix}/projects/${testProjectId}/weekly-status/history`)
        .set('Authorization', `Bearer ${adminToken}`);

      expect(res.status).toBe(200);
      expect(res.body).toHaveProperty('data');
      expect(Array.isArray(res.body.data)).toBe(true);
      expect(res.body.data.length).toBeGreaterThanOrEqual(1);
    });
  });

  describe('GET /dashboard/weekly-overview', () => {
    it('should return a map object (admin only)', async () => {
      const res = await request(app)
        .get(`${apiPrefix}/dashboard/weekly-overview`)
        .set('Authorization', `Bearer ${adminToken}`);

      expect(res.status).toBe(200);
      expect(res.body).toHaveProperty('data');
      expect(typeof res.body.data).toBe('object');
      // Should have our test project in the map
      expect(res.body.data).toHaveProperty(testProjectId);
    });
  });

  describe('GET /dashboard/needs-review', () => {
    it('should return an array of projects needing review', async () => {
      const res = await request(app)
        .get(`${apiPrefix}/dashboard/needs-review`)
        .set('Authorization', `Bearer ${adminToken}`);

      expect(res.status).toBe(200);
      expect(res.body).toHaveProperty('data');
      expect(Array.isArray(res.body.data)).toBe(true);
      // Our test project should NOT be in the list since we set a status
      const ids = res.body.data.map(p => p.id);
      expect(ids).not.toContain(testProjectId);
    });
  });

  describe('RBAC enforcement', () => {
    it('should reject unauthenticated requests', async () => {
      const res = await request(app)
        .get(`${apiPrefix}/projects/${testProjectId}/weekly-status`);

      expect(res.status).toBe(401);
    });

    it('should restrict weekly-overview to admin only (reject supervisor)', async () => {
      if (!hasSupervisor) {
        // Generate a fake supervisor token using the designer user as a stand-in
        const jwt = require('jsonwebtoken');
        const config = require('../src/config');
        const { rows } = await pool.query(
          `SELECT id FROM users WHERE role = 'designer' AND status = 'approved' LIMIT 1`
        );
        if (rows.length) {
          const designerToken = jwt.sign(
            { sub: rows[0].id, role: 'designer' },
            config.jwt.accessSecret,
            { expiresIn: '1h' }
          );
          // Designer should also be forbidden from weekly-overview (admin-only)
          const res = await request(app)
            .get(`${apiPrefix}/dashboard/weekly-overview`)
            .set('Authorization', `Bearer ${designerToken}`);
          expect(res.status).toBe(403);
        }
        return;
      }

      const res = await request(app)
        .get(`${apiPrefix}/dashboard/weekly-overview`)
        .set('Authorization', `Bearer ${supervisorToken}`);

      expect(res.status).toBe(403);
    });
  });
});
