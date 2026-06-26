import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/dio_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';

/// Reset PIN using Employee ID (provided by Admin).
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _idCtrl = TextEditingController();
  final _pinCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _busy = false;
  String? _errorMsg;

  @override
  void dispose() {
    _idCtrl.dispose();
    _pinCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _resetPin() async {
    final id = _idCtrl.text.trim();
    final pin = _pinCtrl.text.trim();
    final confirm = _confirmCtrl.text.trim();

    if (id.isEmpty) {
      setState(() => _errorMsg = 'Enter your Employee ID');
      return;
    }
    if (pin.length != 4) {
      setState(() => _errorMsg = 'PIN must be exactly 4 digits');
      return;
    }
    if (pin != confirm) {
      setState(() => _errorMsg = 'PINs do not match');
      return;
    }

    setState(() {
      _busy = true;
      _errorMsg = null;
    });
    try {
      final dio = DioClient.instance.dio;
      await dio.post('/auth/reset-pin-by-id',
          data: {'userId': id, 'newPin': pin},
          options: Options(extra: {'skipAuth': true}),);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('PIN reset successfully! You can now login.'),),);
        context.go('/login');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _errorMsg = DioClient.toApiException(e).message;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reset PIN')),
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
                  const Text('Reset your PIN',
                      textAlign: TextAlign.center,
                      style:
                          TextStyle(fontSize: 22, fontWeight: FontWeight.w800),),
                  const SizedBox(height: AppSpacing.sm),
                  const Text(
                      'Enter your Employee ID provided by your Administrator.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textSecondary),),
                  const SizedBox(height: AppSpacing.xxl),
                  TextField(
                    controller: _idCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Employee ID',
                      prefixIcon: Icon(Icons.badge_outlined),
                      hintText: 'Ask your admin for this ID',
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  TextField(
                    controller: _pinCtrl,
                    obscureText: true,
                    maxLength: 4,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      labelText: 'New 4-digit PIN',
                      prefixIcon: Icon(Icons.pin_outlined),
                      counterText: '',
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    controller: _confirmCtrl,
                    obscureText: true,
                    maxLength: 4,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      labelText: 'Confirm PIN',
                      prefixIcon: Icon(Icons.pin_outlined),
                      counterText: '',
                    ),
                  ),
                  if (_errorMsg != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Text(_errorMsg!,
                        style: const TextStyle(
                            color: AppColors.danger, fontSize: 13,),
                        textAlign: TextAlign.center,),
                  ],
                  const SizedBox(height: AppSpacing.xl),
                  SizedBox(
                    height: 50,
                    child: FilledButton(
                      onPressed: _busy ? null : _resetPin,
                      child: _busy
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white,),)
                          : const Text('Reset PIN',
                              style: TextStyle(fontSize: 16),),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
