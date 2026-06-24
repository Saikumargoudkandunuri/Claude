import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/dio_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_text_field.dart';
import '../application/auth_controller.dart';

/// Forgot password flow: email → OTP → new password.
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _emailCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  int _step = 0; // 0 = email, 1 = otp+password
  bool _busy = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _otpCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    if (_emailCtrl.text.trim().isEmpty) return;
    setState(() => _busy = true);
    try {
      final api = ref.read(authApiProvider);
      await api.forgotPassword(_emailCtrl.text.trim());
      setState(() => _step = 1);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('OTP sent to your email/phone')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(DioClient.toApiException(e).message)),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resetPassword() async {
    if (_otpCtrl.text.trim().length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter the 6-digit OTP')),
      );
      return;
    }
    if (_passwordCtrl.text.length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password must be at least 8 characters')),
      );
      return;
    }
    if (_passwordCtrl.text != _confirmCtrl.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Passwords do not match')),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      final api = ref.read(authApiProvider);
      await api.resetPassword(
        _emailCtrl.text.trim(),
        _otpCtrl.text.trim(),
        _passwordCtrl.text,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password reset! You can now login.')),
        );
        context.go('/login');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(DioClient.toApiException(e).message)),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reset Password')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: _step == 0 ? _emailStep() : _otpStep(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _emailStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.lock_reset, size: 64, color: AppColors.primary),
        const SizedBox(height: AppSpacing.lg),
        const Text(
          'Forgot Password?',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: AppSpacing.sm),
        const Text(
          'Enter your email and we will send you a reset OTP.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.xl),
        AppTextField(
          label: 'Email',
          controller: _emailCtrl,
          keyboardType: TextInputType.emailAddress,
          validator: Validators.email,
          prefixIcon: Icons.mail_outline,
        ),
        const SizedBox(height: AppSpacing.xl),
        FilledButton(
          onPressed: _busy ? null : _sendOtp,
          child: _busy
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : const Text('Send OTP'),
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
        const Text(
          'Enter OTP',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'OTP sent to ${_emailCtrl.text.trim()}',
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.xl),
        AppTextField(
          label: 'OTP (6 digits)',
          controller: _otpCtrl,
          keyboardType: TextInputType.number,
          prefixIcon: Icons.pin,
        ),
        const SizedBox(height: AppSpacing.md),
        AppTextField(
          label: 'New Password',
          controller: _passwordCtrl,
          obscureText: true,
          prefixIcon: Icons.lock_outline,
        ),
        const SizedBox(height: AppSpacing.md),
        AppTextField(
          label: 'Confirm Password',
          controller: _confirmCtrl,
          obscureText: true,
          prefixIcon: Icons.lock_outline,
        ),
        const SizedBox(height: AppSpacing.xl),
        FilledButton(
          onPressed: _busy ? null : _resetPassword,
          child: _busy
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : const Text('Reset Password'),
        ),
        const SizedBox(height: AppSpacing.md),
        TextButton(
          onPressed: () => setState(() => _step = 0),
          child: const Text('Back'),
        ),
      ],
    );
  }
}
