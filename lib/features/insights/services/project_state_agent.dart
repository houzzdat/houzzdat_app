import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:houzzdat_app/features/insights/models/project_state.dart';

/// Computes real-time project health scores and progress vs plan.
class ProjectStateAgent {
  final _supabase = Supabase.instance.client;

  /// Compute health state for all projects in an account.
  Future<List<ProjectHealthState>> computeAllProjects(String accountId) async {
    final projects = await _supabase
        .from('projects')
        .select('id, name')
        .eq('account_id', accountId);

    final results = <ProjectHealthState>[];
    for (final project in projects) {
      final state = await computeProject(
        project['id'] as String,
        project['name'] as String? ?? 'Unnamed',
        accountId,
      );
      results.add(state);
    }

    // Sort by health score ascending (worst health first)
    results.sort((a, b) => a.healthScore.compareTo(b.healthScore));
    return results;
  }

  /// Compute health state for a single project.
  Future<ProjectHealthState> computeProject(
    String projectId,
    String projectName,
    String accountId,
  ) async {
    // Fetch all data sources in parallel
    final results = await Future.wait([
      _fetchActionItems(projectId, accountId),
      _fetchAttendanceToday(projectId, accountId),
      _fetchVoiceNotesToday(projectId, accountId),
      _fetchWorkerCount(projectId, accountId),
      _fetchPlanAndMilestones(projectId),
      _fetchHealthWeights(accountId),
      _fetchLastActivity(projectId, accountId),
    ]);

    final actions = results[0] as List<Map<String, dynamic>>;
    final attendanceToday = results[1] as int;
    final voiceNotesToday = results[2] as int;
    final totalWorkers = results[3] as int;
    final planData = results[4] as Map<String, dynamic>?;
    final weights = results[5] as Map<String, double>;
    final lastActivityAt = results[6] as DateTime?;

    // Task metrics
    final totalTasks = actions.length;
    final completedTasks = actions.where((a) => a['status'] == 'completed').length;
    final blockedTasks = actions.where((a) =>
        (a['priority'] == 'High' || a['priority'] == 'Critical') &&
        (a['status'] == 'pending' || a['status'] == 'in_progress')).length;
    final overdueTasks = actions.where((a) {
      if (a['due_date'] == null) return false;
      final due = DateTime.tryParse(a['due_date'].toString());
      return due != null && due.isBefore(DateTime.now()) && a['status'] != 'completed';
    }).length;
    final completionRate = totalTasks > 0 ? (completedTasks / totalTasks * 100) : 0.0;

    // Plan/milestone metrics
    final hasPlan = planData != null;
    double plannedProgress = 0;
    double actualProgress = 0;
    final milestones = <MilestoneSnapshot>[];
    DateTime? plannedStart;
    DateTime? plannedEnd;

    if (hasPlan) {
      plannedStart = planData!['start_date'] != null
          ? DateTime.tryParse(planData['start_date'].toString())
          : null;
      plannedEnd = planData['end_date'] != null
          ? DateTime.tryParse(planData['end_date'].toString())
          : null;

      final milestoneRows = planData['milestones'] as List<Map<String, dynamic>>? ?? [];
      for (final m in milestoneRows) {
        final mPlannedEnd = m['planned_end'] != null ? DateTime.tryParse(m['planned_end'].toString()) : null;
        final mActualEnd = m['actual_end'] != null ? DateTime.tryParse(m['actual_end'].toString()) : null;
        final weight = (m['weight_percent'] as num?)?.toDouble() ?? 0;
        final status = m['status'] as String? ?? 'not_started';
        int delayDays = 0;
        if (mPlannedEnd != null && status != 'completed' && DateTime.now().isAfter(mPlannedEnd)) {
          delayDays = DateTime.now().difference(mPlannedEnd).inDays;
        }

        milestones.add(MilestoneSnapshot(
          id: m['id'] as String,
          name: m['name'] as String? ?? '',
          plannedStart: m['planned_start'] != null ? DateTime.tryParse(m['planned_start'].toString()) : null,
          plannedEnd: mPlannedEnd,
          actualStart: m['actual_start'] != null ? DateTime.tryParse(m['actual_start'].toString()) : null,
          actualEnd: mActualEnd,
          weightPercent: weight,
          status: status,
          delayDays: delayDays,
        ));
      }

      plannedProgress = _computePlannedProgress(milestones, DateTime.now());
      actualProgress = _computeActualProgress(milestones);
    }

    final progressVariance = actualProgress - plannedProgress;
    final scheduleStatus = _computeScheduleStatus(progressVariance, hasPlan);

    // Activity metrics
    final daysSinceLastActivity = lastActivityAt != null
        ? DateTime.now().difference(lastActivityAt).inDays
        : 999;

    // Timeline
    final now = DateTime.now();
    final daysRemaining = plannedEnd != null ? plannedEnd.difference(now).inDays : 0;
    final daysElapsed = plannedStart != null ? now.difference(plannedStart).inDays : 0;

    // Top blockers (max 3 high-priority pending/in-progress items)
    final blockerActions = actions
        .where((a) =>
            (a['priority'] == 'High' || a['priority'] == 'Critical') &&
            (a['status'] == 'pending' || a['status'] == 'in_progress'))
        .take(3)
        .map((a) => BlockerItem(
              id: a['id'] as String,
              summary: a['summary'] as String? ?? 'No summary',
              priority: a['priority'] as String? ?? 'Med',
              status: a['status'] as String? ?? 'pending',
              createdAt: DateTime.tryParse(a['created_at']?.toString() ?? '') ?? DateTime.now(),
            ))
        .toList();

    // Compute health score using configurable weights
    final healthScore = _computeHealthScore(
      completionRate: completionRate,
      scheduleAdherence: hasPlan && plannedProgress > 0
          ? (actualProgress / plannedProgress * 100).clamp(0, 100)
          : 100,
      blockerCount: blockedTasks,
      totalTasks: totalTasks,
      daysSinceLastActivity: daysSinceLastActivity,
      attendanceRatio: totalWorkers > 0 ? attendanceToday / totalWorkers : 1.0,
      overdueCount: overdueTasks,
      weights: weights,
      hasPlan: hasPlan,
    );

    final healthLabel = healthScore >= 70
        ? 'On Track'
        : healthScore >= 40
            ? 'At Risk'
            : 'Critical';
    final healthColor = healthScore >= 70
        ? const Color(0xFF2E7D32)
        : healthScore >= 40
            ? const Color(0xFFEF6C00)
            : const Color(0xFFD32F2F);

    return ProjectHealthState(
      projectId: projectId,
      projectName: projectName,
      healthScore: healthScore,
      healthLabel: healthLabel,
      healthColor: healthColor,
      totalTasks: totalTasks,
      completedTasks: completedTasks,
      blockedTasks: blockedTasks,
      overdueTasks: overdueTasks,
      completionRate: completionRate,
      hasPlan: hasPlan,
      plannedProgress: plannedProgress,
      actualProgress: actualProgress,
      progressVariance: progressVariance,
      scheduleStatus: scheduleStatus,
      milestonesTotal: milestones.length,
      milestonesCompleted: milestones.where((m) => m.status == 'completed').length,
      milestonesDelayed: milestones.where((m) => m.delayDays > 0).length,
      milestones: milestones,
      voiceNotesToday: voiceNotesToday,
      workersOnSiteToday: attendanceToday,
      totalWorkers: totalWorkers,
      lastActivityAt: lastActivityAt,
      daysSinceLastActivity: daysSinceLastActivity,
      plannedStartDate: plannedStart,
      plannedEndDate: plannedEnd,
      daysRemaining: daysRemaining,
      daysElapsed: daysElapsed,
      trend: 'stable', // TODO: compute from historical snapshots when available
      trendDelta: 0,
      topBlockers: blockerActions,
    );
  }

