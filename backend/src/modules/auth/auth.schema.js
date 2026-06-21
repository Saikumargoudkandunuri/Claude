'use strict';

const { z } = require('zod');

const register = z.object({
  fullName: z.string().min(2).max(120),
  email: z.string().email(),
  phone: z.string().min(6).max(20),
  password: z.string().min(8).max(100),
});

const login = z.object({
  email: z.string().email(),
  password: z.string().min(1),
});

const refresh = z.object({
  refreshToken: z.string().min(10),
});

const pushToken = z.object({
  pushToken: z.string().min(10),
});

const workerStatus = z.object({
  status: z.enum(['workshop', 'at_site', 'leave', 'holiday']),
});

module.exports = { register, login, refresh, pushToken, workerStatus };
