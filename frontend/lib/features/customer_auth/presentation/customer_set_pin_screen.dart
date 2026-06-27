import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/customer_dio_client.dart';
import '../../customer_portal/theme/customer_theme.dart';
import '../data/customer_auth_api.dart';

/// Screen for first-time customers to create a 4-digit PIN.
///
/// Two-step flow:
/// 1. Enter a new PIN (4 digits via custom numpad)
/// 2. Confirm the PIN (re-enter same 4 digits)
///
/// On match → calls setPin API → auto-login → navigates to /customer shell.
/// On mismatch → shows error, clears inputs, resets to step 1.
class CustomerSetPinScreen extends ConsumerStatefulWidget {
  const CustomerSetPinScreen({super.key});

  @override
  ConsumerState<CustomerSetPinScreen> createState() =>
      _CustomerSetPinScreenState();
}

enum _PinStep { enter, confirm }

class _CustomerSetPinScreenState extends ConsumerState<CustomerSetPinScreen> {
  _PinStep _step = _PinStep.enter;
  String _firstPin = '';
  String _currentInput = '';
  String? _error;
  bool _busy = false;

  String get _mobile {
    // Try query parameter first (navigated via URL)
    final uri = GoRouterState.of(context).uri;
    final queryMobile = uri.queryParameters['mobile'];
    if (queryMobile != null && queryMobile.isNotEmpty) {
      return queryMobile;
    }
    // Fallback to extra map
    final extra = GoRouterState.of(context).extra;
    if (extra is Map<String, dynamic>) {
      return extra['mobile'] as String? ?? '';
    }
    return '';
  }

  void _onDigit(String digit) {
    if (_currentInput.length >= 4 || _busy) return;
    setState(() {
      _currentInput += digit;
      _error = null;
    });

    if (_currentInput.length == 4) {
      _onPinComplete();
    }
  }

  void _onBackspace() {
    if (_currentInput.isEmpty || _busy) return;
    setState(() {
      _currentInput = _currentInput.substring(0, _currentInput.length - 1);
    });
  }

  Future<void> _onPinComplete() async {
    if (_step == _PinStep.enter) {
      // Save first PIN and move to confirm step
      setState(() {
        _firstPin = _currentInput;
        _currentInput = '';
        _step = _PinStep.confirm;
      });
    } else {
      // Confirm step — compare PINs
      if (_currentInput == _firstPin) {
        await _submitPin();
      } else {
        setState(() {
          _error = 'PINs do not match';
          _firstPin = '';
          _currentInput = '';
          _step = _PinStep.enter;
        });
      }
    }
  }

  Future<void> _submitPin() async {
    setState(() => _busy = true);

    try {
      final api = CustomerAuthApi(CustomerDioClient.instance.dio);
      final mobile = _mobile;

      // Set the PIN
      await api.setPin(mobile, _firstPin);

      // Auto-login after setting PIN
      final loginResult = await api.login(mobile, _firstPin);
      final token = loginResult['token'] as String;

      // Store the customer token
      await CustomerDioClient.saveToken(token);

      if (mounted) {
        context.go('/customer');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = 'Something went wrong. Please try again.';
          _firstPin = '';
          _currentInput = '';
          _step = _PinStep.enter;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: CTheme.heroGradient),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: CTheme.p24),
              child: Column(
                children: [
                  const SizedBox(height: 40),
                  // White card
                  Container(
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: CTheme.bgWhite,
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: CTheme.heroShadow,
                    ),
                    child: Column(
                      children: [
                        // Lock icon
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: CTheme.primary.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.lock_outline_rounded,
                            color: CTheme.primary,
                            size: 28,
                          ),
                        ),
                        const SizedBox(height: CTheme.p20),

                        // Title
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          child: Text(
                            _step == _PinStep.enter
                                ? 'Create your PIN'
                                : 'Confirm your PIN',
                            key: ValueKey(_step),
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: CTheme.textDark,
                            ),
                          ),
                        ),
                        const SizedBox(height: CTheme.p8),
                        Text(
                          _step == _PinStep.enter
                              ? 'Enter a 4-digit PIN to secure your account'
                              : 'Re-enter your PIN to confirm',
                          style: const TextStyle(
                            fontSize: 13,
                            color: CTheme.textMid,
                          ),
                        ),
                        const SizedBox(height: CTheme.p32),

                        // PIN dots
                        _PinDots(filledCount: _currentInput.length),

                        // Error message
                        if (_error != null) ...[
                          const SizedBox(height: CTheme.p16),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: CTheme.p12,
                              vertical: CTheme.p8,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF2F2),
                              borderRadius: CTheme.r8,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.error_outline,
                                  size: 18,
                                  color: Color(0xFFDC2626),
                                ),
                                const SizedBox(width: CTheme.p8),
                                Text(
                                  _error!,
                                  style: const TextStyle(
                                    color: Color(0xFFDC2626),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        const SizedBox(height: CTheme.p32),

                        // Loading indicator or numpad
                        if (_busy)
                          const Padding(
                            padding: EdgeInsets.only(bottom: CTheme.p20),
                            child: CircularProgressIndicator(
                                color: CTheme.primary),
                          )
                        else
                          _CustomNumpad(
                            onDigit: _onDigit,
                            onBackspace: _onBackspace,
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// PIN Dots Widget
// ---------------------------------------------------------------------------

class _PinDots extends StatelessWidget {
  const _PinDots({required this.filledCount});

  final int filledCount;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(4, (index) {
        final filled = index < filledCount;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          margin: const EdgeInsets.symmetric(horizontal: 12),
          width: filled ? 22 : 16,
          height: filled ? 22 : 16,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: filled ? CTheme.primary : Colors.transparent,
            border: Border.all(
              color: filled ? CTheme.primary : CTheme.inactive,
              width: 2.5,
            ),
          ),
        );
      }),
    );
  }
}

// ---------------------------------------------------------------------------
// Custom Numeric Keypad Widget
// ---------------------------------------------------------------------------

class _CustomNumpad extends StatelessWidget {
  const _CustomNumpad({
    required this.onDigit,
    required this.onBackspace,
  });

  final void Function(String digit) onDigit;
  final VoidCallback onBackspace;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildRow(['1', '2', '3']),
        const SizedBox(height: CTheme.p12),
        _buildRow(['4', '5', '6']),
        const SizedBox(height: CTheme.p12),
        _buildRow(['7', '8', '9']),
        const SizedBox(height: CTheme.p12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            const SizedBox(width: 64, height: 52),
            _NumpadButton(label: '0', onTap: () => onDigit('0')),
            SizedBox(
              width: 64,
              height: 52,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: CTheme.r16,
                  onTap: onBackspace,
                  child: const Center(
                    child: Icon(
                      Icons.backspace_outlined,
                      color: CTheme.textMid,
                      size: 22,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRow(List<String> digits) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: digits
          .map((d) => _NumpadButton(label: d, onTap: () => onDigit(d)))
          .toList(),
    );
  }
}

class _NumpadButton extends StatelessWidget {
  const _NumpadButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: CTheme.r16,
      child: Container(
        width: 64,
        height: 52,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: CTheme.bgSoft,
          borderRadius: CTheme.r16,
          border: Border.all(color: CTheme.inactive),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: CTheme.textDark,
          ),
        ),
      ),
    );
  }
}