  // ─── Data Fetchers ──────────────────────────────────────────

  Future<List<Map<String, dynamic>>> _fetchActionItems(String projectId, String accountId) async {
    return await _supabase
        .from('action_items')
        .select('id, summary, status, priority, category, due_date, created_at')
        .eq('project_id', projectId)
        .eq('account_id', accountId);
  }

  Future<int> _fetchAttendanceToday(String projectId, String accountId) async {
    final today = DateTime.now().toIso8601String().split('T').first;
    final result = await _supabase
        .from('attendance')
        .select('id')
        .eq('project_id', projectId)
        .gte('check_in_at', '${today}T00:00:00')
        .lte('check_in_at', '${today}T23:59:59');
    return (result as List).length;
  }

  Future<int> _fetchVoiceNotesToday(String projectId, String accountId) async {
    final today = DateTime.now().toIso8601String().split('T').first;
    final result = await _supabase
        .from('voice_notes')
        .select('id')
        .eq('project_id', projectId)
        .gte('created_at', '${today}T00:00:00')
        .lte('created_at', '${today}T23:59:59');
    return (result as List).length;
  }

  Future<int> _fetchWorkerCount(String projectId, String accountId) async {
    final result = await _supabase
        .from('users')
        .select('id')
        .eq('current_project_id', projectId)
        .eq('role', 'worker');
    return (result as List).length;
  }

