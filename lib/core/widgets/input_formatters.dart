import 'package:flutter/services.dart';

/// UX-audit #13: Indian currency formatter with thousand separators.
/// Formats numbers as they're typed: 1,00,000 (Indian grouping).
/// Only formats the integer part; preserves decimal input.
class IndianCurrencyFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;
    if (text.isEmpty) return newValue;

    // Split integer and decimal parts
    final parts = text.split('.');
    final integerPart = parts[0].replaceAll(',', '');
    final decimalPart = parts.length > 1 ? '.${parts[1]}' : '';

    if (integerPart.isEmpty) return newValue;

    // Format integer part with Indian grouping (last 3, then groups of 2)
    final formatted = _formatIndian(integerPart);

    final newText = '$formatted$decimalPart';
    return TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newText.length),
    );
  }

  String _formatIndian(String digits) {
    if (digits.length <= 3) return digits;

    final last3 = digits.substring(digits.length - 3);
    var remaining = digits.substring(0, digits.length - 3);

    final buffer = StringBuffer();
    while (remaining.length > 2) {
      buffer.write('${remaining.substring(0, remaining.length - 2)},');
      remaining = remaining.substring(remaining.length - 2);
    }
    if (remaining.isNotEmpty) {
      // This handles the remaining digits
      return '${digits.substring(0, digits.length - 3).replaceAllMapped(
        RegExp(r'(\d)(?=(\d{2})+$)'),
        (m) => '${m[1]},',
      )},$last3';
    }
    return '$remaining,$last3';
  }
}

/// Simpler implementation using regex for Indian number formatting.
class IndianNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text.replaceAll(',', '');
    if (text.isEmpty) return newValue;

    // Split on decimal point
    final parts = text.split('.');
    if (parts[0].isEmpty) return newValue;

    final intPart = parts[0];
    final decPart = parts.length > 1 ? '.${parts[1]}' : '';

    // Indian grouping: last 3 digits, then every 2
    String formatted;
    if (intPart.length <= 3) {
      formatted = intPart;
    } else {
      final last3 = intPart.substring(intPart.length - 3);
      final rest = intPart.substring(0, intPart.length - 3);
      final groups = <String>[];
      var i = rest.length;
      while (i > 0) {
        final start = (i - 2) < 0 ? 0 : i - 2;
        groups.insert(0, rest.substring(start, i));
        i = start;
      }
      formatted = '${groups.join(',')},${last3}';
    }

    final result = '$formatted$decPart';
    return TextEditingValue(
      text: result,
      selection: TextSelection.collapsed(offset: result.length),
    );
  }
}

/// UX-audit #13: Phone number formatter for Indian numbers.
/// Formats as: +91 XXXXX XXXXX
class IndianPhoneFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var digits = newValue.text.replaceAll(RegExp(r'[^\d+]'), '');

    // If starts with +91, format after that
    if (digits.startsWith('+91')) {
      final number = digits.substring(3);
      if (number.length <= 5) {
        digits = '+91 $number';
      } else {
        digits = '+91 ${number.substring(0, 5)} ${number.substring(5, number.length > 10 ? 10 : number.length)}';
      }
    } else if (digits.startsWith('+')) {
      // Other country codes — don't format
      return newValue;
    } else {
      // No country code — format as 10-digit Indian number
      if (digits.length <= 5) {
        // Leave as-is
      } else if (digits.length <= 10) {
        digits = '${digits.substring(0, 5)} ${digits.substring(5)}';
      } else {
        digits = '${digits.substring(0, 5)} ${digits.substring(5, 10)}';
      }
    }

    return TextEditingValue(
      text: digits,
      selection: TextSelection.collapsed(offset: digits.length),
    );
  }
}
