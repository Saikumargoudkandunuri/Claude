'use strict';

const { query } = require('../db/pool');

/**
 * Record an audit log entry. Accepts an optional pg client so it can run
 * inside the same transaction as the mutation it describes.
 *
 * @param {object} entry
 * @param {string|null} entry.userId
 * @param {string|null} [entry.projectId]
 * @param {string} entry.action       e.g. 'project.create'
 * @param {string} [entry.entityType]
 * @param {string} [entry.entityId]
 * @param {string} [entry.description]
 * @param {object} [entry.metadata]
 * @param {import('pg').PoolClient} [client]
 */
async function logActivity(entry, client) {
  const exec = client ? client.query.bind(client) : query;
  await exec(
    `INSERT INTO activity_logs
       (user_id, project_id, action, entity_type, entity_id, description, metadata)
     VALUES ($1,$2,$3,$4,$5,$6,$7)`,
    [
      entry.userId || null,
      entry.projectId || null,
      entry.action,
      entry.entityType || null,
      entry.entityId || null,
      entry.description || null,
      entry.metadata ? JSON.stringify(entry.metadata) : '{}',
    ]
  );
}

module.exports = { logActivity };
