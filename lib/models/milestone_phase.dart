import 'package:houzzdat_app/models/json_helpers.dart';

class MilestonePhase {
  final String id;
  final String projectId;
  final String accountId;
  final String? moduleId;
  final String name;
  final String? description;
  final int phaseOrder;
  final MilestonePhaseStatus status;
  final DateTime? plannedStart;
  final DateTime? plannedEnd;
  final DateTime? actualStart;
  final DateTime? actualEnd;
  final double? budgetAllocated;
  final double budgetSpent;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<KeyResult> keyResults;

  const MilestonePhase({
    required this.id,
    required this.projectId,
    required this.accountId,
    this.moduleId,
    required this.name,
    this.description,
    required this.phaseOrder,
    required this.status,
    this.plannedStart,
    this.plannedEnd,
    this.actualStart,
    this.actualEnd,
    this.budgetAllocated,
    required this.budgetSpent,
    required this.createdAt,
    required this.updatedAt,
    this.keyResults = const [],
  });

  factory MilestonePhase.fromMap(Map<String, dynamic> map) {
    return MilestonePhase(
      id: map['id'] as String,
      projectId: map['project_id'] as String,
      accountId: map['account_id'] as String,
      moduleId: map['module_id'] as String?,
      name: map['name'] as String,
      description: map['description'] as String?,
      phaseOrder: JsonHelpers.toInt(map['phase_order']) ?? 0,
      status: MilestonePhaseStatus.fromString(map['status'] as String? ?? 'pending'),
      plannedStart: JsonHelpers.tryParseDate(map['planned_start']),
      plannedEnd: JsonHelpers.tryParseDate(map['planned_end']),
      actualStart: JsonHelpers.tryParseDate(map['actual_start']),
      actualEnd: JsonHelpers.tryParseDate(map['actual_end']),
      budgetAllocated: JsonHelpers.toDouble(map['budget_allocated']),
      budgetSpent: JsonHelpers.toDouble(map['budget_spent']) ?? 0,
      createdAt: JsonHelpers.tryParseDate(map['created_at']) ?? DateTime.now(),
      updatedAt: JsonHelpers.tryParseDate(map['updated_at']) ?? DateTime.now(),
      keyResults: JsonHelpers.toMapList(map['key_results'])
          .map((kr) => KeyResult.fromMap(kr))
          .toList(),
    );
  }

  /// Days remaining to planned_end from today. Negative = overdue.
  int get daysRemaining {
    if (plannedEnd == null) return 0;
    return plannedEnd!.difference(DateTime.now()).inDays;
  }

  /// Overall KR completion percentage (0–100).
  double get completionPercent {
    if (keyResults.isEmpty) return 0;
    final total = keyResults.fold<double>(0, (sum, kr) => sum + kr.progressPercent);
    return (total / keyResults.length).clamp(0, 100);
  }

  /// Budget burn percentage (0–100+).
  double get budgetBurnPercent {
    if (budgetAllocated == null || budgetAllocated! <= 0) return 0;
    return ((budgetSpent / budgetAllocated!) * 100).clamp(0, 200);
  }

  bool get isActive => status == MilestonePhaseStatus.active;
  bool get isCompleted => status == MilestonePhaseStatus.completed;
  bool get isBlocked => status == MilestonePhaseStatus.blocked;
  bool get isAtGateReview => status == MilestonePhaseStatus.gateReview;
}

enum MilestonePhaseStatus {
  pending,
  active,
  gateReview,
  completed,
  blocked;

  static MilestonePhaseStatus fromString(String s) {
    switch (s) {
      case 'active': return active;
      case 'gate_review': return gateReview;
      case 'completed': return completed;
      case 'blocked': return blocked;
      default: return pending;
    }
  }

  String get dbValue {
    switch (this) {
      case active: return 'active';
      case gateReview: return 'gate_review';
      case completed: return 'completed';
      case blocked: return 'blocked';
      default: return 'pending';
    }
  }

  String get label {
    switch (this) {
      case active: return 'Active';
      case gateReview: return 'Gate Review';
      case completed: return 'Completed';
      case blocked: return 'Blocked';
      default: return 'Pending';
    }
  }
}

class KeyResult {
  final String id;
  final String phaseId;
  final String projectId;
  final String accountId;
  final String title;
  final KeyResultMetricType metricType;
  final double? targetValue;
  final double currentValue;
  final String? unit;
  final bool autoTrack;
  final bool completed;
  final DateTime? dueDate;
  final DateTime createdAt;
  final DateTime updatedAt;

