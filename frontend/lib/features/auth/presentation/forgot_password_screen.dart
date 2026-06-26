import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/dio_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../application/auth_controller.dart';

/// Reset your password without OTP or email — answer the security question
/// you set on your profile.
///
/// Step 0: enter email   -> server returns your security question
/// Step 1: answer it      -> server returns a one-time reset token
/// Step 2: set a new password -> done, go back to login
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  int _step = 0;
  bool _busy = false;
  String? _errorMsg;

  final _emailCtrl = TextEditingController();
  final _answerCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  String? _question;
  String? _resetToken;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _answerCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _step0() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _errorMsg = 'Enter a valid email');
      return;
    }
    setState(() {
      _busy = true;
      _errorMsg = null;
    });
    try {
      final res = await ref.read(authApiProvider).forgotPasswordQuestion(email);
      if (res['hasQuestion'] != true) {
        setState(() {
          _busy = false;
          _errorMsg = (res['message'] as String?) ??
              'No security question is set for this account. '
                  'Contact your administrator to reset your password.';
        });
        return;
      }
      setState(() {
        _busy = false;
        _question = res['question'] as String?;
        _step = 1;
      });
    } catch (e) {
      setState(() {
        _busy = false;
        _errorMsg = DioClient.toApiException(e).message;
      });
    }
  }

  Future<void> _step1() async {
    final answer = _answerCtrl.text.trim();
    if (answer.isEmpty) {
      setState(() => _errorMsg = 'Enter your answer');
      return;
    }
    setState(() {
      _busy = true;
      _errorMsg = null;
    });
    try {
      final token = await ref
          .read(authApiProvider)
          .verifySecurityAnswer(_emailCtrl.text.trim(), answer);
      setState(() {
        _busy = false;
        _resetToken = token;
        _step = 2;
      });
    } catch (e) {
      setState(() {
        _busy = false;
        _errorMsg = DioClient.toApiException(e).message;
      });
    }
  }

  Future<void> _step2() async {
    final pass = _passCtrl.text;
    if (pass.length < 8) {
      setState(() => _errorMsg = 'Password must be at least 8 characters');
      return;
    }
    if (pass != _confirmCtrl.text) {
      setState(() => _errorMsg = 'Passwords do not match');
      return;
    }
    setState(() {
      _busy = true;
      _errorMsg = null;
    });
    try {
      await ref
          .read(authApiProvider)
          .resetPasswordWithToken(_resetToken!, pass);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password reset! Please log in.')),
      );
      context.go('/login');
    } catch (e) {
      setState(() {
        _busy = false;
        _errorMsg = DioClient.toApiException(e).message;
      });
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.lock_reset,
                      size: 64, color: AppColors.primary,),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    _titleForStep(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.w800,),
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  if (_step == 0) ..._step0Fields(),
                  if (_step == 1) ..._step1Fields(),
                  if (_step == 2) ..._step2Fields(),
                  if (_errorMsg != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      _errorMsg!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: AppColors.danger, fontSize: 13,),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.xl),
                  SizedBox(
                    height: 50,
                    child: FilledButton(
                      onPressed: _busy ? null : _onPrimary,
                      child: _busy
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white,),
                            )
                          : Text(_buttonForStep(),
                              style: const TextStyle(fontSize: 16),),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  TextButton(
                    onPressed: () => context.go('/login'),
                    child: const Text('Back to login'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _titleForStep() {
    switch (_step) {
      case 1:
        return 'Security Question';
      case 2:
        return 'Set a New Password';
      default:
        return 'Reset your password';
    }
  }

  String _buttonForStep() {
    switch (_step) {
      case 1:
        return 'Verify Answer';
      case 2:
        return 'Reset Password';
      default:
        return 'Continue';
    }
  }

  void _onPrimary() {
    switch (_step) {
      case 1:
        _step1();
        break;
      case 2:
        _step2();
        break;
      default:
        _step0();
    }
  }

  List<Widget> _step0Fields() => [
        const Text(
          'Enter your account email. We will ask the security question you set.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.lg),
        TextField(
          controller: _emailCtrl,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
            labelText: 'Email',
            prefixIcon: Icon(Icons.mail_outline),
          ),
        ),
      ];

  List<Widget> _step1Fields() => [
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            _question ?? '',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        TextField(
          controller: _answerCtrl,
          decoration: const InputDecoration(
            labelText: 'Your answer',
            prefixIcon: Icon(Icons.help_outline),
          ),
        ),
      ];

  List<Widget> _step2Fields() => [
        const Text(
          'Choose a new password (min 8 characters).',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.lg),
        TextField(
          controller: _passCtrl,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: 'New password',
            prefixIcon: Icon(Icons.lock_outline),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: _confirmCtrl,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: 'Confirm new password',
            prefixIcon: Icon(Icons.lock_outline),
          ),
        ),
      ];
}