  Future<Map<String, dynamic>?> _fetchPlanAndMilestones(String projectId) async {
    final plan = await _supabase
        .from('project_plans')
        .select()
        .eq('project_id', projectId)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();

    if (plan == null) return null;

    final milestones = await _supabase
        .from('project_milestones')
        .select()
        .eq('plan_id', plan['id'])
        .order('sort_order');

    return {
      ...plan,
      'milestones': milestones,
    };
  }

  Future<Map<String, double>> _fetchHealthWeights(String accountId) async {
    // Try account-specific weights first, then fall back to global
    var weights = await _supabase
        .from('health_score_weights')
        .select()
        .eq('account_id', accountId)
        .maybeSingle();

    weights ??= await _supabase
        .from('health_score_weights')
        .select()
        .isFilter('account_id', null)
        .maybeSingle();

    if (weights == null) {
      // Return defaults
      return {
        'task_completion': 20,
        'schedule_adherence': 25,
        'blocker_severity': 20,
        'activity_recency': 15,
        'worker_attendance': 10,
        'overdue_penalty': 10,
      };
    }

    return {
      'task_completion': (weights['task_completion_weight'] as num?)?.toDouble() ?? 20,
      'schedule_adherence': (weights['schedule_adherence_weight'] as num?)?.toDouble() ?? 25,
      'blocker_severity': (weights['blocker_severity_weight'] as num?)?.toDouble() ?? 20,
      'activity_recency': (weights['activity_recency_weight'] as num?)?.toDouble() ?? 15,
      'worker_attendance': (weights['worker_attendance_weight'] as num?)?.toDouble() ?? 10,
      'overdue_penalty': (weights['overdue_penalty_weight'] as num?)?.toDouble() ?? 10,
    };
  }

  Future<DateTime?> _fetchLastActivity(String projectId, String accountId) async {
    final result = await _supabase
        .from('voice_notes')
        .select('created_at')
        .eq('project_id', projectId)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();
    if (result != null && result['created_at'] != null) {
      return DateTime.tryParse(result['created_at'].toString());
    }
    return null;
  }

  // ─── Score Computation ──────────────────────────────────────

  /// Compute where we SHOULD be based on milestones due by today.
  double _computePlannedProgress(List<MilestoneSnapshot> milestones, DateTime today) {
    if (milestones.isEmpty) return 0;
    double totalWeight = milestones.fold(0, (sum, m) => sum + m.weightPercent);
    if (totalWeight == 0) totalWeight = 100; // Equal weight if not specified

    double progress = 0;
    for (final m in milestones) {
      final weight = totalWeight > 0 ? m.weightPercent / totalWeight : 1.0 / milestones.length;
      if (m.plannedEnd != null && today.isAfter(m.plannedEnd!)) {
        // This milestone should be done by now
        progress += weight * 100;
      } else if (m.plannedStart != null && m.plannedEnd != null && today.isAfter(m.plannedStart!)) {
        // Partially through this milestone
        final totalDays = m.plannedEnd!.difference(m.plannedStart!).inDays;
        final elapsed = today.difference(m.plannedStart!).inDays;
        if (totalDays > 0) {
          progress += weight * (elapsed / totalDays * 100);
        }
      }
    }
    return progress.clamp(0, 100);
  }

