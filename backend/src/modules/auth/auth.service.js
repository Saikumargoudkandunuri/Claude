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

const MAX_LOGIN_ATTEMPTS = 5;
const LOCK_MINUTES = 30;

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

const MAX_LOGIN_ATTEMPTS = 5;
const LOCK_MINUTES = 30;

async function login({ email, password }) {
  const { rows } = await query('SELECT * FROM users WHERE email = $1', [email]);
  const user = rows[0];
  if (!user) throw ApiError.unauthorized('Invalid email or password');

  // Account lockout: block while the lock window is active.
  if (user.locked_until && new Date(user.locked_until) > new Date()) {
    const minutesLeft = Math.ceil((new Date(user.locked_until).getTime() - Date.now()) / 60000);
    throw ApiError.tooManyRequests(
      `Too many failed attempts. Try again in ${minutesLeft} minute(s).`
    );
  }

  const valid = await comparePassword(password, user.password_hash);
  if (!valid) {
    // Increment failed attempts; lock after the threshold.
    const attempts = (user.login_attempts || 0) + 1;
    const shouldLock = attempts >= MAX_LOGIN_ATTEMPTS;
    await query(
      'UPDATE users SET login_attempts = $1, locked_until = $2 WHERE id = $3',
      [
        shouldLock ? 0 : attempts,
        shouldLock ? new Date(Date.now() + LOCK_MINUTES * 60000) : null,
        user.id,
      ]
    );
    if (shouldLock) {
      throw ApiError.tooManyRequests(
        `Too many failed attempts. Account locked for ${LOCK_MINUTES} minutes.`
      );
    }
    throw ApiError.unauthorized('Invalid email or password');
  }

  if (user.status === 'rejected') throw ApiError.forbidden('Your registration was rejected');
  if (user.status === 'disabled') throw ApiError.forbidden('Your account is disabled');

  // Successful login: clear lockout counters and record the timestamp.
  await query(
    'UPDATE users SET login_attempts = 0, locked_until = NULL, last_login_at = now() WHERE id = $1',
    [user.id]
  );

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
  await query(
    'UPDATE users SET password_hash = $1, password_changed_at = now() WHERE id = $2',
    [hash, userId]
  );
  // Invalidate all existing sessions after a password change.
  await query('UPDATE refresh_tokens SET revoked = true WHERE user_id = $1', [userId]);
}

// ─── Security questions + password reset (no OTP, no email) ──────────────────

const SECURITY_QUESTIONS = [
  'What was the name of your first school?',
  "What is your mother's maiden name?",
  'What was the name of your first pet?',
  'What city were you born in?',
  "What is your oldest sibling's middle name?",
];

/** Set or replace the current user's security question + answer. */
async function setSecurityQuestion(userId, { question, answer }) {
  const answerHash = await hashPassword(answer.trim().toLowerCase());
  await query(
    `INSERT INTO user_security_questions (user_id, question, answer_hash)
     VALUES ($1, $2, $3)
     ON CONFLICT (user_id) DO UPDATE
       SET question = EXCLUDED.question,
           answer_hash = EXCLUDED.answer_hash,
           set_at = now()`,
    [userId, question.trim(), answerHash]
  );
}

/** Whether the current user has a security question configured. */
async function getSecurityQuestionStatus(userId) {
  const { rows } = await query(
    'SELECT question FROM user_security_questions WHERE user_id = $1',
    [userId]
  );
  return { hasQuestion: !!rows[0], question: rows[0]?.question || null };
}

/**
 * Forgot-password step 1: look up by email and return the security question.
 * Returns a generic shape when the account/question is missing so we never
 * reveal which emails exist.
 */
async function forgotPasswordQuestion(email) {
  const { rows } = await query(
    `SELECT u.id, sq.question
       FROM users u
       LEFT JOIN user_security_questions sq ON sq.user_id = u.id
      WHERE u.email = $1 AND u.status NOT IN ('disabled', 'rejected')`,
    [email]
  );
  const row = rows[0];
  if (!row || !row.question) {
    return {
      hasQuestion: false,
      question: null,
      message:
        'If that account exists and has a security question, you will be asked it. Otherwise contact your administrator.',
    };
  }
  return { hasQuestion: true, question: row.question };
}

/** Forgot-password step 2: verify the answer and issue a one-time reset token. */
async function verifySecurityAnswer({ email, answer }) {
  const { rows } = await query(
    `SELECT u.id, sq.answer_hash
       FROM users u
       JOIN user_security_questions sq ON sq.user_id = u.id
      WHERE u.email = $1`,
    [email]
  );
  const row = rows[0];
  if (!row) throw ApiError.unauthorized('Incorrect answer');
  const matches = await comparePassword(answer.trim().toLowerCase(), row.answer_hash);
  if (!matches) throw ApiError.unauthorized('Incorrect answer');

  const rawToken = generateRefreshToken();
  await query(
    'INSERT INTO password_reset_tokens (user_id, token_hash) VALUES ($1, $2)',
    [row.id, hashToken(rawToken)]
  );
  return { resetToken: rawToken };
}

/** Forgot-password step 3: consume the token, set the new password, drop sessions. */
async function resetPasswordWithToken({ resetToken, newPassword }) {
  const tokenHash = hashToken(resetToken);
  return withTransaction(async (client) => {
    const { rows } = await client.query(
      `SELECT * FROM password_reset_tokens
        WHERE token_hash = $1 AND used = false AND expires_at > now()
        FOR UPDATE`,
      [tokenHash]
    );
    const token = rows[0];
    if (!token) throw ApiError.forbidden('Reset link is invalid or has expired');

    const hash = await hashPassword(newPassword);
    await client.query(
      `UPDATE users
          SET password_hash = $1, password_changed_at = now(),
              login_attempts = 0, locked_until = NULL
        WHERE id = $2`,
      [hash, token.user_id]
    );
    await client.query('UPDATE password_reset_tokens SET used = true WHERE id = $1', [token.id]);
    await client.query('UPDATE refresh_tokens SET revoked = true WHERE user_id = $1', [
      token.user_id,
    ]);
  });
}

/** Admin issues a reset token for any user (handed over in person). */
async function adminIssueReset(adminId, targetUserId) {
  const { rows } = await query('SELECT id FROM users WHERE id = $1', [targetUserId]);
  if (!rows[0]) throw ApiError.notFound('User not found');
  const rawToken = generateRefreshToken();
  await query(
    'INSERT INTO password_reset_tokens (user_id, token_hash, created_by) VALUES ($1, $2, $3)',
    [targetUserId, hashToken(rawToken), adminId]
  );
  await logActivity({
    userId: adminId,
    action: 'user.password_reset_issued',
    entityType: 'user',
    entityId: targetUserId,
    description: 'Admin issued a password reset token',
  });
  return { resetToken: rawToken, expiresInMinutes: 60 };
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
  SECURITY_QUESTIONS,
  setSecurityQuestion,
  getSecurityQuestionStatus,
  forgotPasswordQuestion,
  verifySecurityAnswer,
  resetPasswordWithToken,
  adminIssueReset,
};
