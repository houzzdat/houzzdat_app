import 'package:flutter/material.dart';

/// Snapshot of a single milestone's progress.
class MilestoneSnapshot {
  final String id;
  final String name;
  final DateTime? plannedStart;
  final DateTime? plannedEnd;
  final DateTime? actualStart;
  final DateTime? actualEnd;
  final double weightPercent;
  final String status; // not_started, in_progress, completed, delayed
  final int delayDays;

  const MilestoneSnapshot({
    required this.id,
    required this.name,
    this.plannedStart,
    this.plannedEnd,
    this.actualStart,
    this.actualEnd,
    this.weightPercent = 0,
    this.status = 'not_started',
    this.delayDays = 0,
  });
}

/// A high-priority blocker item.
class BlockerItem {
  final String id;
  final String summary;
  final String priority;
  final String status;
  final DateTime createdAt;

  const BlockerItem({
    required this.id,
    required this.summary,
    required this.priority,
    required this.status,
    required this.createdAt,
  });
}

/// Complete health state for a single project.
class ProjectHealthState {
  final String projectId;
  final String projectName;
  final int healthScore;
  final String healthLabel;
  final Color healthColor;

  // Task metrics
  final int totalTasks;
  final int completedTasks;
  final int blockedTasks;
  final int overdueTasks;
  final double completionRate;

  // Progress vs Plan
  final bool hasPlan;
  final double plannedProgress;
  final double actualProgress;
  final double progressVariance;
  final String scheduleStatus; // ahead, on_track, behind, critical
  final int milestonesTotal;
  final int milestonesCompleted;
  final int milestonesDelayed;
  final List<MilestoneSnapshot> milestones;

  // Activity metrics
  final int voiceNotesToday;
  final int workersOnSiteToday;
  final int totalWorkers;
  final DateTime? lastActivityAt;
  final int daysSinceLastActivity;

  // Timeline
  final DateTime? plannedStartDate;
  final DateTime? plannedEndDate;
  final int daysRemaining;
  final int daysElapsed;

  // Trend
  final String trend; // improving, stable, declining
  final int trendDelta;

  // Blockers
  final List<BlockerItem> topBlockers;

  const ProjectHealthState({
    required this.projectId,
    required this.projectName,
    required this.healthScore,
    required this.healthLabel,
    required this.healthColor,
    this.totalTasks = 0,
    this.completedTasks = 0,
    this.blockedTasks = 0,
    this.overdueTasks = 0,
    this.completionRate = 0,
    this.hasPlan = false,
    this.plannedProgress = 0,
    this.actualProgress = 0,
    this.progressVariance = 0,
    this.scheduleStatus = 'on_track',
    this.milestonesTotal = 0,
    this.milestonesCompleted = 0,
    this.milestonesDelayed = 0,
    this.milestones = const [],
    this.voiceNotesToday = 0,
    this.workersOnSiteToday = 0,
    this.totalWorkers = 0,
    this.lastActivityAt,
    this.daysSinceLastActivity = 0,
    this.plannedStartDate,
    this.plannedEndDate,
    this.daysRemaining = 0,
    this.daysElapsed = 0,
    this.trend = 'stable',
    this.trendDelta = 0,
    this.topBlockers = const [],
  });
}
