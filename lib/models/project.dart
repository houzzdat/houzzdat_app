import 'package:houzzdat_app/models/json_helpers.dart';

/// Type-safe model for the `projects` table.
///
/// CI-07: Replaces stringly-typed `Map<String, dynamic>` across the codebase.
class Project {
  final String id;
  final String? name;
  final String? location;
  final String? address;
  final String? accountId;
  final double? siteLatitude;
  final double? siteLongitude;
  final double? geofenceRadiusM;
  final DateTime? createdAt;

  const Project({
    required this.id,
    this.name,
    this.location,
    this.address,
    this.accountId,
    this.siteLatitude,
    this.siteLongitude,
    this.geofenceRadiusM,
    this.createdAt,
  });

  factory Project.fromJson(Map<String, dynamic> json) {
    return Project(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString(),
      location: json['location']?.toString(),
      address: json['address']?.toString(),
      accountId: json['account_id']?.toString(),
      siteLatitude: JsonHelpers.toDouble(json['site_latitude']),
      siteLongitude: JsonHelpers.toDouble(json['site_longitude']),
      geofenceRadiusM: JsonHelpers.toDouble(json['geofence_radius_m']),
      createdAt: JsonHelpers.tryParseDate(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'location': location,
    'address': address,
    'account_id': accountId,
    'site_latitude': siteLatitude,
    'site_longitude': siteLongitude,
    'geofence_radius_m': geofenceRadiusM,
    'created_at': createdAt?.toIso8601String(),
  };

  /// Display name: prefers name, falls back to location, then 'Unnamed Project'.
  String get displayName => name ?? location ?? 'Unnamed Project';

  Project copyWith({
    String? id,
    String? name,
    String? location,
    String? address,
    String? accountId,
    double? siteLatitude,
    double? siteLongitude,
    double? geofenceRadiusM,
    DateTime? createdAt,
  }) {
    return Project(
      id: id ?? this.id,
      name: name ?? this.name,
      location: location ?? this.location,
      address: address ?? this.address,
      accountId: accountId ?? this.accountId,
      siteLatitude: siteLatitude ?? this.siteLatitude,
      siteLongitude: siteLongitude ?? this.siteLongitude,
      geofenceRadiusM: geofenceRadiusM ?? this.geofenceRadiusM,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Project && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Project(id: $id, name: $displayName)';
}
