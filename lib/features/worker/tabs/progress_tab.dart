import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:houzzdat_app/core/theme/app_theme.dart';

/// Progress tab — shows worker performance metrics for selected period.
///
/// Displays:
/// - Completion ring (tasks completed / total)
/// - Hours on site, Days worked
/// - Voice notes sent, Pending tasks
/// - Approval rate from approval-type action items
///
/// Period toggle: THIS WEEK (7 days) / THIS MONTH (30 days)
class ProgressTab extends StatefulWidget {
  final String accountId;
  final String userId;
  final String? projectId;

  const ProgressTab({
    super.key,
    required this.accountId,
    required this.userId,
    this.projectId,
  });

  @override
  State<ProgressTab> createState() => _ProgressTabState();
}

class _ProgressTabState extends State<ProgressTab> {
  final _supabase = Supabase.instance.client;

  bool _isLoading = true;
  String? _error;
  String _period = 'week'; // 'week' or 'month'

  // User info
  String? _fullName;
  String? _firstInitial;

  // Metrics
  int _daysWorked = 0;
  Duration _totalHours = Duration.zero;
  int _tasksTotal = 0;
  int _tasksCompleted = 0;
  int _tasksPending = 0;
  int _notesSent = 0;
  double _approvalRate = 0.0;
  bool _hasApprovalData = false;

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
    _loadMetrics();
  }

  Future<void> _loadUserInfo() async {
    try {
      final user = await _supabase
          .from('users')
          .select('full_name, email')
          .eq('id', widget.userId)
          .maybeSingle();

      if (user != null && mounted) {
        final name = user['full_name']?.toString() ?? user['email']?.toString() ?? 'Worker';
        setState(() {
          _fullName = name;
          _firstInitial = name.isNotEmpty ? name[0].toUpperCase() : 'W';
        });
      }
    } catch (e) {
      debugPrint('Error loading user info: $e');
    }
  }

  Future<void> _loadMetrics() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final now = DateTime.now();
      final days = _period == 'week' ? 7 : 30;
      final periodStart = now.subtract(Duration(days: days));

      // Parallel queries
      await Future.wait([
        _loadAttendanceMetrics(periodStart),
        _loadTaskMetrics(periodStart),
        _loadApprovalMetrics(periodStart),
        _loadVoiceNoteMetrics(periodStart),
      ]);

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading metrics: $e');
      if (mounted) {
        setState(() {
          _error = 'Failed to load progress data';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadAttendanceMetrics(DateTime periodStart) async {
    try {
      final attendance = await _supabase
          .from('attendance')
          .select('check_in_at, check_out_at')
          .eq('user_id', widget.userId)
          .not('check_out_at', 'is', null)
          .gte('check_in_at', periodStart.toIso8601String());

      int daysCount = 0;
      Duration totalDuration = Duration.zero;

      for (final record in attendance) {
        daysCount++;
        final checkIn = DateTime.parse(record['check_in_at'].toString());
        final checkOut = DateTime.parse(record['check_out_at'].toString());
        totalDuration += checkOut.difference(checkIn);
      }

      if (mounted) {
        setState(() {
          _daysWorked = daysCount;
          _totalHours = totalDuration;
        });
      }
    } catch (e) {
      debugPrint('Error loading attendance: $e');
    }
  }

  Future<void> _loadTaskMetrics(DateTime periodStart) async {
    try {
      final tasks = await _supabase
          .from('action_items')
          .select('id, status')
          .eq('assigned_to', widget.userId)
          .eq('account_id', widget.accountId)
          .gte('created_at', periodStart.toIso8601String());

      int total = tasks.length;
      int completed = 0;
      int pending = 0;

      for (final task in tasks) {
        final status = task['status']?.toString().toLowerCase() ?? '';
        if (status == 'completed') {
          completed++;
        } else if (status == 'pending' || status == 'in_progress') {
          pending++;
        }
      }

      if (mounted) {
        setState(() {
          _tasksTotal = total;
          _tasksCompleted = completed;
          _tasksPending = pending;
        });
      }
    } catch (e) {
      debugPrint('Error loading tasks: $e');
    }
  }

  Future<void> _loadApprovalMetrics(DateTime periodStart) async {
    try {
      final approvals = await _supabase
          .from('action_items')
          .select('id, status')
          .eq('assigned_to', widget.userId)
          .eq('category', 'approval')
          .eq('account_id', widget.accountId)
          .gte('created_at', periodStart.toIso8601String());

      if (approvals.isNotEmpty) {
        int total = approvals.length;
        int approved = approvals.where((a) => a['status'] == 'completed').length;

        if (mounted) {
          setState(() {
            _hasApprovalData = true;
            _approvalRate = total > 0 ? (approved / total * 100) : 0.0;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _hasApprovalData = false;
            _approvalRate = 0.0;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading approvals: $e');
    }
  }

  Future<void> _loadVoiceNoteMetrics(DateTime periodStart) async {
    try {
      final notes = await _supabase
          .from('voice_notes')
          .select('id')
          .eq('user_id', widget.userId)
          .eq('account_id', widget.accountId)
          .isFilter('parent_id', null)
          .gte('created_at', periodStart.toIso8601String());

      if (mounted) {
        setState(() {
          _notesSent = notes.length;
        });
      }
    } catch (e) {
      debugPrint('Error loading voice notes: $e');
    }
  }

  void _togglePeriod(String newPeriod) {
    if (_period != newPeriod) {
      setState(() => _period = newPeriod);
      _loadMetrics();
    }
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    if (hours == 0 && minutes == 0) return '0h';
    if (hours == 0) return '${minutes}m';
    if (minutes == 0) return '${hours}h';
    return '${hours}h ${minutes}m';
  }

  Color _getApprovalColor() {
    if (!_hasApprovalData) return Colors.grey.shade400;
    if (_approvalRate >= 70) return AppTheme.successGreen;
    if (_approvalRate >= 40) return AppTheme.warningOrange;
    return AppTheme.errorRed;
  }

  Color _getPendingColor() {
    return _tasksPending > 0 ? AppTheme.warningOrange : AppTheme.successGreen;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.primaryIndigo),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(LucideIcons.alertCircle, size: 48, color: AppTheme.errorRed),
            const SizedBox(height: 16),
            Text(_error!, style: AppTheme.bodyMedium),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadMetrics,
              icon: const Icon(LucideIcons.refreshCw),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadMetrics,
      color: AppTheme.primaryIndigo,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Profile section
            CircleAvatar(
              radius: 40,
              backgroundColor: AppTheme.primaryIndigo,
              child: Text(
                _firstInitial ?? 'W',
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _fullName ?? 'Loading...',
              style: AppTheme.headingMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            // Period toggle
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _PeriodChip(
                  label: 'THIS WEEK',
                  isSelected: _period == 'week',
                  onTap: () => _togglePeriod('week'),
                ),
                const SizedBox(width: 12),
                _PeriodChip(
                  label: 'THIS MONTH',
                  isSelected: _period == 'month',
                  onTap: () => _togglePeriod('month'),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Completion ring
            _CompletionRing(
              completed: _tasksCompleted,
              total: _tasksTotal,
            ),
            const SizedBox(height: 24),

            // Stat cards grid
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.2,
              children: [
                _StatCard(
                  icon: LucideIcons.clock,
                  value: _formatDuration(_totalHours),
                  label: 'Hours on Site',
                  color: AppTheme.infoBlue,
                ),
                _StatCard(
                  icon: LucideIcons.calendarCheck,
                  value: _daysWorked.toString(),
                  label: 'Days Worked',
                  color: AppTheme.successGreen,
                ),
                _StatCard(
                  icon: LucideIcons.mic,
                  value: _notesSent.toString(),
                  label: 'Voice Notes',
                  color: AppTheme.accentAmber,
                ),
                _StatCard(
                  icon: LucideIcons.clipboardList,
                  value: _tasksPending.toString(),
                  label: 'Pending Tasks',
                  color: _getPendingColor(),
                ),
                _StatCard(
                  icon: LucideIcons.thumbsUp,
                  value: _hasApprovalData ? '${_approvalRate.toInt()}%' : '—',
                  label: 'Approval Rate',
                  color: _getApprovalColor(),
                ),
              ],
            ),
            const SizedBox(height: 80), // Bottom padding for FAB
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// Period Chip
// ════════════════════════════════════════════════════════════════

class _PeriodChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _PeriodChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryIndigo : Colors.transparent,
          border: Border.all(
            color: AppTheme.primaryIndigo,
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : AppTheme.primaryIndigo,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// Completion Ring
// ════════════════════════════════════════════════════════════════

class _CompletionRing extends StatelessWidget {
  final int completed;
  final int total;

  const _CompletionRing({
    required this.completed,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final percentage = total > 0 ? completed / total : 0.0;

    return SizedBox(
      width: 160,
      height: 160,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Ring
          CustomPaint(
            size: const Size(160, 160),
            painter: _RingPainter(
              percentage: percentage,
              hasData: total > 0,
            ),
          ),
          // Center text
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                completed.toString(),
                style: const TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              Text(
                'completed',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double percentage;
  final bool hasData;

  _RingPainter({required this.percentage, required this.hasData});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 12;

    // Background ring (grey)
    final bgPaint = Paint()
      ..color = Colors.grey.shade300
      ..strokeWidth = 12
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, bgPaint);

    // Progress ring (green)
    if (hasData && percentage > 0) {
      final progressPaint = Paint()
        ..color = AppTheme.successGreen
        ..strokeWidth = 12
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      const startAngle = -math.pi / 2; // Start at top
      final sweepAngle = 2 * math.pi * percentage;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        progressPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// ════════════════════════════════════════════════════════════════
// Stat Card
// ════════════════════════════════════════════════════════════════

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Icon
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 20,
                color: color,
              ),
            ),
            // Value
            Text(
              value,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            // Label
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade600,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
