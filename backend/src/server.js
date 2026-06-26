'use strict';

const { createApp } = require('./app');
const config = require('./config');
const { pool } = require('./db/pool');
const { initSocket } = require('./socket');

const app = createApp();

const server = app.listen(config.port, () => {
  console.log(`ICMS API listening on port ${config.port} (${config.env}) — prefix ${config.apiPrefix}`);
});

// Initialize Socket.IO for real-time messaging
const io = initSocket(server, config);
app.set('io', io); // Make io accessible to route handlers via req.app.get('io')

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

module.exports = server;
