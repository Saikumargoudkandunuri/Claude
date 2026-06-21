'use strict';

const { Pool } = require('pg');
const config = require('../config');

const pool = new Pool(
  config.db.connectionString
    ? { connectionString: config.db.connectionString, ssl: config.db.ssl }
    : {
        host: config.db.host,
        port: config.db.port,
        user: config.db.user,
        password: config.db.password,
        database: config.db.database,
        ssl: config.db.ssl,
      }
);

pool.on('error', (err) => {
  // eslint-disable-next-line no-console
  console.error('Unexpected PostgreSQL pool error', err);
});

/**
 * Run a parameterized query.
 * @param {string} text
 * @param {Array} [params]
 */
function query(text, params) {
  return pool.query(text, params);
}

/**
 * Run a set of statements inside a single transaction.
 * The callback receives a dedicated client; commit/rollback handled here.
 * @param {(client: import('pg').PoolClient) => Promise<any>} callback
 */
async function withTransaction(callback) {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const result = await callback(client);
    await client.query('COMMIT');
    return result;
  } catch (err) {
    try {
      await client.query('ROLLBACK');
    } catch (_) {
      /* ignore rollback error */
    }
    throw err;
  } finally {
    client.release();
  }
}

module.exports = { pool, query, withTransaction };
