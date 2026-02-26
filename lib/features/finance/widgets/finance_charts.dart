import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:houzzdat_app/core/theme/app_theme.dart';

/// UX-audit PP-03: Data visualization widgets for owner financial dashboard.
/// Provides pie charts for status distribution and bar charts for monthly cash flow.

// ─── Fund Request Status Pie Chart ───────────────────────────────────

class FundRequestStatusChart extends StatelessWidget {
  final List<Map<String, dynamic>> fundRequests;

  const FundRequestStatusChart({super.key, required this.fundRequests});

  @override
  Widget build(BuildContext context) {
    final pending = fundRequests.where((r) => r['status'] == 'pending').length;
    final approved = fundRequests.where((r) => r['status'] == 'approved').length;
    final denied = fundRequests.where((r) => r['status'] == 'denied').length;
    final partial = fundRequests.where((r) => r['status'] == 'partially_approved').length;
    final total = pending + approved + denied + partial;

    if (total == 0) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingM,
        vertical: AppTheme.spacingS,
      ),
      padding: const EdgeInsets.all(AppTheme.spacingM),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusL),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Fund Request Status',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 160,
            child: Row(
              children: [
                // Pie chart
                Expanded(
                  flex: 3,
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 28,
                      sections: [
                        if (pending > 0)
                          _pieSection(pending.toDouble(), AppTheme.warningOrange, 'Pending'),
                        if (approved > 0)
                          _pieSection(approved.toDouble(), AppTheme.successGreen, 'Approved'),
                        if (denied > 0)
                          _pieSection(denied.toDouble(), AppTheme.errorRed, 'Denied'),
                        if (partial > 0)
                          _pieSection(partial.toDouble(), AppTheme.infoBlue, 'Partial'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // Legend
                Expanded(
                  flex: 2,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (pending > 0) _legendItem('Pending', pending, AppTheme.warningOrange),
                      if (approved > 0) _legendItem('Approved', approved, AppTheme.successGreen),
                      if (denied > 0) _legendItem('Denied', denied, AppTheme.errorRed),
                      if (partial > 0) _legendItem('Partial', partial, AppTheme.infoBlue),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  PieChartSectionData _pieSection(double value, Color color, String title) {
    return PieChartSectionData(
      value: value,
      color: color,
      radius: 40,
      title: '${value.toInt()}',
      titleStyle: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
    );
  }

  Widget _legendItem(String label, int count, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              '$label ($count)',
              style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Monthly Cash Flow Bar Chart ──────────────────────────────────────

class MonthlyCashFlowChart extends StatelessWidget {
  final List<Map<String, dynamic>> payments;
  final List<Map<String, dynamic>> fundRequests;

  static final _compactFormat =
      NumberFormat.compactCurrency(locale: 'en_IN', symbol: '\u20B9', decimalDigits: 0);

  const MonthlyCashFlowChart({
    super.key,
    required this.payments,
    required this.fundRequests,
  });

  @override
  Widget build(BuildContext context) {
    final monthlyData = _aggregateByMonth();
    if (monthlyData.isEmpty) return const SizedBox.shrink();

    // Limit to last 6 months
    final displayData = monthlyData.length > 6
        ? monthlyData.sublist(monthlyData.length - 6)
        : monthlyData;

    final maxVal = displayData.fold<double>(0, (max, m) {
      final received = m['received'] as double;
      final requested = m['requested'] as double;
      final maxInMonth = received > requested ? received : requested;
      return maxInMonth > max ? maxInMonth : max;
    });

    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingM,
        vertical: AppTheme.spacingS,
      ),
      padding: const EdgeInsets.all(AppTheme.spacingM),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusL),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Monthly Cash Flow',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              // Legend
              _barLegend('Received', AppTheme.successGreen),
              const SizedBox(width: 12),
              _barLegend('Requested', AppTheme.infoBlue),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 180,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxVal * 1.15,
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    tooltipRoundedRadius: 6,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final label = rodIndex == 0 ? 'Received' : 'Requested';
                      return BarTooltipItem(
                        '$label\n${_compactFormat.format(rod.toY)}',
                        const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        if (idx < 0 || idx >= displayData.length) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            displayData[idx]['label'] as String,
                            style: const TextStyle(
                              fontSize: 10,
                              color: AppTheme.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        );
                      },
                      reservedSize: 28,
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 50,
                      getTitlesWidget: (value, meta) {
                        if (value == 0) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: Text(
                            _compactFormat.format(value),
                            style: const TextStyle(
                              fontSize: 9,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: maxVal > 0 ? maxVal / 4 : 1,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: Colors.grey.withValues(alpha: 0.15),
                    strokeWidth: 1,
                  ),
                ),
                barGroups: List.generate(displayData.length, (i) {
                  final month = displayData[i];
                  return BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: month['received'] as double,
                        color: AppTheme.successGreen,
                        width: 12,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                      ),
                      BarChartRodData(
                        toY: month['requested'] as double,
                        color: AppTheme.infoBlue,
                        width: 12,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _barLegend(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
      ],
    );
  }

  /// Aggregate payments and fund requests into monthly buckets.
  List<Map<String, dynamic>> _aggregateByMonth() {
    final monthMap = <String, Map<String, double>>{};
    final monthFormat = DateFormat('yyyy-MM');
    final labelFormat = DateFormat('MMM');

    for (final p in payments) {
      final dateStr = p['received_date']?.toString();
      if (dateStr == null) continue;
      try {
        final dt = DateTime.parse(dateStr);
        final key = monthFormat.format(dt);
        monthMap.putIfAbsent(key, () => {'received': 0, 'requested': 0});
        monthMap[key]!['received'] = (monthMap[key]!['received'] ?? 0) +
            ((p['amount'] as num?)?.toDouble() ?? 0);
      } catch (_) {}
    }

    for (final r in fundRequests) {
      final dateStr = r['created_at']?.toString();
      if (dateStr == null) continue;
      try {
        final dt = DateTime.parse(dateStr);
        final key = monthFormat.format(dt);
        monthMap.putIfAbsent(key, () => {'received': 0, 'requested': 0});
        monthMap[key]!['requested'] = (monthMap[key]!['requested'] ?? 0) +
            ((r['amount'] as num?)?.toDouble() ?? 0);
      } catch (_) {}
    }

    // Sort by month key and add labels
    final sorted = monthMap.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return sorted.map((entry) {
      final dt = DateTime.parse('${entry.key}-01');
      return {
        'key': entry.key,
        'label': labelFormat.format(dt),
        'received': entry.value['received'] ?? 0.0,
        'requested': entry.value['requested'] ?? 0.0,
      };
    }).toList();
  }
}

// ─── Project Action Items Progress Chart ──────────────────────────────

class ProjectProgressChart extends StatelessWidget {
  final Map<String, Map<String, int>> projectStats; // projectId → {pending, inProgress, completed}
  final Map<String, String> projectNames; // projectId → name

  const ProjectProgressChart({
    super.key,
    required this.projectStats,
    required this.projectNames,
  });

  @override
  Widget build(BuildContext context) {
    if (projectStats.isEmpty) return const SizedBox.shrink();

    // Sort by total actions descending, take top 8
    final entries = projectStats.entries.toList()
      ..sort((a, b) {
        final aTotal = (a.value['pending'] ?? 0) + (a.value['inProgress'] ?? 0) + (a.value['completed'] ?? 0);
        final bTotal = (b.value['pending'] ?? 0) + (b.value['inProgress'] ?? 0) + (b.value['completed'] ?? 0);
        return bTotal.compareTo(aTotal);
      });
    final displayEntries = entries.take(8).toList();

    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingM,
        vertical: AppTheme.spacingS,
      ),
      padding: const EdgeInsets.all(AppTheme.spacingM),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusL),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Project Progress',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              _legendDot('Open', AppTheme.warningOrange),
              const SizedBox(width: 8),
              _legendDot('Active', AppTheme.infoBlue),
              const SizedBox(width: 8),
              _legendDot('Done', AppTheme.successGreen),
            ],
          ),
          const SizedBox(height: 12),
          ...displayEntries.map((entry) {
            final name = projectNames[entry.key] ?? 'Unknown';
            final pending = entry.value['pending'] ?? 0;
            final inProgress = entry.value['inProgress'] ?? 0;
            final completed = entry.value['completed'] ?? 0;
            final total = pending + inProgress + completed;

            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        '$completed/$total',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.textSecondary.withValues(alpha: 0.7),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: SizedBox(
                      height: 10,
                      child: total > 0
                          ? Row(
                              children: [
                                if (completed > 0)
                                  Flexible(
                                    flex: completed,
                                    child: Container(color: AppTheme.successGreen),
                                  ),
                                if (inProgress > 0)
                                  Flexible(
                                    flex: inProgress,
                                    child: Container(color: AppTheme.infoBlue),
                                  ),
                                if (pending > 0)
                                  Flexible(
                                    flex: pending,
                                    child: Container(color: AppTheme.warningOrange.withValues(alpha: 0.5)),
                                  ),
                              ],
                            )
                          : Container(color: Colors.grey.withValues(alpha: 0.2)),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _legendDot(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 3),
        Text(label, style: const TextStyle(fontSize: 9, color: AppTheme.textSecondary)),
      ],
    );
  }
}

// ─── PP-07: Project Expenditure Breakdown Chart ─────────────────────────

/// Shows expenditure (fund requests) broken down by project as a horizontal
/// stacked bar chart with month-over-month delta indicators.
class ProjectExpenditureChart extends StatelessWidget {
  final List<Map<String, dynamic>> fundRequests;
  final List<Map<String, dynamic>> projects;

  static final _compactFormat =
      NumberFormat.compactCurrency(locale: 'en_IN', symbol: '\u20B9', decimalDigits: 0);

  const ProjectExpenditureChart({
    super.key,
    required this.fundRequests,
    required this.projects,
  });

  @override
  Widget build(BuildContext context) {
    final projectTotals = _aggregateByProject();
    if (projectTotals.isEmpty) return const SizedBox.shrink();

    // Sort by amount descending, take top 6
    projectTotals.sort((a, b) => (b['total'] as double).compareTo(a['total'] as double));
    final display = projectTotals.take(6).toList();

    final maxVal = display.fold<double>(0, (max, p) {
      final total = p['total'] as double;
      return total > max ? total : max;
    });

    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingM,
        vertical: AppTheme.spacingS,
      ),
      padding: const EdgeInsets.all(AppTheme.spacingM),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusL),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Expenditure by Project',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Based on fund requests',
            style: TextStyle(
              fontSize: 11,
              color: AppTheme.textSecondary.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 16),
          ...display.map((proj) {
            final name = proj['name'] as String;
            final total = proj['total'] as double;
            final approved = proj['approved'] as double;
            final pending = proj['pending'] as double;
            final fraction = maxVal > 0 ? total / maxVal : 0.0;
            final approvedFraction = total > 0 ? approved / total : 0.0;
            final delta = proj['delta'] as double;

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        _compactFormat.format(total),
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      if (delta != 0) ...[
                        const SizedBox(width: 6),
                        Icon(
                          delta > 0 ? Icons.trending_up : Icons.trending_down,
                          size: 14,
                          color: delta > 0 ? AppTheme.errorRed : AppTheme.successGreen,
                        ),
                        Text(
                          '${delta > 0 ? '+' : ''}${delta.round()}%',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: delta > 0 ? AppTheme.errorRed : AppTheme.successGreen,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: SizedBox(
                      height: 10,
                      child: Row(
                        children: [
                          Flexible(
                            flex: (fraction * 100).round().clamp(1, 100),
                            child: Row(
                              children: [
                                if (approved > 0)
                                  Flexible(
                                    flex: (approvedFraction * 100).round(),
                                    child: Container(color: AppTheme.successGreen),
                                  ),
                                if (pending > 0)
                                  Flexible(
                                    flex: ((1 - approvedFraction) * 100).round().clamp(1, 100),
                                    child: Container(color: AppTheme.warningOrange.withValues(alpha: 0.5)),
                                  ),
                              ],
                            ),
                          ),
                          Flexible(
                            flex: ((1 - fraction) * 100).round().clamp(0, 100),
                            child: Container(color: Colors.grey.withValues(alpha: 0.1)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
          // Legend
          Row(
            children: [
              _legendItem2('Approved', AppTheme.successGreen),
              const SizedBox(width: 12),
              _legendItem2('Pending', AppTheme.warningOrange.withValues(alpha: 0.5)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _legendItem2(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
      ],
    );
  }

  List<Map<String, dynamic>> _aggregateByProject() {
    final projectMap = <String, Map<String, double>>{};
    final projectNames = <String, String>{};
    final now = DateTime.now();
    final thisMonth = DateTime(now.year, now.month, 1);
    final lastMonth = DateTime(now.year, now.month - 1, 1);

    // Build project name lookup
    for (final p in projects) {
      final id = p['id']?.toString() ?? '';
      projectNames[id] = p['name']?.toString() ?? 'Unknown';
    }

    for (final r in fundRequests) {
      final pid = r['project_id']?.toString() ?? '';
      final amount = (r['amount'] as num?)?.toDouble() ?? 0;
      final status = r['status']?.toString() ?? '';
      final dateStr = r['created_at']?.toString();

      projectMap.putIfAbsent(pid, () => {
        'total': 0, 'approved': 0, 'pending': 0,
        'this_month': 0, 'last_month': 0,
      });
      projectMap[pid]!['total'] = (projectMap[pid]!['total'] ?? 0) + amount;
      if (status == 'approved') {
        projectMap[pid]!['approved'] = (projectMap[pid]!['approved'] ?? 0) + amount;
      } else if (status == 'pending') {
        projectMap[pid]!['pending'] = (projectMap[pid]!['pending'] ?? 0) + amount;
      }

      // Track this month vs last month for delta
      if (dateStr != null) {
        try {
          final dt = DateTime.parse(dateStr);
          if (dt.year == thisMonth.year && dt.month == thisMonth.month) {
            projectMap[pid]!['this_month'] = (projectMap[pid]!['this_month'] ?? 0) + amount;
          } else if (dt.year == lastMonth.year && dt.month == lastMonth.month) {
            projectMap[pid]!['last_month'] = (projectMap[pid]!['last_month'] ?? 0) + amount;
          }
        } catch (_) {}
      }
    }

    return projectMap.entries.map((entry) {
      final thisM = entry.value['this_month'] ?? 0;
      final lastM = entry.value['last_month'] ?? 0;
      final delta = lastM > 0 ? ((thisM - lastM) / lastM * 100) : 0.0;

      return {
        'id': entry.key,
        'name': projectNames[entry.key] ?? 'Unknown',
        'total': entry.value['total'] ?? 0.0,
        'approved': entry.value['approved'] ?? 0.0,
        'pending': entry.value['pending'] ?? 0.0,
        'delta': delta,
      };
    }).toList();
  }
}

// ─── Approval Distribution Pie Chart ──────────────────────────────────

class ApprovalDistributionChart extends StatelessWidget {
  final List<Map<String, dynamic>> approvals;

  const ApprovalDistributionChart({super.key, required this.approvals});

  @override
  Widget build(BuildContext context) {
    final pending = approvals.where((a) => a['status'] == 'pending').length;
    final approved = approvals.where((a) => a['status'] == 'approved').length;
    final denied = approvals.where((a) => a['status'] == 'denied').length;
    final total = pending + approved + denied;

    if (total == 0) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingM,
        vertical: AppTheme.spacingS,
      ),
      padding: const EdgeInsets.all(AppTheme.spacingM),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusL),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Approval Overview',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 140,
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 24,
                      sections: [
                        if (pending > 0)
                          PieChartSectionData(
                            value: pending.toDouble(),
                            color: AppTheme.warningOrange,
                            radius: 36,
                            title: '${(pending / total * 100).round()}%',
                            titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        if (approved > 0)
                          PieChartSectionData(
                            value: approved.toDouble(),
                            color: AppTheme.successGreen,
                            radius: 36,
                            title: '${(approved / total * 100).round()}%',
                            titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        if (denied > 0)
                          PieChartSectionData(
                            value: denied.toDouble(),
                            color: AppTheme.errorRed,
                            radius: 36,
                            title: '${(denied / total * 100).round()}%',
                            titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (pending > 0) _item('Pending', pending, AppTheme.warningOrange),
                      if (approved > 0) _item('Approved', approved, AppTheme.successGreen),
                      if (denied > 0) _item('Denied', denied, AppTheme.errorRed),
                      const SizedBox(height: 4),
                      Text(
                        'Total: $total',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _item(String label, int count, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '$label ($count)',
            style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }
}
