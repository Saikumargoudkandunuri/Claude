'use strict';

const { createApp } = require('./app');
const config = require('./config');
const { pool } = require('./db/pool');

const app = createApp();

const server = app.listen(config.port, () => {
  // eslint-disable-next-line no-console
  console.log(`ICMS API listening on port ${config.port} (${config.env}) — prefix ${config.apiPrefix}`);
});

function shutdown(signal) {
  // eslint-disable-next-line no-console
  console.log(`\n${signal} received, shutting down...`);
  server.close(() => {
    pool.end().finally(() => process.exit(0));
  });
  // Force exit if it hangs
  setTimeout(() => process.exit(1), 10000).unref();
}

process.on('SIGINT', () => shutdown('SIGINT'));
process.on('SIGTERM', () => shutdown('SIGTERM'));

module.exports = server;
