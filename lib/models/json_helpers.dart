/// Shared JSON parsing helpers used by all model classes.
///
/// CI-07: Centralises safe type conversions to eliminate `as` casts
/// and string-keyed lookups that can fail silently.
class JsonHelpers {
  JsonHelpers._();

  /// Safely parse a date from a dynamic value.
  /// Accepts DateTime, String, or null.
  static DateTime? tryParseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    try {
      return DateTime.parse(value.toString());
    } catch (_) {
      return null;
    }
  }

  /// Safely convert a dynamic value to double.
  /// Accepts num, String, or null.
  static double? toDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  /// Safely convert a dynamic value to int.
  /// Accepts num, String, or null.
  static int? toInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  /// Safely convert a dynamic value to int with a default fallback.
  static int toIntOr(dynamic value, [int defaultValue = 0]) {
    return toInt(value) ?? defaultValue;
  }

  /// Safely convert a dynamic value to double with a default fallback.
  static double toDoubleOr(dynamic value, [double defaultValue = 0.0]) {
    return toDouble(value) ?? defaultValue;
  }

  /// Safely convert a dynamic value to bool.
  /// Treats `true`, `1`, `'true'`, `'1'` as true.
  static bool toBool(dynamic value) {
    if (value == null) return false;
    if (value is bool) return value;
    if (value is int) return value != 0;
    final str = value.toString().toLowerCase();
    return str == 'true' || str == '1';
  }

  /// Safely extract a list of maps from a dynamic value.
  /// Returns empty list if null or wrong type.
  static List<Map<String, dynamic>> toMapList(dynamic value) {
    if (value == null) return [];
    if (value is List) {
      return value
          .whereType<Map<String, dynamic>>()
          .toList();
    }
    return [];
  }

  /// Safely extract a nested map from a dynamic value.
  static Map<String, dynamic>? toMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    return null;
  }
}
