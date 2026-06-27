'use strict';

const rateLimit = require('express-rate-limit');

// Tighter limit for auth endpoints to slow brute-force attempts.
const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 30,
  standardHeaders: true,
  legacyHeaders: false,
  message: { error: { code: 'RATE_LIMITED', message: 'Too many attempts, try later' } },
});

// General API limiter.
const apiLimiter = rateLimit({
  windowMs: 60 * 1000, // 1 minute
  max: 300,
  standardHeaders: true,
  legacyHeaders: false,
  message: { error: { code: 'RATE_LIMITED', message: 'Too many requests' } },
});

// Customer login limiter — 5 attempts per mobile per 15-minute window.
const customerLoginLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 5,
  keyGenerator: (req) => req.body.mobile || req.ip,
  standardHeaders: true,
  legacyHeaders: false,
  message: { error: { code: 'RATE_LIMITED', message: 'Too many attempts, try later' } },
});

// Customer check-mobile limiter — 10 attempts per IP per 15-minute window.
const customerCheckMobileLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 10,
  standardHeaders: true,
  legacyHeaders: false,
  message: { error: { code: 'RATE_LIMITED', message: 'Too many attempts, try later' } },
});

module.exports = { authLimiter, apiLimiter, customerLoginLimiter, customerCheckMobileLimiter };
