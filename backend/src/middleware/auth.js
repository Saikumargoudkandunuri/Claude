'use strict';

const { verifyAccessToken } = require('../utils/jwt');
const { ApiError } = require('../utils/http');
const { query } = require('../db/pool');

/**
 * Authenticate the request via Bearer access token.
 * Loads the fresh user record so status/role changes take effect immediately.
 */
async function authenticate(req, _res, next) {
  try {
    const header = req.headers.authorization || '';
    const [scheme, token] = header.split(' ');
    if (scheme !== 'Bearer' || !token) {
      throw ApiError.unauthorized('Missing bearer token');
    }

    let payload;
    try {
      payload = verifyAccessToken(token);
    } catch (_) {
      throw ApiError.unauthorized('Invalid or expired token');
    }

    const { rows } = await query(
      `SELECT id, full_name, email, phone, role, status, worker_status
         FROM users WHERE id = $1`,
      [payload.sub]
    );
    const user = rows[0];
    if (!user) throw ApiError.unauthorized('User no longer exists');
    if (user.status === 'disabled') throw ApiError.forbidden('Account disabled');
    if (user.status === 'rejected') throw ApiError.forbidden('Account rejected');

    req.user = user;
    next();
  } catch (err) {
    next(err);
  }
}

/** Allow only fully approved users with an assigned role past this point. */
function requireApproved(req, _res, next) {
  if (!req.user) return next(ApiError.unauthorized());
  if (req.user.status !== 'approved' || !req.user.role) {
    return next(ApiError.forbidden('Account pending admin approval'));
  }
  next();
}

module.exports = { authenticate, requireApproved };