  const KeyResult({
    required this.id,
    required this.phaseId,
    required this.projectId,
    required this.accountId,
    required this.title,
    required this.metricType,
    this.targetValue,
    required this.currentValue,
    this.unit,
    required this.autoTrack,
    required this.completed,
    this.dueDate,
    required this.createdAt,
    required this.updatedAt,
  });

  factory KeyResult.fromMap(Map<String, dynamic> map) {
    return KeyResult(
      id: map['id'] as String,
      phaseId: map['phase_id'] as String,
      projectId: map['project_id'] as String,
      accountId: map['account_id'] as String,
      title: map['title'] as String,
      metricType: KeyResultMetricType.fromString(map['metric_type'] as String? ?? 'numeric'),
      targetValue: JsonHelpers.toDouble(map['target_value']),
      currentValue: JsonHelpers.toDouble(map['current_value']) ?? 0,
      unit: map['unit'] as String?,
      autoTrack: JsonHelpers.toBool(map['auto_track']) ?? false,
      completed: JsonHelpers.toBool(map['completed']) ?? false,
      dueDate: JsonHelpers.tryParseDate(map['due_date']),
      createdAt: JsonHelpers.tryParseDate(map['created_at']) ?? DateTime.now(),
      updatedAt: JsonHelpers.tryParseDate(map['updated_at']) ?? DateTime.now(),
    );
  }

  double get progressPercent {
    if (completed) return 100;
    if (metricType == KeyResultMetricType.boolean) return completed ? 100 : 0;
    if (targetValue == null || targetValue! <= 0) return 0;
    return ((currentValue / targetValue!) * 100).clamp(0, 100);
  }

  String get displayValue {
    final val = currentValue % 1 == 0 ? currentValue.toInt().toString() : currentValue.toStringAsFixed(1);
    final target = targetValue != null
        ? (targetValue! % 1 == 0 ? targetValue!.toInt().toString() : targetValue!.toStringAsFixed(1))
        : '?';
    final u = unit != null ? ' $unit' : '';
    return '$val/$target$u';
  }
}

enum KeyResultMetricType {
  count,
  percentage,
  boolean,
  numeric;

  static KeyResultMetricType fromString(String s) {
    switch (s) {
      case 'count': return count;
      case 'percentage': return percentage;
      case 'boolean': return boolean;
      default: return numeric;
    }
  }

  String get dbValue => name;
}

class DailyDelta {
  final String id;
  final String projectId;
  final String accountId;
  final String? phaseId;
  final String? keyResultId;
  final double deltaValue;
  final String source;
  final String? sourceId;
  final DateTime recordedAt;

  const DailyDelta({
    required this.id,
    required this.projectId,
    required this.accountId,
    this.phaseId,
    this.keyResultId,
    required this.deltaValue,
    required this.source,
    this.sourceId,
    required this.recordedAt,
  });

  factory DailyDelta.fromMap(Map<String, dynamic> map) {
    return DailyDelta(
      id: map['id'] as String,
      projectId: map['project_id'] as String,
      accountId: map['account_id'] as String,
      phaseId: map['phase_id'] as String?,
      keyResultId: map['key_result_id'] as String?,
      deltaValue: JsonHelpers.toDouble(map['delta_value']) ?? 0,
      source: map['source'] as String? ?? 'manual',
      sourceId: map['source_id'] as String?,
      recordedAt: JsonHelpers.tryParseDate(map['recorded_at']) ?? DateTime.now(),
    );
  }
}

/// Aggregate health metrics computed in-app from phase data
class PhaseHealthMetrics {
  final String projectId;
  final int runwayDays;
  final String? nextGateName;
  final int criticalBlockers;
  final double valueDeliveredPercent;
  final double forecastConfidencePercent;
  final double totalBudgetAllocated;
  final double totalBudgetSpent;

  const PhaseHealthMetrics({
    required this.projectId,
    required this.runwayDays,
    this.nextGateName,
    required this.criticalBlockers,
    required this.valueDeliveredPercent,
    required this.forecastConfidencePercent,
    this.totalBudgetAllocated = 0,
    this.totalBudgetSpent = 0,
  });

  double get budgetUtilizationPercent {
    if (totalBudgetAllocated <= 0) return 0;
    return ((totalBudgetSpent / totalBudgetAllocated) * 100).clamp(0, 200);
  }

  RunwayZone get runwayZone {
    if (runwayDays > 14) return RunwayZone.green;
    if (runwayDays >= 7) return RunwayZone.amber;
    return RunwayZone.red;
  }
}

enum RunwayZone { green, amber, red }
