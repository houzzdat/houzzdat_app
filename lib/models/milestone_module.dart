import 'package:houzzdat_app/models/json_helpers.dart';

class MilestoneModule {
  final String id;
  final String? accountId;
  final String name;
  final String? description;
  final ModuleCategory category;
  final int typicalDurationDays;
  final int sequenceOrder;
  final List<String> dependencies;
  final IndianConstructionContext indianContext;
  final DateTime createdAt;

  const MilestoneModule({
    required this.id,
    this.accountId,
    required this.name,
    this.description,
    required this.category,
    required this.typicalDurationDays,
    required this.sequenceOrder,
    required this.dependencies,
    required this.indianContext,
    required this.createdAt,
  });

  factory MilestoneModule.fromMap(Map<String, dynamic> map) {
    final contextMap = map['indian_context'] as Map<String, dynamic>? ?? {};
    final deps = map['dependencies'];
    List<String> depsList = [];
    if (deps is List) {
      depsList = deps.map((e) => e.toString()).toList();
    }

    return MilestoneModule(
      id: map['id'] as String,
      accountId: map['account_id'] as String?,
      name: map['name'] as String,
      description: map['description'] as String?,
      category: ModuleCategory.fromString(map['category'] as String? ?? 'structural'),
      typicalDurationDays: JsonHelpers.toInt(map['typical_duration_days']) ?? 7,
      sequenceOrder: JsonHelpers.toInt(map['sequence_order']) ?? 0,
      dependencies: depsList,
      indianContext: IndianConstructionContext.fromMap(contextMap),
      createdAt: JsonHelpers.tryParseDate(map['created_at']) ?? DateTime.now(),
    );
  }

  bool get isGlobal => accountId == null;
}

enum ModuleCategory {
  structural,
  mep,
  finishing,
  legal,
  external,
  specialty;

  static ModuleCategory fromString(String s) {
    switch (s) {
      case 'mep': return mep;
      case 'finishing': return finishing;
      case 'legal': return legal;
      case 'external': return external;
      case 'specialty': return specialty;
      default: return structural;
    }
  }

  String get label {
    switch (this) {
      case mep: return 'MEP';
      case finishing: return 'Finishing';
      case legal: return 'Legal';
      case external: return 'External';
      case specialty: return 'Specialty';
      default: return 'Structural';
    }
  }
}

class IndianConstructionContext {
  final String monsoonRisk;        // 'low' | 'medium' | 'high'
  final int monsoonBufferDays;     // extra days to add Jun-Sep
  final String? notes;
  final List<String> localMaterials;

  const IndianConstructionContext({
    this.monsoonRisk = 'low',
    this.monsoonBufferDays = 0,
    this.notes,
    this.localMaterials = const [],
  });

  factory IndianConstructionContext.fromMap(Map<String, dynamic> map) {
    final mats = map['local_materials'];
    List<String> matList = [];
    if (mats is List) {
      matList = mats.map((e) => e.toString()).toList();
    }
    return IndianConstructionContext(
      monsoonRisk: map['monsoon_risk'] as String? ?? 'low',
      monsoonBufferDays: JsonHelpers.toInt(map['monsoon_buffer_days']) ?? 0,
      notes: map['notes'] as String?,
      localMaterials: matList,
    );
  }

  bool get isMonsoonSensitive => monsoonRisk == 'high' || monsoonRisk == 'medium';
}
