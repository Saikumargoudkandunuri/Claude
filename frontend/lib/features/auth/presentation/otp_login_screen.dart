import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/dio_client.dart';
import '../../../core/storage/secure_store.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../application/auth_controller.dart';

/// OTP Login: Fixed +91 country code, user enters 10-digit number.
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

  String get _otpValue => _otpControllers.map((c) => c.text).join();

  Future<void> _requestOtp() async {
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
      final dio = DioClient.instance.dio;
      await dio.post(
        '/auth/otp/request',
        data: {'phone': '+91$digits'},
        options: Options(extra: {'skipAuth': true}),
      );
      setState(() => _step = 1);
      _startCountdown();
      _snack('OTP sent to +91 $digits');
    } catch (e) {
      setState(() => _errorMsg = DioClient.toApiException(e).message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _verifyOtp() async {
    final otp = _otpValue;
    if (otp.length != 6) {
      setState(() => _errorMsg = 'Enter the complete 6-digit OTP');
      return;
    }
    setState(() {
      _busy = true;
      _errorMsg = null;
    });
    try {
      final digits = _phoneCtrl.text.trim().replaceAll(RegExp(r'[^0-9]'), '');
      final dio = DioClient.instance.dio;
      final res = await dio.post(
        '/auth/otp/verify',
        data: {'phone': '+91$digits', 'otp': otp},
        options: Options(extra: {'skipAuth': true}),
      );
      final data = res.data['data'] as Map<String, dynamic>;

      // Save tokens
      await SecureStore.instance.saveTokens(
        accessToken: data['accessToken'] as String,
        refreshToken: data['refreshToken'] as String,
      );

      // Refresh auth state → router will redirect to dashboard
      await ref.read(authControllerProvider.notifier).refreshUser();
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _errorMsg = DioClient.toApiException(e).message;
        });
      }
    }
  }

  void _snack(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
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
          'We will send a 6-digit OTP to verify your identity.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.xxl),

        // Phone input with fixed +91 prefix
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
              child: const Text(
                '+91',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
            ),
            hintText: '9876543210',
            counterText: '',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),

        if (_errorMsg != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            _errorMsg!,
            style: const TextStyle(color: AppColors.danger, fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ],
        const SizedBox(height: AppSpacing.xl),

        SizedBox(
          height: 50,
          child: FilledButton(
            onPressed: _busy ? null : _requestOtp,
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
    final digits = _phoneCtrl.text.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.sms_outlined, size: 64, color: AppColors.primary),
        const SizedBox(height: AppSpacing.lg),
        const Text(
          'Verify OTP',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'OTP sent to +91 $digits',
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.xxl),

        // 6-digit OTP boxes
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
                        // Auto-verify when all 6 digits entered
                        if (_otpValue.length == 6) {
                          _verifyOtp();
                        }
                      },
                    ),
                  )),
        ),

        if (_errorMsg != null) ...[
          const SizedBox(height: AppSpacing.md),
          Text(
            _errorMsg!,
            style: const TextStyle(color: AppColors.danger, fontSize: 13),
            textAlign: TextAlign.center,
          ),
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

        // Resend
        Center(
          child: _countdown > 0
              ? Text(
                  'Resend OTP in ${_countdown}s',
                  style: const TextStyle(color: AppColors.textSecondary),
                )
              : TextButton(
                  onPressed: _busy ? null : _requestOtp,
                  child: const Text('Resend OTP'),
                ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Center(
          child: TextButton(
            onPressed: () => setState(() {
              _step = 0;
              _errorMsg = null;
              for (final c in _otpControllers) {
                c.clear();
              }
            }),
            child: const Text('Change phone number'),
          ),
        ),
      ],
    );
  }
}
