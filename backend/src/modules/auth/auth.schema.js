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

const updateProfile = z.object({
  fullName: z.string().min(2).max(120).optional(),
  phone: z.string().min(6).max(20).optional(),
});

const changePassword = z.object({
  currentPassword: z.string().min(1),
  newPassword: z.string().min(8).max(100),
});

const forgotPassword = z.object({
  email: z.string().email(),
});

const resetPassword = z.object({
  email: z.string().email(),
  otp: z.string().length(6),
  newPassword: z.string().min(8).max(100),
});

const pinLogin = z.object({
  phone: z.string().min(6).max(20),
  pin: z.string().length(4),
});

const changePin = z.object({
  currentPin: z.string().length(4),
  newPin: z.string().length(4),
});

const adminResetPin = z.object({
  pin: z.string().length(4),
});

const resetPinById = z.object({
  userId: z.string().min(1),
  newPin: z.string().length(4),
});

const setSecurityQuestion = z.object({
  question: z.string().min(5).max(200),
  answer: z.string().min(2).max(100),
});

const forgotPasswordQuestion = z.object({
  email: z.string().email(),
});

const verifySecurityAnswer = z.object({
  email: z.string().email(),
  answer: z.string().min(1).max(100),
});

const resetPasswordWithToken = z.object({
  resetToken: z.string().min(10),
  newPassword: z.string().min(8).max(100),
});

module.exports = { register, login, refresh, pushToken, workerStatus, updateProfile, changePassword, forgotPassword, resetPassword, pinLogin, changePin, adminResetPin, resetPinById, setSecurityQuestion, forgotPasswordQuestion, verifySecurityAnswer, resetPasswordWithToken };
