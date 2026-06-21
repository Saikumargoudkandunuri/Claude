'use strict';

const express = require('express');
const helmet = require('helmet');
const cors = require('cors');
const pinoHttp = require('pino-http');

const config = require('./config');
const { pool } = require('./db/pool');
const { authenticate, requireApproved } = require('./middleware/auth');
const { apiLimiter } = require('./middleware/rateLimit');
const { errorHandler } = require('./middleware/error');
const { notFound } = require('./middleware/notFound');

// Routers
const authRoutes = require('./modules/auth/auth.routes');
const usersRoutes = require('./modules/users/users.routes');
const projectsRoutes = require('./modules/projects/projects.routes');
const filesRoutes = require('./modules/drawings/files.routes');
const reportsRoutes = require('./modules/reports/reports.routes');
const workplansRoutes = require('./modules/workplans/workplans.routes');
const paymentsRoutes = require('./modules/payments/payments.routes');
const notificationsRoutes = require('./modules/notifications/notifications.routes');
const activityRoutes = require('./modules/activity/activity.routes');
const dashboardRoutes = require('./modules/dashboard/dashboard.routes');

function createApp() {
  const app = express();

  app.set('trust proxy', 1);
  app.use(helmet());
  app.use(
    cors({
      origin: config.corsOrigins.includes('*') ? true : config.corsOrigins,
      credentials: true,
    })
  );
  app.use(express.json({ limit: '2mb' }));
  app.use(express.urlencoded({ extended: true }));
  app.use(
    pinoHttp({
      level: config.isProd ? 'info' : 'debug',
      autoLogging: !config.isProd,
    })
  );

  // Health checks (public, outside API prefix)
  app.get('/health', (_req, res) => res.json({ status: 'ok', uptime: process.uptime() }));
  app.get('/health/db', async (_req, res) => {
    try {
      await pool.query('SELECT 1');
      res.json({ status: 'ok', db: 'up' });
    } catch (err) {
      res.status(503).json({ status: 'error', db: 'down' });
    }
  });

  const api = express.Router();

  // Public auth endpoints (register/login/refresh) + a few authenticated ones.
  api.use('/auth', authRoutes);

  // Everything below requires a valid, approved account.
  api.use(apiLimiter);
  api.use(authenticate, requireApproved);

  api.use('/users', usersRoutes);
  api.use('/projects', projectsRoutes);
  api.use('/notifications', notificationsRoutes);
  api.use('/dashboard', dashboardRoutes);

  // Routers that declare absolute paths (mix of /projects/:id/... and flat).
  api.use('/', filesRoutes);
  api.use('/', reportsRoutes);
  api.use('/', workplansRoutes);
  api.use('/', paymentsRoutes);
  api.use('/', activityRoutes);

  app.use(config.apiPrefix, api);

  app.use(notFound);
  app.use(errorHandler);

  return app;
}

module.exports = { createApp };
