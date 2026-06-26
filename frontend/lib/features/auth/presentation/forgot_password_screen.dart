import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/dio_client.dart';
import '../../../core/theme/app_spacing.dart';

const _navy = Color(0xFF1A237E);
const _blue = Color(0xFF1565C0);
const _error = Color(0xFFD32F2F);
const _success = Color(0xFF2E7D32);

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

  final _employeeIdCtrl = TextEditingController();
  final _newPinCtrl = TextEditingController();
  final _confirmPinCtrl = TextEditingController();

  bool _obscureNew = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _employeeIdCtrl.dispose();
    _newPinCtrl.dispose();
    _confirmPinCtrl.dispose();
    super.dispose();
  }

  void _continueToStep1() {
    final id = _employeeIdCtrl.text.trim();
    if (id.isEmpty) {
      setState(() => _errorMsg = 'Please enter your Employee ID');
      return;
    }
    setState(() {
      _errorMsg = null;
      _step = 1;
    });
  }

  Future<void> _resetPin() async {
    final pin = _newPinCtrl.text;
    if (pin.length != 4) {
      setState(() => _errorMsg = 'PIN must be exactly 4 digits');
      return;
    }
    if (pin != _confirmPinCtrl.text) {
      setState(() => _errorMsg = 'PINs do not match');
      return;
    }

    setState(() {
      _busy = true;
      _errorMsg = null;
    });

    try {
      final dio = DioClient.instance.dio;
      await dio.post(
        '/auth/reset-pin-by-id',
        data: {
          'userId': _employeeIdCtrl.text.trim(),
          'newPin': pin,
        },
        options: Options(extra: {'skipAuth': true}),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('PIN reset successfully'),
            backgroundColor: _success,
          ),
        );
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
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (_step == 1) {
              setState(() {
                _step = 0;
                _errorMsg = null;
              });
            } else {
              context.go('/login');
            }
          },
        ),
        title: const Text(
          'Reset PIN',
          style: TextStyle(color: _navy, fontWeight: FontWeight.w700),
        ),
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
                  if (_step == 0) ..._buildStep0(),
                  if (_step == 1) ..._buildStep1(),
                  if (_errorMsg != null) ...[
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      _errorMsg!,
                      style: const TextStyle(color: _error, fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildStep0() {
    return [
      const Icon(Icons.badge_outlined, size: 64, color: _navy),
      const SizedBox(height: AppSpacing.lg),
      const Text(
        'Enter your Employee ID',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: _navy,
        ),
      ),
      const SizedBox(height: AppSpacing.sm),
      const Text(
        'Ask your administrator for your Employee ID if you don\'t have it.',
        textAlign: TextAlign.center,
        style: TextStyle(color: Color(0xFF64748B), fontSize: 14),
      ),
      const SizedBox(height: AppSpacing.xxl),
      TextField(
        controller: _employeeIdCtrl,
        decoration: InputDecoration(
          labelText: 'Employee ID',
          prefixIcon: const Icon(Icons.badge_outlined),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      const SizedBox(height: AppSpacing.xl),
      SizedBox(
        height: 50,
        child: FilledButton(
          onPressed: _continueToStep1,
          style: FilledButton.styleFrom(
            backgroundColor: _blue,
            minimumSize: const Size.fromHeight(50),
          ),
          child: const Text('Continue', style: TextStyle(fontSize: 16)),
        ),
      ),
    ];
  }

  List<Widget> _buildStep1() {
    return [
      const Icon(Icons.lock_reset, size: 64, color: _navy),
      const SizedBox(height: AppSpacing.lg),
      const Text(
        'Set a New PIN',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: _navy,
        ),
      ),
      const SizedBox(height: AppSpacing.xxl),

      // New PIN
      TextField(
        controller: _newPinCtrl,
        keyboardType: TextInputType.number,
        maxLength: 4,
        obscureText: _obscureNew,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(
          labelText: 'New PIN',
          counterText: '',
          prefixIcon: const Icon(Icons.lock_outline),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          suffixIcon: IconButton(
            icon: Icon(
              _obscureNew ? Icons.visibility_off : Icons.visibility,
            ),
            onPressed: () => setState(() => _obscureNew = !_obscureNew),
          ),
        ),
      ),
      const SizedBox(height: AppSpacing.lg),

      // Confirm PIN
      TextField(
        controller: _confirmPinCtrl,
        keyboardType: TextInputType.number,
        maxLength: 4,
        obscureText: _obscureConfirm,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(
          labelText: 'Confirm PIN',
          counterText: '',
          prefixIcon: const Icon(Icons.lock_outline),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          suffixIcon: IconButton(
            icon: Icon(
              _obscureConfirm ? Icons.visibility_off : Icons.visibility,
            ),
            onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
          ),
        ),
      ),
      const SizedBox(height: AppSpacing.xl),

      // Reset button
      SizedBox(
        height: 50,
        child: FilledButton(
          onPressed: _busy ? null : _resetPin,
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
              : const Text('Reset PIN', style: TextStyle(fontSize: 16)),
        ),
      ),
    ];
  }
}
