import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/dio_client.dart';
import '../../../core/storage/secure_store.dart';
import '../../../core/theme/app_spacing.dart';
import '../application/auth_controller.dart';

const _navy = Color(0xFF1A237E);
const _blue = Color(0xFF1565C0);

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
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
        data: {'phone': '+91$digits', 'pin': pin},
        options: Options(extra: {'skipAuth': true}),
      );
      final data = res.data['data'] as Map<String, dynamic>;

      await SecureStore.instance.saveTokens(
        accessToken: data['accessToken'] as String,
        refreshToken: data['refreshToken'] as String,
      );

      if (mounted) {
        await ref.read(authControllerProvider.notifier).refreshUser();
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
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Brand
                  Center(
                    child: Column(
                      children: [
                        Image.asset('assets/icon/app_icon.png', height: 80),
                        const SizedBox(height: AppSpacing.md),
                        const Text(
                          'Metal & More Interiors',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: _navy,
                          ),
                        ),
                      ],
                    ),
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
                      letterSpacing: 1,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Mobile Number',
                      prefixIcon: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        alignment: Alignment.center,
                        width: 70,
                        child: const Text(
                          '+91',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      hintText: '9876543210',
                      counterText: '',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
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
                      letterSpacing: 8,
                    ),
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      labelText: '4-digit PIN',
                      counterText: '',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePin ? Icons.visibility_off : Icons.visibility,
                        ),
                        onPressed: () =>
                            setState(() => _obscurePin = !_obscurePin),
                      ),
                    ),
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _login(),
                  ),

                  if (_errorMsg != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      _errorMsg!,
                      style: const TextStyle(
                        color: Color(0xFFD32F2F),
                        fontSize: 13,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  const SizedBox(height: AppSpacing.xl),

                  // Login button
                  SizedBox(
                    height: 50,
                    child: FilledButton(
                      onPressed: _busy ? null : _login,
                      style: FilledButton.styleFrom(
                        backgroundColor: _blue,
                        minimumSize: const Size.fromHeight(50),
                      ),
                      child: _busy
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Login',
                              style: TextStyle(fontSize: 16),
                            ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // Forgot PIN
                  TextButton(
                    onPressed: () => context.go('/forgot-password'),
                    child: const Text('Forgot PIN?'),
                  ),

                  // Register
                  TextButton(
                    onPressed: () => context.go('/register'),
                    child: const Text('New employee? Register'),
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
