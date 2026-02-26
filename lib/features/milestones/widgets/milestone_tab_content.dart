import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:houzzdat_app/core/theme/app_theme.dart';
import 'package:houzzdat_app/core/widgets/shared_widgets.dart';
import 'package:houzzdat_app/core/widgets/page_transitions.dart';
import 'package:houzzdat_app/features/milestones/services/milestone_service.dart';
import 'package:houzzdat_app/features/milestones/widgets/runway_metric_card.dart';
import 'package:houzzdat_app/features/milestones/widgets/phase_card_widget.dart';
import 'package:houzzdat_app/features/milestones/screens/milestone_setup_screen.dart';
import 'package:houzzdat_app/models/models.dart';

/// Milestone tab content embedded in InsightsTabBody.
/// Shows 4 strategic metrics + phase list for the current project.
class MilestoneTabContent extends StatefulWidget {
  final String accountId;

  const MilestoneTabContent({super.key, required this.accountId});

  @override
  State<MilestoneTabContent> createState() => _MilestoneTabContentState();
}

class _MilestoneTabContentState extends State<MilestoneTabContent>
    with AutomaticKeepAliveClientMixin {
  final _service = MilestoneService();
  final _supabase = Supabase.instance.client;

  String? _currentProjectId;
  String _userRole = 'manager';
  List<MilestonePhase> _phases = [];
  PhaseHealthMetrics? _health;
  List<Map<String, dynamic>> _projects = [];
  bool _isLoading = true;
  bool _hasPlan = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      final userData = await _supabase
          .from('users')
          .select('role, current_project_id')
          .eq('id', userId)
          .maybeSingle();

      final projectsData = await _supabase
          .from('projects')
          .select('id, name')
          .eq('account_id', widget.accountId)
          .order('name', ascending: true);

      if (mounted) {
        setState(() {
          _userRole = userData?['role'] as String? ?? 'manager';
          _currentProjectId = userData?['current_project_id'] as String?;
          _projects = (projectsData as List)
              .map((p) => <String, dynamic>{'id': p['id'] as String, 'name': p['name'] as String})
              .toList();
          if (_currentProjectId == null && _projects.isNotEmpty) {
            _currentProjectId = _projects.first['id'] as String;
          }
        });
      }

      await _loadData();
    } catch (e) {
      debugPrint('[MilestoneTabContent] initialize error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadData() async {
    if (_currentProjectId == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    setState(() => _isLoading = true);
    try {
      final hasPlan = await _service.hasMilestonePlan(_currentProjectId!);
      if (!hasPlan) {
        if (mounted) setState(() { _hasPlan = false; _isLoading = false; });
        return;
      }

      final phases = await _service.getPhasesForProject(_currentProjectId!);
      final health = await _service.getPhaseHealth(_currentProjectId!, widget.accountId);

      if (mounted) {
        setState(() {
          _phases = phases;
          _health = health;
          _hasPlan = true;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('[MilestoneTabContent] _loadData error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _navigateToSetup() {
    if (_currentProjectId == null) return;
    Navigator.push(
      context,
      FadeSlideRoute(
        page: MilestoneSetupScreen(
          accountId: widget.accountId,
          projectId: _currentProjectId!,
          projectName: _projects
              .firstWhere((p) => p['id'] == _currentProjectId,
                  orElse: () => <String, dynamic>{'name': 'Project'})['name']
              as String,
        ),
      ),
    ).then((_) => _loadData());
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_currentProjectId == null) {
      return const EmptyStateWidget(
        icon: LucideIcons.building,
        title: 'No project selected',
        subtitle: 'Select a project from the dashboard to view milestones',
      );
    }

    if (!_hasPlan) {
      return _buildSetupPrompt();
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          // Project selector
          if (_projects.length > 1) _buildProjectSelector(),

          // 4 metric cards
          if (_health != null) _buildMetricsGrid(),

          // Budget summary bar
          if (_health != null && _health!.totalBudgetAllocated > 0)
            _buildBudgetSummary(),

          // Phase list
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'PHASE PLAN',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: AppTheme.textSecondary,
                letterSpacing: 0.5,
              ),
            ),
          ),
          ..._phases.map((phase) => PhaseCardWidget(
            phase: phase,
            projectId: _currentProjectId!,
            accountId: widget.accountId,
            isManager: _userRole == 'manager' || _userRole == 'admin',
            onPhaseUpdated: _loadData,
          )),

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildSetupPrompt() {
    final isManager = _userRole == 'manager' || _userRole == 'admin';
    return Column(
      children: [
        if (_projects.length > 1) _buildProjectSelector(),
        Expanded(
          child: EmptyStateWidget(
            icon: LucideIcons.layoutList,
            title: 'No milestone plan yet',
            subtitle: isManager
                ? 'Answer 3 quick questions to generate an AI-powered construction plan'
                : 'The manager hasn\'t set up milestones for this project yet',
            action: isManager
                ? ElevatedButton(
                    onPressed: _navigateToSetup,
                    child: const Text('Setup Milestones'),
                  )
                : null,
          ),
        ),
      ],
    );
  }

  Widget _buildProjectSelector() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          const Icon(LucideIcons.mapPin, size: 14, color: AppTheme.textSecondary),
          const SizedBox(width: 6),
          DropdownButton<String>(
            value: _currentProjectId,
            items: _projects.map((p) => DropdownMenuItem<String>(
              value: p['id'] as String,
              child: Text(p['name'] as String, style: const TextStyle(fontSize: 14)),
            )).toList(),
            onChanged: (val) {
              setState(() => _currentProjectId = val);
              _loadData();
            },
            underline: const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildBudgetSummary() {
    final h = _health!;
    final spent = h.totalBudgetSpent;
    final allocated = h.totalBudgetAllocated;
    final utilPct = h.budgetUtilizationPercent;
    final isOver = spent > allocated;

    String formatCurrency(double amount) {
      if (amount >= 100000) return '${(amount / 100000).toStringAsFixed(1)}L';
      if (amount >= 1000) return '${(amount / 1000).toStringAsFixed(0)}K';
      return amount.toStringAsFixed(0);
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isOver ? AppTheme.errorRed.withValues(alpha: 0.4) : Colors.grey[200]!),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 4, offset: const Offset(0, 2)),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(LucideIcons.indianRupee, size: 14, color: AppTheme.textSecondary),
                const SizedBox(width: 6),
                const Text(
                  'BUDGET',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.textSecondary, letterSpacing: 0.5),
                ),
                const Spacer(),
                Text(
                  '₹${formatCurrency(spent)} / ₹${formatCurrency(allocated)}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: isOver ? AppTheme.errorRed : AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '(${utilPct.round()}%)',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isOver ? AppTheme.errorRed : utilPct > 80 ? AppTheme.warningOrange : AppTheme.successGreen,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: (utilPct / 100).clamp(0, 1),
                minHeight: 5,
                backgroundColor: Colors.grey[200],
                valueColor: AlwaysStoppedAnimation(
                  isOver ? AppTheme.errorRed : utilPct > 80 ? AppTheme.warningOrange : AppTheme.successGreen,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricsGrid() {
    final h = _health!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: GridView.count(
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.6,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          RunwayMetricCard.runway(h),
          RunwayMetricCard.blockers(h),
          RunwayMetricCard.valueDelivered(h),
          RunwayMetricCard.forecast(h),
        ],
      ),
    );
  }
}
