'use strict';

const { z } = require('zod');

const checkMobile = z.object({
  mobile: z.string(),
});

const setPin = z.object({
  mobile: z.string(),
  pin: z.string().regex(/^\d{4}$/),
});

const login = z.object({
  mobile: z.string(),
  pin: z.string(),
});

const announce = z.object({
  projectId: z.string().uuid(),
  title: z.string().min(1),
  body: z.string().min(1),
});

const resetPin = z.object({
  customerId: z.string().uuid(),
});

module.exports = { checkMobile, setPin, login, announce, resetPin };
