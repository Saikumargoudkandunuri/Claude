'use strict';

const { asyncHandler, ok, ApiError } = require('../../utils/http');
const service = require('./auth.service');

const register = asyncHandler(async (req, res) => {
  const user = await service.register(req.body);
  ok(res, { user, message: 'Registration received. Awaiting admin approval.' }, 201);
});

const login = asyncHandler(async (req, res) => {
  const result = await service.login(req.body);
  ok(res, result);
});

const refresh = asyncHandler(async (req, res) => {
  const tokens = await service.refresh(req.body);
  ok(res, tokens);
});

const logout = asyncHandler(async (req, res) => {
  await service.logout(req.body);
  res.status(204).send();
});

const me = asyncHandler(async (req, res) => {
  const user = await service.me(req.user.id);
  ok(res, user);
});

const updatePushToken = asyncHandler(async (req, res) => {
  await service.updatePushToken(req.user.id, req.body.pushToken);
  res.status(204).send();
});

const updateWorkerStatus = asyncHandler(async (req, res) => {
  const user = await service.updateWorkerStatus(req.user.id, req.body.status);
  ok(res, user);
});

const updateProfile = asyncHandler(async (req, res) => {
  const user = await service.updateProfile(req.user.id, req.body);
  ok(res, user);
});

const changePassword = asyncHandler(async (req, res) => {
  await service.changePassword(req.user.id, req.body);
  res.status(204).send();
});

const forgotPassword = asyncHandler(async (req, res) => {
  const result = await service.forgotPassword(req.body.email);
  ok(res, result || { message: 'If this email exists, a reset OTP has been sent.' });
});

const resetPassword = asyncHandler(async (req, res) => {
  await service.resetPassword(req.body);
  ok(res, { message: 'Password reset successfully. You can now login.' });
});

const pinLoginCtrl = asyncHandler(async (req, res) => {
  const result = await service.pinLogin(req.body.phone, req.body.pin);
  ok(res, result);
});

const changePinCtrl = asyncHandler(async (req, res) => {
  await service.changePin(req.user.id, req.body.currentPin, req.body.newPin);
  res.status(204).send();
});

const resetPinByIdCtrl = asyncHandler(async (req, res) => {
  await service.resetPinById(req.body.userId, req.body.newPin);
  ok(res, { message: 'PIN reset successfully' });
});

const uploadAvatar = asyncHandler(async (req, res) => {
  if (!req.file) return res.status(400).json({ error: { message: 'No file provided' } });
  const result = await service.uploadAvatar(req.user.id, req.file, req);
  ok(res, result);
});

const getAvatar = asyncHandler(async (req, res) => {
  const { query: dbQuery } = require('../../db/pool');
  const storage = require('../../services/fileStorage');
  const { rows } = await dbQuery('SELECT avatar_url FROM users WHERE id = $1', [req.params.userId]);
  const storageKey = rows[0]?.avatar_url;
  if (!storageKey || !storage.exists(storageKey)) {
    return res.status(404).json({ error: { message: 'No avatar' } });
  }
  const stat = await storage.stat(storageKey);
  res.setHeader('Content-Type', 'image/jpeg');
  res.setHeader('Content-Length', stat.size);
  res.setHeader('Cache-Control', 'public, max-age=3600');
  storage.createReadStream(storageKey).pipe(res);
});

// ─── Security question / password reset (no OTP, no email) ───────────────────

const forgotPasswordQuestionCtrl = asyncHandler(async (req, res) => {
  const result = await service.forgotPasswordQuestion(req.body.email);
  ok(res, result);
});

const verifySecurityAnswerCtrl = asyncHandler(async (req, res) => {
  const result = await service.verifySecurityAnswer(req.body);
  ok(res, result);
});

const resetPasswordWithTokenCtrl = asyncHandler(async (req, res) => {
  await service.resetPasswordWithToken(req.body);
  ok(res, { message: 'Password reset successfully. Please log in.' });
});

const getSecurityQuestionCtrl = asyncHandler(async (req, res) => {
  const result = await service.getSecurityQuestionStatus(req.user.id);
  ok(res, { ...result, options: service.SECURITY_QUESTIONS });
});

const setSecurityQuestionCtrl = asyncHandler(async (req, res) => {
  await service.setSecurityQuestion(req.user.id, req.body);
  res.status(204).send();
});

const adminIssueResetCtrl = asyncHandler(async (req, res) => {
  if (req.user.role !== 'admin') throw ApiError.forbidden('Admins only');
  const result = await service.adminIssueReset(req.user.id, req.params.userId);
  ok(res, result);
});

module.exports = { register, login, refresh, logout, me, updatePushToken, updateWorkerStatus, updateProfile, changePassword, forgotPassword, resetPassword, pinLoginCtrl, changePinCtrl, resetPinByIdCtrl, uploadAvatar, getAvatar, forgotPasswordQuestionCtrl, verifySecurityAnswerCtrl, resetPasswordWithTokenCtrl, getSecurityQuestionCtrl, setSecurityQuestionCtrl, adminIssueResetCtrl };
