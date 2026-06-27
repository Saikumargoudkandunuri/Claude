'use strict';

const jwt = require('jsonwebtoken');
const config = require('../config');
const { ApiError } = require('../utils/http');

/**
 * Authenticate a customer request via Bearer token signed with CUSTOMER_JWT_SECRET.
 * Attaches req.customer = { projectId, customerName, mobile } on success.
 * This is completely separate from staff auth (auth.js) — different secret, different payload.
 */
function authenticateCustomer(req, _res, next) {
  try {
    const header = req.headers.authorization || '';
    const [scheme, token] = header.split(' ');
    if (scheme !== 'Bearer' || !token) {
      throw ApiError.unauthorized('Missing bearer token');
    }

    const secret = config.customerJwt.secret;
    if (!secret) {
      throw ApiError.unauthorized('Customer auth not configured');
    }

    let payload;
    try {
      payload = jwt.verify(token, secret);
    } catch (_) {
      throw ApiError.unauthorized('Invalid or expired token');
    }

    // Validate payload structure — must be a customer token
    if (payload.role !== 'customer' || !payload.customerId) {
      throw ApiError.unauthorized('Invalid or expired token');
    }

    req.customer = {
      customerId: payload.customerId,
      projectId: payload.projectId,
      customerName: payload.customerName,
      mobile: payload.mobile,
    };

    next();
  } catch (err) {
    next(err);
  }
}

module.exports = { authenticateCustomer };
