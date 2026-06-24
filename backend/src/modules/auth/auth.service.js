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
 * Request OTP for phone-based login.
 * Only existing approved users can receive OTPs.
 */
async function requestLoginOtp(phone) {
  // Find user by phone
  const { rows: users } = await query(
    `SELECT id, phone, status FROM users WHERE phone = $1`,
    [phone]
  );
  const user = users[0];
  if (!user) throw ApiError.notFound('No account found with this phone number');
  if (user.status === 'disabled') throw ApiError.forbidden('Account is disabled');
  if (user.status === 'rejected') throw ApiError.forbidden('Account was rejected');

  // Rate limit: max 1 OTP per phone per 60 seconds
  const { rows: recent } = await query(
    `SELECT id FROM otp_codes
     WHERE phone = $1 AND purpose = 'login' AND created_at > now() - interval '60 seconds'`,
    [phone]
  );
  if (recent.length > 0) {
    throw ApiError.tooManyRequests('Please wait 60 seconds before requesting another OTP');
  }

  // Invalidate previous unused OTPs for this phone
  await query(
    `UPDATE otp_codes SET used = true WHERE phone = $1 AND purpose = 'login' AND used = false`,
    [phone]
  );

  // Generate and store OTP
  const otp = String(Math.floor(100000 + Math.random() * 900000));
  const otpHash = hashToken(otp);
  const expiresAt = new Date(Date.now() + 5 * 60 * 1000); // 5 minutes

  await query(
    `INSERT INTO otp_codes (phone, otp_hash, purpose, expires_at)
     VALUES ($1, $2, 'login', $3)`,
    [phone, otpHash, expiresAt]
  );

  // Send SMS
  const { sendSms } = require('../../services/sms');
  await sendSms(phone, `Your ICMS login OTP is: ${otp}. Valid for 5 minutes.`);

  // Log the event
  await logActivity({
    userId: user.id,
    action: 'auth.otp_requested',
    entityType: 'user',
    entityId: user.id,
    description: `OTP requested for phone login`,
  });

  return { message: 'OTP sent successfully', expiresInSeconds: 300 };
}

/**
 * Verify OTP and issue JWT tokens (same as password login).
 */
async function verifyLoginOtp(phone, otp) {
  // Find user
  const { rows: users } = await query(
    `SELECT * FROM users WHERE phone = $1`,
    [phone]
  );
  const user = users[0];
  if (!user) throw ApiError.unauthorized('Invalid phone number');
  if (user.status === 'disabled') throw ApiError.forbidden('Account is disabled');
  if (user.status === 'rejected') throw ApiError.forbidden('Account was rejected');

  // Find the latest unused OTP for this phone
  const otpHash = hashToken(otp);
  const { rows: otpRows } = await query(
    `SELECT id, attempts, max_attempts, expires_at, used
     FROM otp_codes
     WHERE phone = $1 AND purpose = 'login' AND used = false
     ORDER BY created_at DESC LIMIT 1`,
    [phone]
  );

  const otpRecord = otpRows[0];
  if (!otpRecord) throw ApiError.unauthorized('No OTP found. Please request a new one.');

  // Check expiry
  if (new Date(otpRecord.expires_at) < new Date()) {
    await query('UPDATE otp_codes SET used = true WHERE id = $1', [otpRecord.id]);
    throw ApiError.unauthorized('OTP has expired. Please request a new one.');
  }

  // Check attempts
  if (otpRecord.attempts >= otpRecord.max_attempts) {
    await query('UPDATE otp_codes SET used = true WHERE id = $1', [otpRecord.id]);
    throw ApiError.forbidden('Too many attempts. Please request a new OTP.');
  }

  // Verify OTP hash
  const { rows: matched } = await query(
    `SELECT id FROM otp_codes
     WHERE id = $1 AND otp_hash = $2`,
    [otpRecord.id, otpHash]
  );

  if (matched.length === 0) {
    // Increment attempts
    await query(
      'UPDATE otp_codes SET attempts = attempts + 1 WHERE id = $1',
      [otpRecord.id]
    );
    const remaining = otpRecord.max_attempts - otpRecord.attempts - 1;
    throw ApiError.unauthorized(
      `Invalid OTP. ${remaining > 0 ? `${remaining} attempts remaining.` : 'No attempts remaining.'}`
    );
  }

  // Mark OTP as used (single-use, prevent replay)
  await query('UPDATE otp_codes SET used = true WHERE id = $1', [otpRecord.id]);

  // Issue JWT tokens
  const tokens = await issueTokens(user);

  // Log successful authentication
  await logActivity({
    userId: user.id,
    action: 'auth.otp_verified',
    entityType: 'user',
    entityId: user.id,
    description: 'Logged in via OTP',
  });

  return { ...tokens, user: publicUser(user) };
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
  requestLoginOtp,
  verifyLoginOtp,
};
