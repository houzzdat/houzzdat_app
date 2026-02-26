/// Type-safe model for the `users` table.
///
/// CI-07: Replaces stringly-typed `Map<String, dynamic>` across the codebase.
class AppUser {
  final String id;
  final String? email;
  final String? fullName;
  final String? phoneNumber;
  final String? role;
  final String? accountId;
  final String? currentProjectId;
  final bool quickTagEnabled;
  final bool geofenceExempt;
  final DateTime? createdAt;

  const AppUser({
    required this.id,
    this.email,
    this.fullName,
    this.phoneNumber,
    this.role,
    this.accountId,
    this.currentProjectId,
    this.quickTagEnabled = false,
    this.geofenceExempt = false,
    this.createdAt,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id']?.toString() ?? '',
      email: json['email']?.toString(),
      fullName: json['full_name']?.toString(),
      phoneNumber: json['phone_number']?.toString(),
      role: json['role']?.toString(),
      accountId: json['account_id']?.toString(),
      currentProjectId: json['current_project_id']?.toString(),
      quickTagEnabled: json['quick_tag_enabled'] == true,
      geofenceExempt: json['geofence_exempt'] == true,
      createdAt: _tryParseDate(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'email': email,
    'full_name': fullName,
    'phone_number': phoneNumber,
    'role': role,
    'account_id': accountId,
    'current_project_id': currentProjectId,
    'quick_tag_enabled': quickTagEnabled,
    'geofence_exempt': geofenceExempt,
    'created_at': createdAt?.toIso8601String(),
  };

  /// Display name: prefers full_name, falls back to email, then 'Unknown'.
  String get displayName => fullName ?? email ?? 'Unknown';

  AppUser copyWith({
    String? id,
    String? email,
    String? fullName,
    String? phoneNumber,
    String? role,
    String? accountId,
    String? currentProjectId,
    bool? quickTagEnabled,
    bool? geofenceExempt,
    DateTime? createdAt,
  }) {
    return AppUser(
      id: id ?? this.id,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      role: role ?? this.role,
      accountId: accountId ?? this.accountId,
      currentProjectId: currentProjectId ?? this.currentProjectId,
      quickTagEnabled: quickTagEnabled ?? this.quickTagEnabled,
      geofenceExempt: geofenceExempt ?? this.geofenceExempt,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is AppUser && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'AppUser(id: $id, name: $displayName, role: $role)';
}

DateTime? _tryParseDate(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  try {
    return DateTime.parse(value.toString());
  } catch (_) {
    return null;
  }
}
