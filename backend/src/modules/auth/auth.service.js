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
    avatarUrl: u.avatar_url || null,
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

  // FIX-12: Token reuse detection — if the token is not found or already revoked,
  // it may be a stolen/reused token. Revoke ALL tokens for safety.
  if (!record) {
    throw ApiError.unauthorized('Invalid or expired refresh token');
  }
  if (record.revoked) {
    // Reuse detected — revoke all tokens for this user (security measure).
    await query('UPDATE refresh_tokens SET revoked = true WHERE user_id = $1', [record.user_id]);
    throw ApiError.unauthorized('Session invalidated for security. Please log in again.');
  }
  if (new Date(record.expires_at) < new Date()) {
    throw ApiError.unauthorized('Refresh token expired');
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

async function updateProfile(userId, { fullName, phone }) {
  const sets = [];
  const params = [];
  if (fullName) { params.push(fullName); sets.push(`full_name = $${params.length}`); }
  if (phone) { params.push(phone); sets.push(`phone = $${params.length}`); }
  if (sets.length === 0) throw ApiError.badRequest('Nothing to update');
  params.push(userId);
  const { rows } = await query(
    `UPDATE users SET ${sets.join(', ')} WHERE id = $${params.length} RETURNING *`,
    params
  );
  return publicUser(rows[0]);
}

async function changePassword(userId, { currentPassword, newPassword }) {
  const { rows } = await query('SELECT password_hash FROM users WHERE id = $1', [userId]);
  if (!rows[0]) throw ApiError.notFound('User not found');
  const valid = await comparePassword(currentPassword, rows[0].password_hash);
  if (!valid) throw ApiError.forbidden('Current password is incorrect');
  const hash = await hashPassword(newPassword);
  await query('UPDATE users SET password_hash = $1 WHERE id = $2', [hash, userId]);
}

async function forgotPassword(email) {
  const { rows } = await query('SELECT id, full_name FROM users WHERE email = $1', [email]);
  if (!rows[0]) return; // Don't reveal if email exists
  const otp = String(Math.floor(100000 + Math.random() * 900000));
  // Store OTP with 10 min expiry
  await query(
    `UPDATE users SET reset_otp = $1, reset_otp_expires = now() + interval '10 minutes' WHERE id = $2`,
    [otp, rows[0].id]
  );
  // In production, send via SMS/email. For now log it.
  console.log(`[OTP] Password reset OTP for ${email}: ${otp}`);
  return { message: 'If this email exists, a reset OTP has been sent.' };
}

async function resetPassword({ email, otp, newPassword }) {
  const { rows } = await query(
    `SELECT id FROM users WHERE email = $1 AND reset_otp = $2 AND reset_otp_expires > now()`,
    [email, otp]
  );
  if (!rows[0]) throw ApiError.forbidden('Invalid or expired OTP');
  const hash = await hashPassword(newPassword);
  await query(
    'UPDATE users SET password_hash = $1, reset_otp = NULL, reset_otp_expires = NULL WHERE id = $2',
    [hash, rows[0].id]
  );
}

/**
 * PIN-based phone login.
 * Normalizes phone to handle +91, 91, or plain 10-digit formats.
 */
async function pinLogin(phone, pin) {
  const digits = phone.replace(/[^0-9]/g, '');
  const last10 = digits.slice(-10);

  const { rows: users } = await query(
    `SELECT * FROM users
     WHERE phone = $1 OR phone = $2 OR phone = $3
        OR RIGHT(REPLACE(REPLACE(phone, ' ', ''), '-', ''), 10) = $4
     LIMIT 1`,
    [phone, `+91${last10}`, last10, last10]
  );

  const user = users[0];
  if (!user) throw ApiError.unauthorized('Invalid mobile number or PIN');
  if (user.status === 'disabled') throw ApiError.forbidden('Account is disabled');
  if (user.status === 'rejected') throw ApiError.forbidden('Account was rejected');
  if (user.status === 'pending') throw ApiError.forbidden('Account pending admin approval');

  if (!user.pin_hash) throw ApiError.forbidden('PIN not set. Contact administrator.');

  const valid = await comparePassword(pin, user.pin_hash);
  if (!valid) throw ApiError.unauthorized('Invalid mobile number or PIN');

  const tokens = await issueTokens(user);
  await logActivity({
    userId: user.id,
    action: 'auth.pin_login',
    entityType: 'user',
    entityId: user.id,
    description: 'Logged in via PIN',
  });

  return { ...tokens, user: publicUser(user) };
}

/**
 * Change PIN for the currently authenticated user.
 */
async function changePin(userId, currentPin, newPin) {
  const { rows } = await query('SELECT pin_hash FROM users WHERE id = $1', [userId]);
  if (!rows[0]) throw ApiError.notFound('User not found');
  if (!rows[0].pin_hash) throw ApiError.forbidden('PIN not set. Contact administrator.');
  const valid = await comparePassword(currentPin, rows[0].pin_hash);
  if (!valid) throw ApiError.forbidden('Current PIN is incorrect');
  const hash = await hashPassword(newPin);
  await query('UPDATE users SET pin_hash = $1 WHERE id = $2', [hash, userId]);
}

/**
 * Admin sets/resets a user's PIN.
 */
async function adminSetPin(adminId, targetUserId, pin) {
  const hash = await hashPassword(pin);
  await query('UPDATE users SET pin_hash = $1 WHERE id = $2', [hash, targetUserId]);
  await logActivity({
    userId: adminId,
    action: 'user.pin_reset',
    entityType: 'user',
    entityId: targetUserId,
    description: 'Admin reset user PIN',
  });
}

/**
 * Self-service PIN reset using Employee ID.
 */
async function resetPinById(userId, newPin) {
  const { rows } = await query('SELECT id FROM users WHERE id = $1', [userId]);
  if (!rows[0]) throw ApiError.notFound('Invalid Employee ID');
  const hash = await hashPassword(newPin);
  await query('UPDATE users SET pin_hash = $1 WHERE id = $2', [hash, userId]);
}

async function uploadAvatar(userId, file, req) {
  const storage = require('../../services/fileStorage');
  const config = require('../../config');
  const saved = await storage.save(file.buffer, {
    projectId: 'avatars',
    category: 'profile',
    originalName: file.originalname,
  });
  // Build public URL
  const proto = req.headers['x-forwarded-proto'] || req.protocol;
  const host = req.headers['x-forwarded-host'] || req.get('host');
  const publicBase = config.publicUrl
    ? `${config.publicUrl.replace(/\/+$/, '')}${config.apiPrefix}`
    : `${proto}://${host}${config.apiPrefix}`;
  // Store as a download URL using the files system (create a virtual file entry)
  const avatarUrl = `${publicBase}/auth/avatar/${userId}`;
  await query('UPDATE users SET avatar_url = $1 WHERE id = $2', [saved.storageKey, userId]);
  return { avatarUrl };
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
  updateProfile,
  changePassword,
  forgotPassword,
  resetPassword,
  pinLogin,
  changePin,
  adminSetPin,
  resetPinById,
  uploadAvatar,
};
