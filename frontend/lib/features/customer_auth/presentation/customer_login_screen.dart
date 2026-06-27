import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';

import '../../../core/network/customer_dio_client.dart';
import '../../../core/utils/web_platform.dart' as web_platform;
import '../../customer_portal/theme/customer_theme.dart';
import '../data/customer_auth_api.dart';

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
        decoration: const BoxDecoration(gradient: CTheme.heroGradient),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: CTheme.p24),
              child: Column(
                children: [
                  _buildLogo(),
                  const SizedBox(height: 36),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 400),
                    switchInCurve: Curves.easeOut,
                    switchOutCurve: Curves.easeIn,
                    child: _buildCard(),
                  ),
                  if (kIsWeb) ...[
                    const SizedBox(height: 24),
                    const _WebDownloadSection(),
                  ],
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
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: CTheme.bgWhite,
            borderRadius: CTheme.r20,
            boxShadow: CTheme.heroShadow,
          ),
          child: ClipRRect(
            borderRadius: CTheme.r20,
            child: Image.asset(
              'assets/icon/app_icon.png',
              fit: BoxFit.cover,
            ),
          ),
        ),
        const SizedBox(height: CTheme.p16),
        const Text(
          'Metal & More Interiors',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: CTheme.bgWhite,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: CTheme.p4),
        Text(
          'Customer Portal',
          style: TextStyle(
            fontSize: 13,
            color: CTheme.bgWhite.withValues(alpha: 0.85),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildCard() {
    Widget content;
    switch (_phase) {
      case _Phase.mobile:
        content = _buildMobilePhase();
      case _Phase.nameReveal:
        content = _buildNameRevealPhase();
      case _Phase.pinEntry:
        content = _buildPinPhase();
    }

    return Container(
      key: ValueKey(_phase),
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: CTheme.bgWhite,
        borderRadius: BorderRadius.circular(28),
        boxShadow: CTheme.heroShadow,
      ),
      child: content,
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
          'Welcome Back',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: CTheme.textDark,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: CTheme.p4),
        const Text(
          'Enter your registered mobile number',
          style: TextStyle(fontSize: 13, color: CTheme.textMid),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: CTheme.p24),
        Container(
          decoration: BoxDecoration(
            color: CTheme.bgSoft,
            borderRadius: CTheme.r12,
            border: Border.all(color: CTheme.inactive),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: CTheme.p16),
                child: const Text(
                  '+91',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: CTheme.primaryDeep,
                  ),
                ),
              ),
              Container(width: 1, height: 28, color: CTheme.inactive),
              Expanded(
                child: TextField(
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.number,
                  maxLength: 10,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1,
                    color: CTheme.textDark,
                  ),
                  decoration: const InputDecoration(
                    hintText: '9876543210',
                    hintStyle: TextStyle(color: CTheme.textLight),
                    counterText: '',
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: CTheme.p12,
                      vertical: CTheme.p16,
                    ),
                  ),
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _checkMobile(),
                ),
              ),
            ],
          ),
        ),
        if (_errorMsg != null) ...[
          const SizedBox(height: CTheme.p12),
          _buildErrorBanner(),
        ],
        const SizedBox(height: CTheme.p24),
        _GradientButton(
          label: 'Continue',
          busy: _busy,
          onPressed: _checkMobile,
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
          Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: CTheme.heroGradient,
            ),
            child: Center(
              child: Text(
                _customerName.isNotEmpty ? _customerName[0].toUpperCase() : '?',
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: CTheme.bgWhite,
                ),
              ),
            ),
          ),
          const SizedBox(height: CTheme.p16),
          const Text(
            'Welcome,',
            style: TextStyle(fontSize: 16, color: CTheme.textMid),
          ),
          const SizedBox(height: CTheme.p4),
          Text(
            _customerName,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: CTheme.textDark,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: CTheme.p16),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: CTheme.p12,
              vertical: CTheme.p8,
            ),
            decoration: BoxDecoration(
              color: CTheme.success.withValues(alpha: 0.1),
              borderRadius: CTheme.r8,
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle, color: CTheme.success, size: 18),
                SizedBox(width: CTheme.p8),
                Text(
                  'We found your project ✓',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: CTheme.success,
                  ),
                ),
              ],
            ),
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
            color: CTheme.textDark,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: CTheme.p4),
        const Text(
          'Enter your 4-digit PIN',
          style: TextStyle(fontSize: 13, color: CTheme.textMid),
        ),
        const SizedBox(height: CTheme.p24),
        _buildPinDots(),
        if (_errorMsg != null) ...[
          const SizedBox(height: CTheme.p12),
          _buildErrorBanner(),
        ],
        const SizedBox(height: CTheme.p24),
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
          curve: Curves.easeOut,
          margin: const EdgeInsets.symmetric(horizontal: 10),
          width: filled ? 20 : 16,
          height: filled ? 20 : 16,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: filled ? CTheme.primary : Colors.transparent,
            border: Border.all(
              color: filled ? CTheme.primary : CTheme.inactive,
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
                return const SizedBox(width: 64, height: 52);
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
        child: isBackspace
            ? const Icon(Icons.backspace_outlined, color: CTheme.textMid)
            : Text(
                key,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: CTheme.textDark,
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
      padding: const EdgeInsets.symmetric(
          horizontal: CTheme.p12, vertical: CTheme.p8),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: CTheme.r8,
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, size: 18, color: Color(0xFFDC2626)),
          const SizedBox(width: CTheme.p8),
          Expanded(
            child: Text(
              _errorMsg!,
              style: const TextStyle(color: Color(0xFFDC2626), fontSize: 12.5),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Gradient Button
// ---------------------------------------------------------------------------

class _GradientButton extends StatelessWidget {
  const _GradientButton({
    required this.label,
    required this.busy,
    required this.onPressed,
  });

  final String label;
  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: busy ? null : onPressed,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          gradient: CTheme.heroGradient,
          borderRadius: CTheme.r16,
          boxShadow: CTheme.heroShadow,
        ),
        child: Center(
          child: busy
              ? const SizedBox(
                  height: 22,
                  width: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: CTheme.bgWhite,
                  ),
                )
              : Text(
                  label,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: CTheme.bgWhite,
                  ),
                ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Web Download / Add-to-Home-Screen Section
// ---------------------------------------------------------------------------

class _WebDownloadSection extends StatelessWidget {
  const _WebDownloadSection();

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) return const SizedBox.shrink();

    final isAndroid = web_platform.isWebAndroid();
    final isIOS = web_platform.isWebIOS();

    if (isAndroid) return const _AndroidDownloadWidget();
    if (isIOS) return const _IOSHomeScreenWidget();
    return const SizedBox.shrink(); // Desktop — show nothing
  }
}

class _AndroidDownloadWidget extends StatelessWidget {
  const _AndroidDownloadWidget();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        OutlinedButton.icon(
          onPressed: () => web_platform.triggerApkDownload(),
          icon: const Icon(Icons.download, color: CTheme.primary),
          label: const Text(
            'Download App for Android',
            style: TextStyle(
              color: CTheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: CTheme.primary, width: 1.5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'After download, tap the file to install',
          style: TextStyle(
            fontSize: 12,
            color: CTheme.bgWhite.withValues(alpha: 0.85),
          ),
        ),
      ],
    );
  }
}

