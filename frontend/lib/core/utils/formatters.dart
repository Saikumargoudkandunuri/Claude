import 'package:intl/intl.dart';

/// Display formatting helpers (currency in INR, dates, stage labels).
class Formatters {
  Formatters._();

  static final NumberFormat _currency = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 0,
  );

  static String currency(num? value) => _currency.format(value ?? 0);

  static String date(dynamic value) {
    if (value == null) return '-';
    final dt = value is DateTime ? value : DateTime.tryParse(value.toString());
    if (dt == null) return '-';
    return DateFormat('dd MMM yyyy').format(dt);
  }

  static String dateTime(dynamic value) {
    if (value == null) return '-';
    final dt = value is DateTime ? value : DateTime.tryParse(value.toString());
    if (dt == null) return '-';
    return DateFormat('dd MMM yyyy, hh:mm a').format(dt);
  }

  /// Convert 'material_purchase' -> 'Material Purchase'.
  static String stageLabel(String? stage) {
    if (stage == null || stage.isEmpty) return '-';
    return stage
        .split('_')
        .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ')
        .replaceAll('3d', '3D');
  }

  static String roleLabel(String? role) {
    if (role == null) return '-';
    return '${role[0].toUpperCase()}${role.substring(1)}';
  }
}
