import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:houzzdat_app/core/theme/app_theme.dart';

/// Health Score Weight Configuration tab for Super Admins.
///
/// Shows 6 sliders for the health score factors that must sum to 100.
/// Supports global defaults (account_id = null) and per-company overrides.
class HealthScoreConfigTab extends StatefulWidget {
  const HealthScoreConfigTab({super.key});

  @override
  State<HealthScoreConfigTab> createState() => _HealthScoreConfigTabState();
}

class _HealthScoreConfigTabState extends State<HealthScoreConfigTab> {
  final _supabase = Supabase.instance.client;

  bool _isLoading = true;
  bool _isSaving = false;
  String? _selectedAccountId; // null = global default
  List<Map<String, dynamic>> _companies = [];

  // Weight values
  double _taskCompletion = 20;
  double _scheduleAdherence = 25;
  double _blockerSeverity = 20;
  double _activityRecency = 15;
  double _workerAttendance = 10;
  double _overduePenalty = 10;

  // Original values (to detect changes)
  Map<String, double> _originalWeights = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      // Fetch all companies for the selector
      final companies = await _supabase
          .from('accounts')
          .select('id, company_name')
          .order('company_name');

      _companies = List<Map<String, dynamic>>.from(companies);

      // Load global defaults
      await _loadWeights(null);
    } catch (e) {
      debugPrint('Error loading health score config: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadWeights(String? accountId) async {
    try {
      Map<String, dynamic>? row;

      if (accountId == null) {
        row = await _supabase
            .from('health_score_weights')
            .select()
            .isFilter('account_id', null)
            .maybeSingle();
      } else {
        row = await _supabase
            .from('health_score_weights')
            .select()
            .eq('account_id', accountId)
            .maybeSingle();

        // Fall back to global defaults if no per-company config
        row ??= await _supabase
            .from('health_score_weights')
            .select()
            .isFilter('account_id', null)
            .maybeSingle();
      }

      if (row != null && mounted) {
        setState(() {
          _taskCompletion = (row!['task_completion_weight'] as num?)?.toDouble() ?? 20;
          _scheduleAdherence = (row['schedule_adherence_weight'] as num?)?.toDouble() ?? 25;
          _blockerSeverity = (row['blocker_severity_weight'] as num?)?.toDouble() ?? 20;
          _activityRecency = (row['activity_recency_weight'] as num?)?.toDouble() ?? 15;
          _workerAttendance = (row['worker_attendance_weight'] as num?)?.toDouble() ?? 10;
          _overduePenalty = (row['overdue_penalty_weight'] as num?)?.toDouble() ?? 10;
          _originalWeights = _currentWeightsMap();
        });
      }
    } catch (e) {
      debugPrint('Error loading weights: $e');
    }
  }

  Map<String, double> _currentWeightsMap() => {
    'task_completion_weight': _taskCompletion,
    'schedule_adherence_weight': _scheduleAdherence,
    'blocker_severity_weight': _blockerSeverity,
    'activity_recency_weight': _activityRecency,
    'worker_attendance_weight': _workerAttendance,
    'overdue_penalty_weight': _overduePenalty,
  };

  double get _totalWeight =>
      _taskCompletion + _scheduleAdherence + _blockerSeverity +
      _activityRecency + _workerAttendance + _overduePenalty;

  bool get _isValid => (_totalWeight - 100).abs() < 0.01;

  bool get _hasChanges {
    final current = _currentWeightsMap();
    for (final key in current.keys) {
      if ((current[key]! - (_originalWeights[key] ?? 0)).abs() > 0.01) return true;
    }
    return false;
  }

  Future<void> _save() async {
    if (!_isValid || _isSaving) return;

    setState(() => _isSaving = true);
    try {
      final user = _supabase.auth.currentUser;
      final data = {
        'account_id': _selectedAccountId,
        'task_completion_weight': _taskCompletion,
        'schedule_adherence_weight': _scheduleAdherence,
        'blocker_severity_weight': _blockerSeverity,
        'activity_recency_weight': _activityRecency,
        'worker_attendance_weight': _workerAttendance,
        'overdue_penalty_weight': _overduePenalty,
        'updated_by': user?.id,
        'updated_at': DateTime.now().toIso8601String(),
      };

      // Upsert: insert or update on conflict
      await _supabase.from('health_score_weights').upsert(
        data,
        onConflict: 'account_id',
      );

      _originalWeights = _currentWeightsMap();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Health score weights saved'),
            backgroundColor: AppTheme.successGreen,
          ),
        );
        setState(() {});
      }
    } catch (e) {
      debugPrint('Error saving weights: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save: $e'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _resetDefaults() {
    setState(() {
      _taskCompletion = 20;
      _scheduleAdherence = 25;
      _blockerSeverity = 20;
      _activityRecency = 15;
      _workerAttendance = 10;
      _overduePenalty = 10;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.primaryIndigo),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Company selector
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('SCOPE',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold,
                        color: AppTheme.textSecondary, letterSpacing: 1)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String?>(
                    value: _selectedAccountId,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                      prefixIcon: Icon(Icons.business),
                    ),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('Global Defaults (all companies)'),
                      ),
                      ..._companies.map((c) => DropdownMenuItem<String?>(
                        value: c['id']?.toString(),
                        child: Text(c['company_name']?.toString() ?? 'Unknown'),
                      )),
                    ],
                    onChanged: (val) {
                      setState(() => _selectedAccountId = val);
                      _loadWeights(val);
                    },
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Weight sliders
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text('HEALTH SCORE WEIGHTS',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold,
                            color: AppTheme.textSecondary, letterSpacing: 1)),
                      const Spacer(),
                      TextButton.icon(
                        icon: const Icon(Icons.restart_alt, size: 16),
                        label: const Text('Reset', style: TextStyle(fontSize: 12)),
                        onPressed: _resetDefaults,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  _buildWeightSlider(
                    'Task Completion',
                    Icons.task_alt,
                    _taskCompletion,
                    (v) => setState(() => _taskCompletion = v.roundToDouble()),
                  ),
                  _buildWeightSlider(
                    'Schedule Adherence',
                    Icons.calendar_today,
                    _scheduleAdherence,
                    (v) => setState(() => _scheduleAdherence = v.roundToDouble()),
                  ),
                  _buildWeightSlider(
                    'Blocker Severity',
                    Icons.block,
                    _blockerSeverity,
                    (v) => setState(() => _blockerSeverity = v.roundToDouble()),
                  ),
                  _buildWeightSlider(
                    'Activity Recency',
                    Icons.timeline,
                    _activityRecency,
                    (v) => setState(() => _activityRecency = v.roundToDouble()),
                  ),
                  _buildWeightSlider(
                    'Worker Attendance',
                    Icons.people,
                    _workerAttendance,
                    (v) => setState(() => _workerAttendance = v.roundToDouble()),
                  ),
                  _buildWeightSlider(
                    'Overdue Penalty',
                    Icons.warning_amber,
                    _overduePenalty,
                    (v) => setState(() => _overduePenalty = v.roundToDouble()),
                  ),

                  const SizedBox(height: 12),
                  const Divider(),
                  const SizedBox(height: 8),

                  // Total indicator
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('Total: ',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      Text(
                        '${_totalWeight.toInt()}%',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: _isValid ? AppTheme.successGreen : AppTheme.errorRed,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        _isValid ? Icons.check_circle : Icons.error,
                        color: _isValid ? AppTheme.successGreen : AppTheme.errorRed,
                        size: 20,
                      ),
                    ],
                  ),
                  if (!_isValid) ...[
                    const SizedBox(height: 4),
                    Center(
                      child: Text(
                        'Weights must sum to exactly 100%',
                        style: TextStyle(fontSize: 12, color: AppTheme.errorRed),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Save button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _isValid && _hasChanges && !_isSaving ? _save : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentAmber,
                foregroundColor: Colors.black,
                disabledBackgroundColor: Colors.grey.shade300,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isSaving
                  ? const SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                  : const Text('Save Weights',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeightSlider(
    String label,
    IconData icon,
    double value,
    ValueChanged<double> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppTheme.primaryIndigo),
          const SizedBox(width: 8),
          SizedBox(
            width: 120,
            child: Text(label,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
          ),
          Expanded(
            child: Slider(
              value: value,
              min: 0,
              max: 50,
              divisions: 50,
              activeColor: AppTheme.primaryIndigo,
              onChanged: onChanged,
            ),
          ),
          SizedBox(
            width: 40,
            child: Text(
              '${value.toInt()}%',
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
