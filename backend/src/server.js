'use strict';

const { createApp } = require('./app');
const config = require('./config');
const { pool } = require('./db/pool');
const { initSocket } = require('./socket');
const { run: runMigrations } = require('./db/migrate');

const app = createApp();

// Auto-run pending migrations on startup.
runMigrations()
  .then(() => {
    const server = app.listen(config.port, () => {
      console.log(`ICMS API listening on port ${config.port} (${config.env}) — prefix ${config.apiPrefix}`);
    });

    // Initialize Socket.IO for real-time messaging
    const io = initSocket(server, config);
    app.set('io', io);

    function shutdown(signal) {
      console.log(`\n${signal} received, shutting down...`);
      io.close();
      server.close(() => {
        pool.end().finally(() => process.exit(0));
      });
      setTimeout(() => process.exit(1), 10000).unref();
    }

    process.on('SIGINT', () => shutdown('SIGINT'));
    process.on('SIGTERM', () => shutdown('SIGTERM'));
  })
  .catch((err) => {
    console.error('Migration failed, starting server anyway:', err.message);
    // Start even if migrations fail so the existing endpoints still work
    const server = app.listen(config.port, () => {
      console.log(`ICMS API listening on port ${config.port} (${config.env}) — prefix ${config.apiPrefix}`);
    });

    const io = initSocket(server, config);
    app.set('io', io);

    function shutdown(signal) {
      console.log(`\n${signal} received, shutting down...`);
      io.close();
      server.close(() => {
        pool.end().finally(() => process.exit(0));
      });
      setTimeout(() => process.exit(1), 10000).unref();
    }

    process.on('SIGINT', () => shutdown('SIGINT'));
    process.on('SIGTERM', () => shutdown('SIGTERM'));
  });
