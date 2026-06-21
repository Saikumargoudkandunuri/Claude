'use strict';

const { query, withTransaction } = require('../../db/pool');
const { ApiError } = require('../../utils/http');
const { hashPassword, comparePassword } = require('../../utils/password');
const {
  signAccessToken,
  generateRefreshToken,
  hashToken,
  refreshExpiryDate,
} = require('../../utils/jwt');
const { logActivity } = require('../../utils/activity');
const { notifyAdmins } = require('../../utils/notify');

function publicUser(u) {
  return {
    id: u.id,
    fullName: u.full_name,
    email: u.email,
    phone: u.phone,
    role: u.role,
    status: u.status,
    workerStatus: u.worker_status,
  };
}

async function issueTokens(user) {
  const accessToken = signAccessToken(user);
  const refreshToken = generateRefreshToken();
  await query(
    `INSERT INTO refresh_tokens (user_id, token_hash, expires_at)
     VALUES ($1,$2,$3)`,
    [user.id, hashToken(refreshToken), refreshExpiryDate()]
  );
  return { accessToken, refreshToken };
}

async function register({ fullName, email, phone, password }) {
  const existing = await query('SELECT id FROM users WHERE email = $1', [email]);
  if (existing.rows.length > 0) {
    throw ApiError.conflict('An account with this email already exists');
  }

  const passwordHash = await hashPassword(password);
  const user = await withTransaction(async (client) => {
    const { rows } = await client.query(
      `INSERT INTO users (full_name, email, phone, password_hash, status)
       VALUES ($1,$2,$3,$4,'pending')
       RETURNING *`,
      [fullName, email, phone, passwordHash]
    );
    const created = rows[0];
    await logActivity(
      {
        userId: created.id,
        action: 'user.register',
        entityType: 'user',
        entityId: created.id,
        description: `${fullName} registered and is pending approval`,
      },
      client
    );
    // Notify admins of the new registration request.
    await notifyAdmins(
      {
        type: 'user.registration',
        title: 'New registration request',
        body: `${fullName} (${email}) is awaiting approval`,
        data: { route: 'icms://approvals', userId: created.id },
      },
      client
    );
    return created;
  });

  return publicUser(user);
}

async function login({ email, password }) {
  const { rows } = await query('SELECT * FROM users WHERE email = $1', [email]);
  const user = rows[0];
  if (!user) throw ApiError.unauthorized('Invalid email or password');

  const valid = await comparePassword(password, user.password_hash);
  if (!valid) throw ApiError.unauthorized('Invalid email or password');

  if (user.status === 'rejected') throw ApiError.forbidden('Your registration was rejected');
  if (user.status === 'disabled') throw ApiError.forbidden('Your account is disabled');

  const tokens = await issueTokens(user);
  return { ...tokens, user: publicUser(user) };
}

async function refresh({ refreshToken }) {
  const tokenHash = hashToken(refreshToken);
  const { rows } = await query(
    `SELECT rt.*, u.id AS uid, u.role, u.status
       FROM refresh_tokens rt
       JOIN users u ON u.id = rt.user_id
      WHERE rt.token_hash = $1`,
    [tokenHash]
  );
  const record = rows[0];
  if (!record || record.revoked || new Date(record.expires_at) < new Date()) {
    throw ApiError.unauthorized('Invalid or expired refresh token');
  }

  // Rotate: revoke the old token and issue a new pair.
  return withTransaction(async (client) => {
    await client.query('UPDATE refresh_tokens SET revoked = true WHERE id = $1', [record.id]);
    const user = { id: record.uid, role: record.role, status: record.status };
    const accessToken = signAccessToken(user);
    const newRefresh = generateRefreshToken();
    await client.query(
      `INSERT INTO refresh_tokens (user_id, token_hash, expires_at) VALUES ($1,$2,$3)`,
      [user.id, hashToken(newRefresh), refreshExpiryDate()]
    );
    return { accessToken, refreshToken: newRefresh };
  });
}

async function logout({ refreshToken }) {
  await query('UPDATE refresh_tokens SET revoked = true WHERE token_hash = $1', [
    hashToken(refreshToken),
  ]);
}

async function me(userId) {
  const { rows } = await query('SELECT * FROM users WHERE id = $1', [userId]);
  if (!rows[0]) throw ApiError.notFound('User not found');
  return publicUser(rows[0]);
}

async function updatePushToken(userId, pushToken) {
  await query('UPDATE users SET push_token = $1 WHERE id = $2', [pushToken, userId]);
}

async function updateWorkerStatus(userId, status) {
  const { rows } = await query(
    'UPDATE users SET worker_status = $1 WHERE id = $2 RETURNING *',
    [status, userId]
  );
  return publicUser(rows[0]);
}

module.exports = {
  publicUser,
  register,
  login,
  refresh,
  logout,
  me,
  updatePushToken,
  updateWorkerStatus,
};
