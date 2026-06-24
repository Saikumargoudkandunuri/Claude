import 'dart:async';

import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/dio_client.dart';
import '../../../core/storage/secure_store.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../application/auth_controller.dart';

/// Firebase Phone Auth login screen.
/// Fixed +91 country code, user enters 10-digit number.
/// After Firebase verifies OTP, backend checks if phone exists in DB.
class OtpLoginScreen extends ConsumerStatefulWidget {
  const OtpLoginScreen({super.key});

  @override
  ConsumerState<OtpLoginScreen> createState() => _OtpLoginScreenState();
}

class _OtpLoginScreenState extends ConsumerState<OtpLoginScreen> {
  final _phoneCtrl = TextEditingController();
  final _otpControllers = List.generate(6, (_) => TextEditingController());
  final _otpFocusNodes = List.generate(6, (_) => FocusNode());

  int _step = 0; // 0 = phone, 1 = otp
  bool _busy = false;
  int _countdown = 0;
  Timer? _timer;
  String? _errorMsg;
  String? _verificationId;
  int? _resendToken;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    for (final c in _otpControllers) {
      c.dispose();
    }
    for (final f in _otpFocusNodes) {
      f.dispose();
    }
    _timer?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    _countdown = 60;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_countdown <= 0) {
        t.cancel();
      } else {
        setState(() => _countdown--);
      }
    });
  }

  String get _fullPhone => '+91${_phoneCtrl.text.trim()}';
  String get _otpValue => _otpControllers.map((c) => c.text).join();

  /// Step 1: Send OTP via Firebase Phone Auth
  Future<void> _sendOtp() async {
    final digits = _phoneCtrl.text.trim().replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length != 10) {
      setState(() => _errorMsg = 'Enter a valid 10-digit mobile number');
      return;
    }
    setState(() {
      _busy = true;
      _errorMsg = null;
    });

    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: '+91$digits',
        timeout: const Duration(seconds: 60),
        forceResendingToken: _resendToken,
        verificationCompleted: (PhoneAuthCredential credential) async {
          // Auto-verification (Android auto-read SMS)
          await _signInWithCredential(credential);
        },
        verificationFailed: (FirebaseAuthException e) {
          if (mounted) {
            setState(() {
              _busy = false;
              _errorMsg = e.message ?? 'Verification failed. Try again.';
            });
          }
        },
        codeSent: (String verificationId, int? resendToken) {
          if (mounted) {
            setState(() {
              _verificationId = verificationId;
              _resendToken = resendToken;
              _step = 1;
              _busy = false;
            });
            _startCountdown();
          }
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          _verificationId = verificationId;
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _errorMsg = 'Failed to send OTP. Check your internet connection.';
        });
      }
    }
  }

  /// Step 2: Verify OTP manually
  Future<void> _verifyOtp() async {
    final otp = _otpValue;
    if (otp.length != 6) {
      setState(() => _errorMsg = 'Enter the complete 6-digit OTP');
      return;
    }
    if (_verificationId == null) {
      setState(() => _errorMsg = 'Session expired. Please resend OTP.');
      return;
    }
    setState(() {
      _busy = true;
      _errorMsg = null;
    });

    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: otp,
      );
      await _signInWithCredential(credential);
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          if (e.code == 'invalid-verification-code') {
            _errorMsg = 'Invalid OTP. Please check and try again.';
          } else if (e.code == 'session-expired') {
            _errorMsg = 'OTP expired. Please resend.';
          } else {
            _errorMsg = e.message ?? 'Verification failed.';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _errorMsg = 'Verification failed. Try again.';
        });
      }
    }
  }

  /// After Firebase verifies the phone, check with our backend
  Future<void> _signInWithCredential(PhoneAuthCredential credential) async {
    try {
      final userCredential =
          await FirebaseAuth.instance.signInWithCredential(credential);
      final firebaseUser = userCredential.user;
      if (firebaseUser == null) {
        setState(() {
          _busy = false;
          _errorMsg = 'Authentication failed.';
        });
        return;
      }

      // Now call our backend to get JWT tokens
      final phone = firebaseUser.phoneNumber ?? _fullPhone;
      final dio = DioClient.instance.dio;
      final res = await dio.post(
        '/auth/firebase-phone-login',
        data: {
          'phone': phone,
          'firebaseUid': firebaseUser.uid,
        },
        options: Options(extra: {'skipAuth': true}),
      );
      final data = res.data['data'] as Map<String, dynamic>;

      // Save JWT tokens
      await SecureStore.instance.saveTokens(
        accessToken: data['accessToken'] as String,
        refreshToken: data['refreshToken'] as String,
      );

      // Sign out from Firebase (we use our own JWT)
      await FirebaseAuth.instance.signOut();

      // Refresh auth state → router redirects to dashboard
      if (mounted) {
        await ref.read(authControllerProvider.notifier).refreshUser();
      }
    } on DioException catch (e) {
      // Backend rejected: phone not registered
      await FirebaseAuth.instance.signOut();
      if (mounted) {
        setState(() {
          _busy = false;
          _errorMsg = DioClient.toApiException(e).message;
        });
      }
    } catch (e) {
      await FirebaseAuth.instance.signOut();
      if (mounted) {
        setState(() {
          _busy = false;
          _errorMsg = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/login'),
        ),
        title: const Text('Login with OTP'),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: _step == 0 ? _phoneStep() : _otpStep(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _phoneStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.phone_android, size: 64, color: AppColors.primary),
        const SizedBox(height: AppSpacing.lg),
        const Text(
          'Enter your mobile number',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: AppSpacing.sm),
        const Text(
          'We will send a verification code via SMS.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.xxl),
        TextField(
          controller: _phoneCtrl,
          keyboardType: TextInputType.number,
          maxLength: 10,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: const TextStyle(
              fontSize: 18, fontWeight: FontWeight.w600, letterSpacing: 1),
          decoration: InputDecoration(
            prefixIcon: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              alignment: Alignment.center,
              width: 70,
              child: const Text('+91',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            ),
            hintText: '9876543210',
            counterText: '',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        if (_errorMsg != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(_errorMsg!,
              style: const TextStyle(color: AppColors.danger, fontSize: 13),
              textAlign: TextAlign.center),
        ],
        const SizedBox(height: AppSpacing.xl),
        SizedBox(
          height: 50,
          child: FilledButton(
            onPressed: _busy ? null : _sendOtp,
            child: _busy
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Text('Send OTP', style: TextStyle(fontSize: 16)),
          ),
        ),
      ],
    );
  }

  Widget _otpStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.sms_outlined, size: 64, color: AppColors.primary),
        const SizedBox(height: AppSpacing.lg),
        const Text('Verify OTP',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
        const SizedBox(height: AppSpacing.sm),
        Text('Code sent to ${_fullPhone}',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textSecondary)),
        const SizedBox(height: AppSpacing.xxl),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(
              6,
              (i) => SizedBox(
                    width: 46,
                    child: TextField(
                      controller: _otpControllers[i],
                      focusNode: _otpFocusNodes[i],
                      textAlign: TextAlign.center,
                      keyboardType: TextInputType.number,
                      maxLength: 1,
                      style: const TextStyle(
                          fontSize: 22, fontWeight: FontWeight.w800),
                      decoration: InputDecoration(
                        counterText: '',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10)),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                              color: AppColors.primary, width: 2),
                        ),
                      ),
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      onChanged: (value) {
                        if (value.isNotEmpty && i < 5) {
                          _otpFocusNodes[i + 1].requestFocus();
                        }
                        if (value.isEmpty && i > 0) {
                          _otpFocusNodes[i - 1].requestFocus();
                        }
                        if (_otpValue.length == 6) _verifyOtp();
                      },
                    ),
                  )),
        ),
        if (_errorMsg != null) ...[
          const SizedBox(height: AppSpacing.md),
          Text(_errorMsg!,
              style: const TextStyle(color: AppColors.danger, fontSize: 13),
              textAlign: TextAlign.center),
        ],
        const SizedBox(height: AppSpacing.xl),
        SizedBox(
          height: 50,
          child: FilledButton(
            onPressed: _busy ? null : _verifyOtp,
            child: _busy
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Text('Verify & Login', style: TextStyle(fontSize: 16)),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Center(
          child: _countdown > 0
              ? Text('Resend in ${_countdown}s',
                  style: const TextStyle(color: AppColors.textSecondary))
              : TextButton(
                  onPressed: _busy ? null : _sendOtp,
                  child: const Text('Resend OTP')),
        ),
        Center(
          child: TextButton(
            onPressed: () => setState(() {
              _step = 0;
              _errorMsg = null;
              for (final c in _otpControllers) {
                c.clear();
              }
            }),
            child: const Text('Change number'),
          ),
        ),
      ],
    );
  }
}
