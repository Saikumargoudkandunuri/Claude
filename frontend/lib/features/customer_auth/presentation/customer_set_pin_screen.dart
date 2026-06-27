import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/customer_dio_client.dart';
import '../data/customer_auth_api.dart';

const _brandColor = Color(0xFF00D1DC);

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
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_brandColor, Color(0xFF0097A7)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 60),
              // Title
              Text(
                _step == _PinStep.enter
                    ? 'Create your PIN'
                    : 'Confirm your PIN',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _step == _PinStep.enter
                    ? 'Enter a 4-digit PIN to secure your account'
                    : 'Re-enter your PIN to confirm',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withValues(alpha: 0.85),
                ),
              ),
              const SizedBox(height: 40),

              // PIN dots
              _PinDots(filledCount: _currentInput.length),

              // Error message
              if (_error != null) ...[
                const SizedBox(height: 20),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 40),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 18,
                        color: Colors.red.shade700,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _error!,
                        style: TextStyle(
                          color: Colors.red.shade700,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const Spacer(),

              // Loading indicator
              if (_busy)
                const Padding(
                  padding: EdgeInsets.only(bottom: 20),
                  child: CircularProgressIndicator(color: Colors.white),
                ),

              // Custom numpad
              if (!_busy)
                _CustomNumpad(onDigit: _onDigit, onBackspace: _onBackspace),

              const SizedBox(height: 30),
            ],
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
          margin: const EdgeInsets.symmetric(horizontal: 10),
          width: filled ? 20 : 16,
          height: filled ? 20 : 16,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: filled ? Colors.white : Colors.transparent,
            border: Border.all(
              color: Colors.white,
              width: 2,
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        children: [
          // Row 1: 1 2 3
          _buildRow(['1', '2', '3']),
          const SizedBox(height: 16),
          // Row 2: 4 5 6
          _buildRow(['4', '5', '6']),
          const SizedBox(height: 16),
          // Row 3: 7 8 9
          _buildRow(['7', '8', '9']),
          const SizedBox(height: 16),
          // Row 4: empty 0 backspace
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Empty space
              const SizedBox(width: 72, height: 72),
              // 0
              _NumpadButton(label: '0', onTap: () => onDigit('0')),
              // Backspace
              SizedBox(
                width: 72,
                height: 72,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(36),
                    onTap: onBackspace,
                    child: const Center(
                      child: Icon(
                        Icons.backspace_outlined,
                        color: Colors.white,
                        size: 26,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
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
    return SizedBox(
      width: 72,
      height: 72,
      child: Material(
        color: Colors.white.withValues(alpha: 0.15),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Center(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