class _IOSHomeScreenWidget extends StatelessWidget {
  const _IOSHomeScreenWidget();

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () => _showIOSInstructions(context),
      icon: const Icon(Icons.add_to_home_screen, color: CTheme.primary),
      label: const Text(
        'Add to Home Screen for iPhone',
        style: TextStyle(
          color: CTheme.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: CTheme.primary, width: 1.5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      ),
    );
  }

  void _showIOSInstructions(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Add to Home Screen',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: CTheme.textDark,
                  ),
                ),
                const SizedBox(height: 20),
                _buildStep(
                  number: '1',
                  text: 'Tap the Share icon at the bottom of Safari',
                  icon: Icons.ios_share,
                ),
                const SizedBox(height: 14),
                _buildStep(
                  number: '2',
                  text: 'Scroll down and tap "Add to Home Screen"',
                  icon: Icons.add_box_outlined,
                ),
                const SizedBox(height: 14),
                _buildStep(
                  number: '3',
                  text: 'Tap Add',
                  icon: Icons.check_circle_outline,
                ),
                const SizedBox(height: 24),
                // Visual arrow pointing down toward Safari share bar
                Column(
                  children: [
                    Text(
                      'Look for this icon below',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Icon(
                      Icons.ios_share,
                      size: 28,
                      color: CTheme.primary,
                    ),
                    const SizedBox(height: 4),
                    const Icon(
                      Icons.keyboard_arrow_down,
                      size: 32,
                      color: CTheme.primary,
                    ),
                    const Icon(
                      Icons.keyboard_arrow_down,
                      size: 32,
                      color: CTheme.primary,
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStep({
    required String number,
    required String text,
    required IconData icon,
  }) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: CTheme.heroGradient,
          ),
          child: Center(
            child: Text(
              number,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Icon(icon, size: 20, color: CTheme.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 14,
              color: CTheme.textDark,
            ),
          ),
        ),
      ],
    );
  }
}
