'use strict';

const { query } = require('../db/pool');
const config = require('../config');

/**
 * Create an in-app notification and (best-effort) send a push message.
 * Safe to call without a transaction; never throws on push failure.
 *
 * @param {object} n
 * @param {string} n.userId
 * @param {string} n.type
 * @param {string} n.title
 * @param {string} [n.body]
 * @param {string} [n.projectId]
 * @param {object} [n.data]
 * @param {import('pg').PoolClient} [client]
 */
async function createNotification(n, client) {
  const exec = client ? client.query.bind(client) : query;
  const { rows } = await exec(
    `INSERT INTO notifications (user_id, type, title, body, project_id, data)
     VALUES ($1,$2,$3,$4,$5,$6)
     RETURNING *`,
    [n.userId, n.type, n.title, n.body || null, n.projectId || null, JSON.stringify(n.data || {})]
  );

  // Best-effort push (does not block / fail the request)
  sendPush(n.userId, n.title, n.body, n.data).catch(() => {});

  return rows[0];
}

/** Create the same notification for many users. */
async function notifyUsers(userIds, payload, client) {
  const unique = [...new Set(userIds.filter(Boolean))];
  await Promise.all(unique.map((userId) => createNotification({ ...payload, userId }, client)));
}

/** Notify every approved admin (e.g. new registration, payment update). */
async function notifyAdmins(payload, client) {
  const exec = client ? client.query.bind(client) : query;
  const { rows } = await exec(
    `SELECT id FROM users WHERE role = 'admin' AND status = 'approved'`
  );
  await notifyUsers(rows.map((r) => r.id), payload, client);
}

/**
 * Fire-and-forget FCM push. Returns silently if no server key configured
 * or the user has no push token. In INTEGRATIONS_ONLY/dev this no-ops.
 */
async function sendPush(userId, title, body, data) {
  if (!config.fcm.serverKey) return;
  const { rows } = await query('SELECT push_token FROM users WHERE id = $1', [userId]);
  const token = rows[0]?.push_token;
  if (!token) return;

  try {
    await fetch('https://fcm.googleapis.com/fcm/send', {
      method: 'POST',
      headers: {
        Authorization: `key=${config.fcm.serverKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        to: token,
        notification: { title, body: body || '' },
        data: data || {},
      }),
    });
  } catch (_) {
    /* swallow push errors */
  }
}

module.exports = { createNotification, notifyUsers, notifyAdmins, sendPush };
