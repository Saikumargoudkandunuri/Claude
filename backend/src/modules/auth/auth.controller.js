'use strict';

const { asyncHandler, ok } = require('../../utils/http');
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

const requestOtp = asyncHandler(async (req, res) => {
  const result = await service.requestLoginOtp(req.body.phone);
  ok(res, result);
});

const verifyOtp = asyncHandler(async (req, res) => {
  const result = await service.verifyLoginOtp(req.body.phone, req.body.otp);
  ok(res, result);
});

const firebasePhoneLogin = asyncHandler(async (req, res) => {
  const result = await service.firebasePhoneLogin(req.body.phone, req.body.firebaseUid);
  ok(res, result);
});

module.exports = { register, login, refresh, logout, me, updatePushToken, updateWorkerStatus, updateProfile, changePassword, forgotPassword, resetPassword, requestOtp, verifyOtp, firebasePhoneLogin };
