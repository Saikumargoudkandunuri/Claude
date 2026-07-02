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
    // Convert UTC timestamps from the backend to the device's local timezone
    // before formatting so dates/times display correctly for the user's region.
    return DateFormat('dd MMM yyyy').format(dt.toLocal());
  }

  static String dateTime(dynamic value) {
    if (value == null) return '-';
    final dt = value is DateTime ? value : DateTime.tryParse(value.toString());
    if (dt == null) return '-';
    return DateFormat('dd MMM yyyy, hh:mm a').format(dt.toLocal());
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

  /// Normalize an Indian mobile number to canonical `+91XXXXXXXXXX` form so it
  /// matches the customer-portal login (which always queries with `+91`).
  ///
  /// Accepts inputs like `9876543210`, `+91 98765 43210`, `09876543210`,
  /// `919876543210`. Returns the trimmed original when a valid 10-digit
  /// number cannot be extracted (so unrelated values are left untouched).
  static String normalizeIndianPhone(String? raw) {
    if (raw == null) return '';
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return '';
    var digits = trimmed.replaceAll(RegExp(r'[^0-9]'), '');
    // Drop country code / leading zero to isolate the 10-digit subscriber no.
    if (digits.length == 12 && digits.startsWith('91')) {
      digits = digits.substring(2);
    } else if (digits.length == 11 && digits.startsWith('0')) {
      digits = digits.substring(1);
    } else if (digits.length > 10) {
      digits = digits.substring(digits.length - 10);
    }
    if (digits.length != 10) {
      return trimmed; // not a normal mobile — leave as-is
    }
    return '+91$digits';
  }
}
