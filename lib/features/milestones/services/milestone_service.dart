import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:houzzdat_app/models/models.dart';

class MilestoneService {
  final _supabase = Supabase.instance.client;

  // ---------------------------------------------------------------------------
  // PHASE CRUD
  // ---------------------------------------------------------------------------

  /// Fetch all phases for a project, ordered by phase_order, with KRs joined
  Future<List<MilestonePhase>> getPhasesForProject(String projectId) async {
    try {
      final data = await _supabase
          .from('milestone_phases')
          .select('*, key_results(*)')
          .eq('project_id', projectId)
          .order('phase_order', ascending: true);

      return (data as List)
          .map((row) => MilestonePhase.fromMap(row as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('[MilestoneService] getPhasesForProject error: $e');
      return [];
    }
  }

  /// Compute health metrics for a project from its phases
  Future<PhaseHealthMetrics> getPhaseHealth(String projectId, String accountId) async {
    final phases = await getPhasesForProject(projectId);

    if (phases.isEmpty) {
      return PhaseHealthMetrics(
        projectId: projectId,
        runwayDays: 0,
        nextGateName: null,
        criticalBlockers: 0,
        valueDeliveredPercent: 0,
        forecastConfidencePercent: 0,
      );
    }

    // RUNWAY: days to next active/pending phase end date
    MilestonePhase? nextPhase;
    for (final p in phases) {
      if (p.status == MilestonePhaseStatus.active ||
          p.status == MilestonePhaseStatus.gateReview) {
        nextPhase = p;
        break;
      }
    }
    final runwayDays = nextPhase?.daysRemaining ?? 0;

    // CRITICAL BLOCKERS: blocked phases + overdue active phases
    final blockers = phases.where((p) =>
        p.status == MilestonePhaseStatus.blocked ||
        (p.status == MilestonePhaseStatus.active && p.daysRemaining < 0)).length;

    // VALUE DELIVERED: weighted average KR completion across all phases
    final allKRs = phases.expand((p) => p.keyResults).toList();
    final valuePercent = allKRs.isEmpty
        ? 0.0
        : allKRs.fold<double>(0, (sum, kr) => sum + kr.progressPercent) / allKRs.length;

    // FORECAST CONFIDENCE: simple heuristic
    // - Start at 100%, deduct for blockers, overdue phases, low KR completion
    double confidence = 100;
    if (blockers > 0) confidence -= (blockers * 10).clamp(0, 40);
    if (valuePercent < 30) confidence -= 20;
    if (runwayDays < 7 && runwayDays >= 0) confidence -= 15;
    if (runwayDays < 0) confidence -= 30;
    confidence = confidence.clamp(0, 100);

    // BUDGET AGGREGATES
    final totalAllocated = phases.fold<double>(
        0, (sum, p) => sum + (p.budgetAllocated ?? 0));
    final totalSpent = phases.fold<double>(
        0, (sum, p) => sum + p.budgetSpent);

    return PhaseHealthMetrics(
      projectId: projectId,
      runwayDays: runwayDays.abs(),
      nextGateName: nextPhase?.name,
      criticalBlockers: blockers,
      valueDeliveredPercent: valuePercent,
      forecastConfidencePercent: confidence,
      totalBudgetAllocated: totalAllocated,
      totalBudgetSpent: totalSpent,
    );
  }

  /// Update phase status
  Future<void> updatePhaseStatus(String phaseId, MilestonePhaseStatus status) async {
    await _supabase
        .from('milestone_phases')
        .update({'status': status.dbValue})
        .eq('id', phaseId);
  }

  /// Update a phase's editable fields
  Future<void> updatePhase({
    required String phaseId,
    String? name,
    String? description,
    DateTime? plannedStart,
    DateTime? plannedEnd,
    double? budgetAllocated,
  }) async {
    final updates = <String, dynamic>{};
    if (name != null) updates['name'] = name;
    if (description != null) updates['description'] = description;
    if (plannedStart != null) updates['planned_start'] = plannedStart.toIso8601String().split('T')[0];
    if (plannedEnd != null) updates['planned_end'] = plannedEnd.toIso8601String().split('T')[0];
    if (budgetAllocated != null) updates['budget_allocated'] = budgetAllocated;
    if (updates.isEmpty) return;
    await _supabase.from('milestone_phases').update(updates).eq('id', phaseId);
  }

  /// Delete a phase (cascades to key_results via DB constraint)
  Future<void> deletePhase(String phaseId) async {
    await _supabase.from('milestone_phases').delete().eq('id', phaseId);
  }

  /// Add a new key result to a phase
  Future<void> addKeyResult({
    required String phaseId,
    required String projectId,
    required String accountId,
    required String title,
    required String metricType,
    double? targetValue,
    String? unit,
  }) async {
    await _supabase.from('key_results').insert({
      'phase_id': phaseId,
      'project_id': projectId,
      'account_id': accountId,
      'title': title,
      'metric_type': metricType,
      'target_value': targetValue ?? 1,
      'current_value': 0,
      'unit': unit,
      'auto_track': false,
      'completed': false,
    });
  }

  /// Update a key result's definition (not its progress value)
  Future<void> updateKeyResult({
    required String keyResultId,
    String? title,
    String? metricType,
    double? targetValue,
    String? unit,
  }) async {
    final updates = <String, dynamic>{};
    if (title != null) updates['title'] = title;
    if (metricType != null) updates['metric_type'] = metricType;
    if (targetValue != null) updates['target_value'] = targetValue;
    if (unit != null) updates['unit'] = unit;
    if (updates.isEmpty) return;
    await _supabase.from('key_results').update(updates).eq('id', keyResultId);
  }

  /// Delete a key result
  Future<void> deleteKeyResult(String keyResultId) async {
    await _supabase.from('key_results').delete().eq('id', keyResultId);
  }

  // ---------------------------------------------------------------------------
  // AI PLAN GENERATION
  // ---------------------------------------------------------------------------

  /// Call the generate-milestone-plan edge function to create a plan from 3 questions
  Future<List<MilestonePhase>> generateMilestonePlan({
    required String projectId,
    required String accountId,
    required String q1StartingPoint,
    required String q2WorkTypes,
    required String q3Timeline,
    String? siteType,
    double? areaSqft,
    int? numberOfFloors,
    double? estimatedBudgetLakhs,
    String language = 'en',
  }) async {
    try {
      final body = <String, dynamic>{
        'project_id': projectId,
        'account_id': accountId,
        'q1': q1StartingPoint,
        'q2': q2WorkTypes,
        'q3': q3Timeline,
        'language': language,
      };
      if (siteType != null) body['site_type'] = siteType;
      if (areaSqft != null) body['area_sqft'] = areaSqft;
      if (numberOfFloors != null) body['number_of_floors'] = numberOfFloors;
      if (estimatedBudgetLakhs != null) body['estimated_budget_lakhs'] = estimatedBudgetLakhs;

      final response = await _supabase.functions.invoke(
        'generate-milestone-plan',
        body: body,
      );

      if (response.status != 200) {
        throw Exception('Plan generation failed: ${response.data}');
      }

      // Fetch the newly created phases
      return getPhasesForProject(projectId);
    } catch (e) {
      debugPrint('[MilestoneService] generateMilestonePlan error: $e');
      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // KEY RESULTS
  // ---------------------------------------------------------------------------

  /// Manually update a key result's current value
  Future<void> updateKeyResultValue({
    required String keyResultId,
    required double newValue,
    required String projectId,
    required String accountId,
    required String phaseId,
  }) async {
    final previousData = await _supabase
        .from('key_results')
        .select('current_value, target_value')
        .eq('id', keyResultId)
        .maybeSingle();

    final previousValue = (previousData?['current_value'] as num?)?.toDouble() ?? 0;
    final targetValue = (previousData?['target_value'] as num?)?.toDouble();
    final completed = targetValue != null && newValue >= targetValue;

    await _supabase.from('key_results').update({
      'current_value': newValue,
      'completed': completed,
    }).eq('id', keyResultId);

    // Log the delta
    final delta = newValue - previousValue;
    if (delta != 0) {
      await _supabase.from('daily_deltas').insert({
        'project_id': projectId,
        'account_id': accountId,
        'phase_id': phaseId,
        'key_result_id': keyResultId,
        'delta_value': delta,
        'source': 'manual',
      });
    }
  }

  // ---------------------------------------------------------------------------
  // MODULE LIBRARY
  // ---------------------------------------------------------------------------

  Future<List<MilestoneModule>> getModules({String? accountId}) async {
    try {
      // Filters must be applied before .order() (which returns PostgrestTransformBuilder).
      // Return global templates (account_id IS NULL) + account-specific ones.
      final List<Map<String, dynamic>> data;
      if (accountId != null) {
        data = await _supabase
            .from('milestone_modules')
            .select()
            .or('account_id.is.null,account_id.eq.$accountId')
            .order('sequence_order', ascending: true);
      } else {
        data = await _supabase
            .from('milestone_modules')
            .select()
            .isFilter('account_id', null)
            .order('sequence_order', ascending: true);
      }

      return data
          .map((row) => MilestoneModule.fromMap(row))
          .toList();
    } catch (e) {
      debugPrint('[MilestoneService] getModules error: $e');
      return [];
    }
  }

  /// Check if a project already has milestones set up
  Future<bool> hasMilestonePlan(String projectId) async {
    try {
      final count = await _supabase
          .from('milestone_phases')
          .select()
          .eq('project_id', projectId)
          .count(CountOption.exact);
      return (count.count ?? 0) > 0;
    } catch (e) {
      return false;
    }
  }
}
