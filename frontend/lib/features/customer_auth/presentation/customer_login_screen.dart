import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';

import '../../../core/network/customer_dio_client.dart';
import '../data/customer_auth_api.dart';

const _teal = Color(0xFF00D1DC);
const _darkTeal = Color(0xFF004D51);

/// Three-phase customer login screen:
/// 1. Mobile entry → 2. Name reveal (greeting) → 3. PIN entry via custom keypad.
class CustomerLoginScreen extends ConsumerStatefulWidget {
  const CustomerLoginScreen({super.key});

  @override
  ConsumerState<CustomerLoginScreen> createState() =>
      _CustomerLoginScreenState();
}

enum _Phase { mobile, nameReveal, pinEntry }

class _CustomerLoginScreenState extends ConsumerState<CustomerLoginScreen>
    with SingleTickerProviderStateMixin {
  final _phoneCtrl = TextEditingController();

  _Phase _phase = _Phase.mobile;
  bool _busy = false;
  String? _errorMsg;

  // Data from check-mobile response
  String _customerName = '';
  bool _pinSet = false;
  String _pin = '';

  late final AnimationController _nameAnimCtrl;
  late final Animation<double> _nameScale;
  late final Animation<double> _nameOpacity;

  @override
  void initState() {
    super.initState();
    _nameAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _nameScale = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _nameAnimCtrl, curve: Curves.easeOutBack),
    );
    _nameOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _nameAnimCtrl, curve: Curves.easeIn),
    );
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _nameAnimCtrl.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Phase 1: Check mobile
  // ---------------------------------------------------------------------------

  Future<void> _checkMobile() async {
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
      final api = CustomerAuthApi(CustomerDioClient.instance.dio);
      final result = await api.checkMobile('+91$digits');

      final found = result['found'] as bool? ?? false;
      if (!found) {
        if (mounted) {
          setState(() {
            _busy = false;
            _errorMsg = 'No project linked to this mobile number';
          });
        }
        return;
      }

      _customerName = (result['customerName'] as String?) ?? '';
      _pinSet = (result['pinSet'] as bool?) ?? false;

      if (mounted) {
        setState(() {
          _busy = false;
          _phase = _Phase.nameReveal;
        });
        _nameAnimCtrl.forward();

        // If PIN is not set, navigate to set-pin screen after a short delay
        if (!_pinSet) {
          await Future<void>.delayed(const Duration(milliseconds: 1500));
          if (mounted) {
            context
                .go('/customer-set-pin?mobile=+91$digits&name=$_customerName');
          }
        } else {
          // Auto-transition to PIN entry after showing greeting
          await Future<void>.delayed(const Duration(milliseconds: 1500));
          if (mounted) {
            setState(() => _phase = _Phase.pinEntry);
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _errorMsg = _extractErrorMessage(e);
        });
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Phase 3: PIN login
  // ---------------------------------------------------------------------------

  Future<void> _loginWithPin() async {
    final digits = _phoneCtrl.text.trim().replaceAll(RegExp(r'[^0-9]'), '');

    setState(() {
      _busy = true;
      _errorMsg = null;
    });

    try {
      final api = CustomerAuthApi(CustomerDioClient.instance.dio);
      final result = await api.login('+91$digits', _pin);

      final token = result['token'] as String;
      await CustomerDioClient.saveToken(token);

      if (mounted) {
        context.go('/customer');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _pin = '';
          _errorMsg = _extractErrorMessage(e);
        });
      }
    }
  }

  String _extractErrorMessage(Object e) {
    if (e is DioException) {
      final data = e.response?.data;
      if (data is Map && data['error'] is Map) {
        return (data['error']['message'] ?? 'Request failed').toString();
      }
      return e.message ?? 'Network error';
    }
    return e.toString();
  }

  void _onKeyTap(String key) {
    if (_busy) return;

    if (key == 'backspace') {
      if (_pin.isNotEmpty) {
        setState(() {
          _pin = _pin.substring(0, _pin.length - 1);
          _errorMsg = null;
        });
      }
      return;
    }

    if (_pin.length >= 4) return;

    setState(() {
      _pin = _pin + key;
      _errorMsg = null;
    });

    // Auto-submit on 4th digit
    if (_pin.length == 4) {
      _loginWithPin();
    }
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_teal, Color(0xFF0097A7)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                children: [
                  _buildLogo(),
                  const SizedBox(height: 36),
                  _buildCard(),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Column(
      children: [
        Container(
          width: 90,
          height: 90,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: Image.asset(
              'assets/icon/app_icon.png',
              fit: BoxFit.cover,
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Metal & More Interiors',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Customer Portal',
          style: TextStyle(
            fontSize: 13,
            color: Colors.white.withValues(alpha: 0.85),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: switch (_phase) {
        _Phase.mobile => _buildMobilePhase(),
        _Phase.nameReveal => _buildNameRevealPhase(),
        _Phase.pinEntry => _buildPinPhase(),
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Phase 1: Mobile entry
  // ---------------------------------------------------------------------------

  Widget _buildMobilePhase() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Welcome',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: _darkTeal,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6),
        Text(
          'Enter your registered mobile number',
          style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 28),
        TextField(
          controller: _phoneCtrl,
          keyboardType: TextInputType.number,
          maxLength: 10,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 1,
          ),
          decoration: InputDecoration(
            labelText: 'Mobile Number',
            labelStyle: TextStyle(color: Colors.grey.shade600),
            prefixIcon: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              alignment: Alignment.center,
              width: 64,
              child: const Text(
                '+91',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: _darkTeal,
                ),
              ),
            ),
            hintText: '9876543210',
            counterText: '',
            filled: true,
            fillColor: Colors.grey.shade50,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _teal, width: 2),
            ),
          ),
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _checkMobile(),
        ),
        if (_errorMsg != null) ...[
          const SizedBox(height: 12),
          _buildErrorBanner(),
        ],
        const SizedBox(height: 24),
        SizedBox(
          height: 52,
          child: ElevatedButton(
            onPressed: _busy ? null : _checkMobile,
            style: ElevatedButton.styleFrom(
              backgroundColor: _teal,
              foregroundColor: Colors.white,
              disabledBackgroundColor: _teal.withValues(alpha: 0.6),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: _busy
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                : const Text(
                    'Continue',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Phase 2: Name reveal
  // ---------------------------------------------------------------------------

  Widget _buildNameRevealPhase() {
    return AnimatedBuilder(
      animation: _nameAnimCtrl,
      builder: (context, child) {
        return Opacity(
          opacity: _nameOpacity.value,
          child: Transform.scale(
            scale: _nameScale.value,
            child: child,
          ),
        );
      },
      child: Column(
        children: [
          const Icon(Icons.check_circle, color: _teal, size: 56),
          const SizedBox(height: 16),
          Text(
            'Welcome,',
            style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 4),
          Text(
            _customerName,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: _darkTeal,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          if (!_pinSet)
            Text(
              'Setting up your PIN...',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
            )
          else
            Text(
              'Enter your PIN to continue',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
            ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Phase 3: PIN entry with custom keypad
  // ---------------------------------------------------------------------------

  Widget _buildPinPhase() {
    return Column(
      children: [
        Text(
          'Welcome, $_customerName',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: _darkTeal,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6),
        Text(
          'Enter your 4-digit PIN',
          style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 24),
        _buildPinDots(),
        if (_errorMsg != null) ...[
          const SizedBox(height: 12),
          _buildErrorBanner(),
        ],
        const SizedBox(height: 24),
        _buildNumpad(),
      ],
    );
  }

  Widget _buildPinDots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(4, (i) {
        final filled = i < _pin.length;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 10),
          width: filled ? 18 : 16,
          height: filled ? 18 : 16,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: filled ? _teal : Colors.transparent,
            border: Border.all(
              color: filled ? _teal : Colors.grey.shade300,
              width: 2,
            ),
          ),
        );
      }),
    );
  }

  Widget _buildNumpad() {
    const keys = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['', '0', 'backspace'],
    ];

    return Column(
      children: keys.map((row) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: row.map((key) {
              if (key.isEmpty) {
                return const SizedBox(width: 72, height: 56);
              }
              return _buildKeyButton(key);
            }).toList(),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildKeyButton(String key) {
    final isBackspace = key == 'backspace';

    return InkWell(
      onTap: () => _onKeyTap(key),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 72,
        height: 56,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(16),
        ),
        child: isBackspace
            ? Icon(Icons.backspace_outlined, color: Colors.grey.shade700)
            : Text(
                key,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  color: _darkTeal,
                ),
              ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Shared widgets
  // ---------------------------------------------------------------------------

  Widget _buildErrorBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, size: 18, color: Colors.red.shade700),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _errorMsg!,
              style: TextStyle(color: Colors.red.shade700, fontSize: 12.5),
            ),
          ),
        ],
      ),
    );
  }
}
