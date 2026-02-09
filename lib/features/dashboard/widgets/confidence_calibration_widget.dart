import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:houzzdat_app/core/theme/app_theme.dart';

/// Confidence Calibration Dashboard (Phase D)
/// Shows weekly AI accuracy trends, correction counts, and confidence distribution.
/// Collapsible panel designed to sit at the top of the Actions tab.
class ConfidenceCalibrationWidget extends StatefulWidget {
  final String accountId;
  const ConfidenceCalibrationWidget({super.key, required this.accountId});

  @override
  State<ConfidenceCalibrationWidget> createState() =>
      _ConfidenceCalibrationWidgetState();
}

class _ConfidenceCalibrationWidgetState
    extends State<ConfidenceCalibrationWidget> {
  final _supabase = Supabase.instance.client;
  bool _isExpanded = false;
  bool _isLoading = false;
  Map<String, dynamic>? _currentWeek;
  Map<String, dynamic>? _previousWeek;
  int _totalCorrections = 0;
  int _confirmedCount = 0;
  int _dismissedCount = 0;
  int _promotedCount = 0;

  Future<void> _loadStats() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    try {
      // Current week stats from action_items directly
      final now = DateTime.now();
      final weekStart = now.subtract(Duration(days: now.weekday - 1));
      final prevWeekStart = weekStart.subtract(const Duration(days: 7));

      final currentWeekData = await _supabase
          .from('action_items')
          .select('confidence_score, needs_review, is_critical_flag')
          .eq('account_id', widget.accountId)
          .gte('created_at', weekStart.toIso8601String());

      final prevWeekData = await _supabase
          .from('action_items')
          .select('confidence_score, needs_review, is_critical_flag')
          .eq('account_id', widget.accountId)
          .gte('created_at', prevWeekStart.toIso8601String())
          .lt('created_at', weekStart.toIso8601String());

      _currentWeek = _aggregateWeek(currentWeekData);
      _previousWeek = _aggregateWeek(prevWeekData);

      // Correction stats for current week
      final corrections = await _supabase
          .from('ai_corrections')
          .select('correction_type')
          .eq('account_id', widget.accountId)
          .gte('created_at', weekStart.toIso8601String());

      _totalCorrections = corrections.length;
      _confirmedCount = corrections
          .where((c) => c['correction_type'] == 'review_confirmed')
          .length;
      _dismissedCount = corrections
          .where((c) => c['correction_type'] == 'review_dismissed')
          .length;
      _promotedCount = corrections
          .where((c) => c['correction_type'] == 'promoted_to_action')
          .length;
    } catch (e) {
      debugPrint('Error loading calibration stats: $e');
    }

    if (mounted) setState(() => _isLoading = false);
  }

  Map<String, dynamic> _aggregateWeek(List<dynamic> items) {
    if (items.isEmpty) {
      return {
        'total': 0,
        'avg_confidence': 0.0,
        'high': 0,
        'medium': 0,
        'low': 0,
        'review': 0,
        'critical': 0,
      };
    }

    double totalConf = 0;
    int high = 0, medium = 0, low = 0, review = 0, critical = 0;

    for (final item in items) {
      final score =
          double.tryParse(item['confidence_score']?.toString() ?? '') ?? 0.5;
      totalConf += score;
      if (score >= 0.85) {
        high++;
      } else if (score >= 0.70) {
        medium++;
      } else {
        low++;
      }
      if (item['needs_review'] == true) review++;
      if (item['is_critical_flag'] == true) critical++;
    }

    return {
      'total': items.length,
      'avg_confidence': totalConf / items.length,
      'high': high,
      'medium': medium,
      'low': low,
      'review': review,
      'critical': critical,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusM),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () {
              setState(() => _isExpanded = !_isExpanded);
              if (_isExpanded && _currentWeek == null) _loadStats();
            },
            borderRadius: BorderRadius.circular(AppTheme.radiusM),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  const Icon(Icons.insights, size: 20, color: AppTheme.infoBlue),
                  const SizedBox(width: 8),
                  const Text(
                    'AI ACCURACY',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: AppTheme.infoBlue,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    _isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: AppTheme.textSecondary,
                  ),
                ],
              ),
            ),
          ),
          if (_isExpanded) _buildExpandedContent(),
        ],
      ),
    );
  }

  Widget _buildExpandedContent() {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_currentWeek == null) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text('No data available', style: TextStyle(color: AppTheme.textSecondary)),
      );
    }

    final total = _currentWeek!['total'] as int;
    final avgConf = _currentWeek!['avg_confidence'] as double;
    final high = _currentWeek!['high'] as int;
    final medium = _currentWeek!['medium'] as int;
    final low = _currentWeek!['low'] as int;

    // Trend calculation
    final prevAvg = _previousWeek?['avg_confidence'] as double? ?? 0;
    final trend = total > 0 && prevAvg > 0 ? avgConf - prevAvg : null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(height: 1),
          const SizedBox(height: 12),
          // Row 1: Overall confidence + trend
          Row(
            children: [
              _buildStatCard(
                'This Week',
                total > 0 ? '${(avgConf * 100).toStringAsFixed(0)}%' : 'N/A',
                'avg confidence',
                _getConfidenceColor(avgConf),
              ),
              const SizedBox(width: 8),
              _buildStatCard(
                'Trend',
                trend != null
                    ? '${trend >= 0 ? '+' : ''}${(trend * 100).toStringAsFixed(1)}%'
                    : 'N/A',
                'vs last week',
                trend != null
                    ? (trend >= 0 ? AppTheme.successGreen : AppTheme.errorRed)
                    : AppTheme.textSecondary,
              ),
              const SizedBox(width: 8),
              _buildStatCard(
                'Items',
                '$total',
                'processed',
                AppTheme.primaryIndigo,
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Row 2: Confidence distribution bar
          const Text(
            'CONFIDENCE DISTRIBUTION',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          if (total > 0)
            _buildDistributionBar(high, medium, low, total)
          else
            const Text('No items this week',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
          const SizedBox(height: 12),
          // Row 3: Correction feedback stats
          const Text(
            'MANAGER FEEDBACK',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              _buildFeedbackChip(
                  'Confirmed', _confirmedCount, AppTheme.successGreen),
              const SizedBox(width: 6),
              _buildFeedbackChip(
                  'Dismissed', _dismissedCount, AppTheme.errorRed),
              const SizedBox(width: 6),
              _buildFeedbackChip(
                  'Promoted', _promotedCount, AppTheme.warningOrange),
              const SizedBox(width: 6),
              _buildFeedbackChip(
                  'Total', _totalCorrections, AppTheme.primaryIndigo),
            ],
          ),
          const SizedBox(height: 8),
          // Action buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: () => _showGlossaryManager(context),
                icon: const Icon(Icons.book, size: 16),
                label:
                    const Text('Site Glossary', style: TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.primaryIndigo,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: _loadStats,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Refresh', style: TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.infoBlue,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
      String label, String value, String subtitle, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(AppTheme.radiusS),
          border: Border.all(color: color.withValues(alpha: 0.15)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDistributionBar(int high, int medium, int low, int total) {
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: SizedBox(
            height: 12,
            child: Row(
              children: [
                if (high > 0)
                  Expanded(
                    flex: high,
                    child: Container(color: AppTheme.successGreen),
                  ),
                if (medium > 0)
                  Expanded(
                    flex: medium,
                    child: Container(color: AppTheme.warningOrange),
                  ),
                if (low > 0)
                  Expanded(
                    flex: low,
                    child: Container(color: AppTheme.textSecondary),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            _legendDot(AppTheme.successGreen, 'High ≥85%', high),
            const SizedBox(width: 12),
            _legendDot(AppTheme.warningOrange, 'Med 70-84%', medium),
            const SizedBox(width: 12),
            _legendDot(AppTheme.textSecondary, 'Low <70%', low),
          ],
        ),
      ],
    );
  }

  Widget _legendDot(Color color, String label, int count) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          '$label ($count)',
          style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary),
        ),
      ],
    );
  }

  Widget _buildFeedbackChip(String label, int count, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppTheme.radiusS),
        ),
        child: Column(
          children: [
            Text(
              '$count',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              label,
              style: const TextStyle(fontSize: 9, color: AppTheme.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  void _showGlossaryManager(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => _GlossaryManagerSheet(accountId: widget.accountId),
    );
  }

  Color _getConfidenceColor(double score) {
    if (score >= 0.85) return AppTheme.successGreen;
    if (score >= 0.70) return AppTheme.warningOrange;
    return AppTheme.errorRed;
  }
}

/// Bottom sheet for managing site-specific glossary terms.
/// Allows managers to add/remove construction terms that the AI should know about.
class _GlossaryManagerSheet extends StatefulWidget {
  final String accountId;
  const _GlossaryManagerSheet({required this.accountId});

  @override
  State<_GlossaryManagerSheet> createState() => _GlossaryManagerSheetState();
}

class _GlossaryManagerSheetState extends State<_GlossaryManagerSheet> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _terms = [];
  bool _isLoading = true;
  String? _selectedProjectId;
  List<Map<String, dynamic>> _projects = [];

  @override
  void initState() {
    super.initState();
    _loadProjects();
  }

  Future<void> _loadProjects() async {
    try {
      final data = await _supabase
          .from('projects')
          .select('id, name')
          .eq('account_id', widget.accountId)
          .order('name');
      if (mounted) {
        setState(() {
          _projects = List<Map<String, dynamic>>.from(data);
          if (_projects.isNotEmpty) {
            _selectedProjectId = _projects.first['id']?.toString();
            _loadTerms();
          } else {
            _isLoading = false;
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading projects: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadTerms() async {
    if (_selectedProjectId == null) return;
    setState(() => _isLoading = true);
    try {
      final data = await _supabase
          .from('site_glossary')
          .select()
          .eq('project_id', _selectedProjectId!)
          .eq('is_active', true)
          .order('term');
      if (mounted) {
        setState(() {
          _terms = List<Map<String, dynamic>>.from(data);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading glossary: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _addTerm() async {
    final termController = TextEditingController();
    final defController = TextEditingController();
    String category = 'general';

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Add Glossary Term'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: termController,
                decoration: const InputDecoration(
                  labelText: 'Term',
                  hintText: 'e.g. TMT, shuttering, DPC',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: defController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Definition',
                  hintText: 'e.g. TMT steel reinforcement bars',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: category,
                decoration: const InputDecoration(
                  labelText: 'Category',
                  border: OutlineInputBorder(),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                items: const [
                  DropdownMenuItem(value: 'material', child: Text('Material')),
                  DropdownMenuItem(value: 'brand', child: Text('Brand')),
                  DropdownMenuItem(value: 'tool', child: Text('Tool')),
                  DropdownMenuItem(value: 'process', child: Text('Process')),
                  DropdownMenuItem(value: 'location', child: Text('Location')),
                  DropdownMenuItem(value: 'role', child: Text('Role')),
                  DropdownMenuItem(value: 'general', child: Text('General')),
                ],
                onChanged: (v) =>
                    setDialogState(() => category = v ?? category),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryIndigo),
              child:
                  const Text('Add', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );

    if (result == true &&
        termController.text.trim().isNotEmpty &&
        defController.text.trim().isNotEmpty) {
      try {
        await _supabase.from('site_glossary').insert({
          'project_id': _selectedProjectId,
          'account_id': widget.accountId,
          'term': termController.text.trim(),
          'definition': defController.text.trim(),
          'category': category,
          'added_by': _supabase.auth.currentUser?.id,
        });
        _loadTerms();
      } catch (e) {
        debugPrint('Error adding term: $e');
      }
    }
  }

  Future<void> _deleteTerm(String id) async {
    try {
      await _supabase
          .from('site_glossary')
          .update({'is_active': false})
          .eq('id', id);
      _loadTerms();
    } catch (e) {
      debugPrint('Error deleting term: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.book, color: AppTheme.primaryIndigo),
              const SizedBox(width: 8),
              const Text(
                'SITE GLOSSARY',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.add_circle, color: AppTheme.primaryIndigo),
                onPressed: _selectedProjectId != null ? _addTerm : null,
                tooltip: 'Add term',
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Add construction terms specific to your site. These help AI better understand voice notes.',
            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 12),
          // Project selector
          if (_projects.isNotEmpty)
            DropdownButtonFormField<String>(
              value: _selectedProjectId,
              decoration: const InputDecoration(
                labelText: 'Project',
                border: OutlineInputBorder(),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              items: _projects
                  .map((p) => DropdownMenuItem<String>(
                        value: p['id']?.toString(),
                        child: Text(p['name']?.toString() ?? ''),
                      ))
                  .toList(),
              onChanged: (v) {
                setState(() => _selectedProjectId = v);
                _loadTerms();
              },
            ),
          const SizedBox(height: 12),
          const Divider(),
          // Terms list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _terms.isEmpty
                    ? const Center(
                        child: Text(
                          'No glossary terms yet.\nTap + to add construction terms.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppTheme.textSecondary),
                        ),
                      )
                    : ListView.separated(
                        itemCount: _terms.length,
                        separatorBuilder: (_, __) =>
                            const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final term = _terms[index];
                          return ListTile(
                            dense: true,
                            title: Text(
                              term['term']?.toString() ?? '',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text(
                              term['definition']?.toString() ?? '',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppTheme.infoBlue
                                        .withValues(alpha: 0.1),
                                    borderRadius:
                                        BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    term['category']
                                            ?.toString()
                                            .toUpperCase() ??
                                        '',
                                    style: const TextStyle(
                                        fontSize: 9,
                                        color: AppTheme.infoBlue),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline,
                                      size: 18,
                                      color: AppTheme.errorRed),
                                  onPressed: () => _deleteTerm(
                                      term['id']?.toString() ?? ''),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