  /// Compute where we ARE based on completed milestones.
  double _computeActualProgress(List<MilestoneSnapshot> milestones) {
    if (milestones.isEmpty) return 0;
    double totalWeight = milestones.fold(0, (sum, m) => sum + m.weightPercent);
    if (totalWeight == 0) totalWeight = 100;

    double progress = 0;
    for (final m in milestones) {
      final weight = totalWeight > 0 ? m.weightPercent / totalWeight : 1.0 / milestones.length;
      if (m.status == 'completed') {
        progress += weight * 100;
      } else if (m.status == 'in_progress') {
        // Partial credit: 50% for in-progress
        progress += weight * 50;
      }
    }
    return progress.clamp(0, 100);
  }

  String _computeScheduleStatus(double variance, bool hasPlan) {
    if (!hasPlan) return 'on_track';
    if (variance >= 5) return 'ahead';
    if (variance >= -5) return 'on_track';
    if (variance >= -20) return 'behind';
    return 'critical';
  }

  int _computeHealthScore({
    required double completionRate,
    required double scheduleAdherence,
    required int blockerCount,
    required int totalTasks,
    required int daysSinceLastActivity,
    required double attendanceRatio,
    required int overdueCount,
    required Map<String, double> weights,
    required bool hasPlan,
  }) {
    double score = 0;
    double totalWeight = 0;

    // Task completion
    final w1 = weights['task_completion'] ?? 20;
    score += completionRate / 100 * w1;
    totalWeight += w1;

    // Schedule adherence
    final w2 = weights['schedule_adherence'] ?? 25;
    if (hasPlan) {
      score += scheduleAdherence / 100 * w2;
      totalWeight += w2;
    } else {
      // Redistribute to task completion and activity
      score += completionRate / 100 * (w2 / 2);
      totalWeight += w2;
      // Give the other half as activity bonus
      final activityScore = daysSinceLastActivity == 0
          ? 1.0
          : daysSinceLastActivity <= 1
              ? 0.8
              : daysSinceLastActivity <= 3
                  ? 0.5
                  : 0.2;
      score += activityScore * (w2 / 2);
    }

    // Blocker severity (inverse: fewer blockers = higher score)
    final w3 = weights['blocker_severity'] ?? 20;
    final blockerRatio = totalTasks > 0 ? 1 - (blockerCount / totalTasks).clamp(0, 1) : 1.0;
    score += blockerRatio * w3;
    totalWeight += w3;

    // Activity recency
    final w4 = weights['activity_recency'] ?? 15;
    final activityScore = daysSinceLastActivity == 0
        ? 1.0
        : daysSinceLastActivity <= 1
            ? 0.8
            : daysSinceLastActivity <= 3
                ? 0.5
                : daysSinceLastActivity <= 7
                    ? 0.3
                    : 0.1;
    score += activityScore * w4;
    totalWeight += w4;

    // Worker attendance
    final w5 = weights['worker_attendance'] ?? 10;
    score += attendanceRatio.clamp(0, 1) * w5;
    totalWeight += w5;

    // Overdue penalty (inverse)
    final w6 = weights['overdue_penalty'] ?? 10;
    final overdueRatio = totalTasks > 0 ? 1 - (overdueCount / totalTasks).clamp(0, 1) : 1.0;
    score += overdueRatio * w6;
    totalWeight += w6;

    return totalWeight > 0 ? (score / totalWeight * 100).round().clamp(0, 100) : 50;
  }
}
