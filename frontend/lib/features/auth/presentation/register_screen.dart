import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/dio_client.dart';
import '../../../core/theme/app_spacing.dart';

const _navy = Color(0xFF1A237E);
const _blue = Color(0xFF1565C0);

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _pinCtrl = TextEditingController();
  final _confirmPinCtrl = TextEditingController();

  String _selectedRole = 'worker';
  bool _busy = false;
  bool _obscurePin = true;
  bool _obscureConfirm = true;

  static const _roles = ['supervisor', 'designer', 'worker'];

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _pinCtrl.dispose();
    _confirmPinCtrl.dispose();
    super.dispose();
  }

  String? _validateName(String? v) {
    if (v == null || v.trim().length < 2)
      return 'Name must be at least 2 characters';
    return null;
  }

  String? _validatePhone(String? v) {
    final digits = v?.replaceAll(RegExp(r'[^0-9]'), '') ?? '';
    if (digits.length != 10) return 'Enter a valid 10-digit number';
    if (!RegExp(r'^[6-9]').hasMatch(digits)) return 'Must start with 6-9';
    return null;
  }

  String? _validatePin(String? v) {
    if (v == null || v.length != 4) return 'PIN must be exactly 4 digits';
    return null;
  }

  String? _validateConfirmPin(String? v) {
    if (v != _pinCtrl.text) return 'PINs do not match';
    return null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _busy = true);

    try {
      final dio = DioClient.instance.dio;
      final digits = _phoneCtrl.text.trim().replaceAll(RegExp(r'[^0-9]'), '');
      await dio.post(
        '/auth/register',
        data: {
          'fullName': _nameCtrl.text.trim(),
          'phone': '+91$digits',
          'role': _selectedRole,
          'pin': _pinCtrl.text,
        },
        options: Options(extra: {'skipAuth': true}),
      );

      if (mounted) {
        context.go('/pending');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(DioClient.toApiException(e).message)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Create Account',
          style: TextStyle(color: _navy, fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Full Name
                    TextFormField(
                      controller: _nameCtrl,
                      textCapitalization: TextCapitalization.words,
                      validator: _validateName,
                      decoration: InputDecoration(
                        labelText: 'Full Name',
                        prefixIcon: const Icon(Icons.person_outline),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    // Mobile Number
                    TextFormField(
                      controller: _phoneCtrl,
                      keyboardType: TextInputType.number,
                      maxLength: 10,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      validator: _validatePhone,
                      decoration: InputDecoration(
                        labelText: 'Mobile Number',
                        counterText: '',
                        prefixIcon: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          alignment: Alignment.center,
                          width: 70,
                          child: const Text(
                            '+91',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    // Role Dropdown
                    DropdownButtonFormField<String>(
                      value: _selectedRole,
                      decoration: InputDecoration(
                        labelText: 'Role',
                        prefixIcon: const Icon(Icons.badge_outlined),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      items: _roles
                          .map((r) => DropdownMenuItem(
                                value: r,
                                child: Text(
                                  r[0].toUpperCase() + r.substring(1),
                                ),
                              ))
                          .toList(),
                      onChanged: (v) {
                        if (v != null) setState(() => _selectedRole = v);
                      },
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    // Create PIN
                    TextFormField(
                      controller: _pinCtrl,
                      keyboardType: TextInputType.number,
                      maxLength: 4,
                      obscureText: _obscurePin,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      validator: _validatePin,
                      decoration: InputDecoration(
                        labelText: 'Create PIN',
                        counterText: '',
                        prefixIcon: const Icon(Icons.lock_outline),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePin
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                          onPressed: () =>
                              setState(() => _obscurePin = !_obscurePin),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    // Confirm PIN
                    TextFormField(
                      controller: _confirmPinCtrl,
                      keyboardType: TextInputType.number,
                      maxLength: 4,
                      obscureText: _obscureConfirm,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      validator: _validateConfirmPin,
                      decoration: InputDecoration(
                        labelText: 'Confirm PIN',
                        counterText: '',
                        prefixIcon: const Icon(Icons.lock_outline),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureConfirm
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                          onPressed: () => setState(
                              () => _obscureConfirm = !_obscureConfirm),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),

                    // Submit
                    SizedBox(
                      height: 50,
                      child: FilledButton(
                        onPressed: _busy ? null : _submit,
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
                                'Register',
                                style: TextStyle(fontSize: 16),
                              ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    // Already have account
                    TextButton(
                      onPressed: () => context.go('/login'),
                      child: const Text('Already have account? Log in'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
