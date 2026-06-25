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

/// Mobile Number + 4-digit PIN login screen.
/// Fixed +91 country code, user enters 10-digit number and 4-digit PIN.
class PinLoginScreen extends ConsumerStatefulWidget {
  const PinLoginScreen({super.key});

  @override
  ConsumerState<PinLoginScreen> createState() => _PinLoginScreenState();
}

class _PinLoginScreenState extends ConsumerState<PinLoginScreen> {
  final _phoneCtrl = TextEditingController();
  final _pinCtrl = TextEditingController();
  final _phoneFocus = FocusNode();
  final _pinFocus = FocusNode();

  bool _busy = false;
  bool _obscurePin = true;
  String? _errorMsg;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _pinCtrl.dispose();
    _phoneFocus.dispose();
    _pinFocus.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final digits = _phoneCtrl.text.trim().replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length != 10) {
      setState(() => _errorMsg = 'Enter a valid 10-digit mobile number');
      return;
    }
    final pin = _pinCtrl.text.trim();
    if (pin.length != 4) {
      setState(() => _errorMsg = 'Enter your 4-digit PIN');
      return;
    }

    setState(() {
      _busy = true;
      _errorMsg = null;
    });

    try {
      final dio = DioClient.instance.dio;
      final res = await dio.post(
        '/auth/pin-login',
        data: {
          'phone': '+91$digits',
          'pin': pin,
        },
        options: Options(extra: {'skipAuth': true}),
      );
      final data = res.data['data'] as Map<String, dynamic>;

      // Save JWT tokens
      await SecureStore.instance.saveTokens(
        accessToken: data['accessToken'] as String,
        refreshToken: data['refreshToken'] as String,
      );

      // Refresh auth state → router redirects to dashboard
      if (mounted) {
        await ref.read(authControllerProvider.notifier).refreshUser();
      }
    } on DioException catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _errorMsg = DioClient.toApiException(e).message;
        });
      }
    } catch (e) {
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
        title: const Text('Login with PIN'),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.phone_android,
                      size: 64, color: AppColors.primary),
                  const SizedBox(height: AppSpacing.lg),
                  const Text(
                    'Enter your mobile number & PIN',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  const Text(
                    'Use the 4-digit PIN provided by your administrator.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  // Phone field
                  TextField(
                    controller: _phoneCtrl,
                    focusNode: _phoneFocus,
                    keyboardType: TextInputType.number,
                    maxLength: 10,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1),
                    decoration: InputDecoration(
                      prefixIcon: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        alignment: Alignment.center,
                        width: 70,
                        child: const Text('+91',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.w700)),
                      ),
                      hintText: '9876543210',
                      counterText: '',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    textInputAction: TextInputAction.next,
                    onSubmitted: (_) => _pinFocus.requestFocus(),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  // PIN field
                  TextField(
                    controller: _pinCtrl,
                    focusNode: _pinFocus,
                    keyboardType: TextInputType.number,
                    maxLength: 4,
                    obscureText: _obscurePin,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 8),
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      labelText: '4-digit PIN',
                      counterText: '',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                      suffixIcon: IconButton(
                        icon: Icon(_obscurePin
                            ? Icons.visibility_off
                            : Icons.visibility),
                        onPressed: () =>
                            setState(() => _obscurePin = !_obscurePin),
                      ),
                    ),
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _login(),
                  ),
                  if (_errorMsg != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Text(_errorMsg!,
                        style: const TextStyle(
                            color: AppColors.danger, fontSize: 13),
                        textAlign: TextAlign.center),
                  ],
                  const SizedBox(height: AppSpacing.xl),
                  SizedBox(
                    height: 50,
                    child: FilledButton(
                      onPressed: _busy ? null : _login,
                      child: _busy
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Text('Login', style: TextStyle(fontSize: 16)),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  const Text(
                    'Forgot PIN? Contact your Administrator.',
                    textAlign: TextAlign.center,
                    style:
                        TextStyle(color: AppColors.textSecondary, fontSize: 13),
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
