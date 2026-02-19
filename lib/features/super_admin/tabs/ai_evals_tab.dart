import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:houzzdat_app/core/theme/app_theme.dart';

/// AI Evals tab in the Super Admin Panel.
/// Provides quick links to the SiteVoice Agents eval dashboard,
/// health endpoint, and agent processing stats from Supabase.
class AiEvalsTab extends StatefulWidget {
  const AiEvalsTab({super.key});

  @override
  State<AiEvalsTab> createState() => _AiEvalsTabState();
}

class _AiEvalsTabState extends State<AiEvalsTab> {
  // TODO: Update this to your production Vercel URL after deployment
  static const String _baseUrl = 'https://sitevoice-agents.vercel.app';

  final _supabase = Supabase.instance.client;

  int _totalProcessed = 0;
  int _failedCount = 0;
  int _successCount = 0;
  Map<String, dynamic>? _lastProcessed;
  bool _loadingStats = false;

  @override
  void initState() {
    super.initState();
    _fetchStats();
  }

  Future<void> _fetchStats() async {
    setState(() => _loadingStats = true);
    try {
      // Fetch stats from agent_processing_log table directly
      final totalResult = await _supabase
          .from('agent_processing_log')
          .select('id')
          .count(CountOption.exact);

      final failedResult = await _supabase
          .from('agent_processing_log')
          .select('id')
          .eq('status', 'error')
          .count(CountOption.exact);

      final successResult = await _supabase
          .from('agent_processing_log')
          .select('id')
          .eq('status', 'success')
          .count(CountOption.exact);

      final lastResult = await _supabase
          .from('agent_processing_log')
          .select('created_at, agent_name, status')
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (mounted) {
        setState(() {
          _totalProcessed = totalResult.count;
          _failedCount = failedResult.count;
          _successCount = successResult.count;
          _lastProcessed = lastResult;
          _loadingStats = false;
        });
      }
    } catch (e) {
      debugPrint('Stats fetch failed: $e');
      if (mounted) setState(() => _loadingStats = false);
    }
  }

  Future<void> _openUrl(String path) async {
    final uri = Uri.parse('$_baseUrl$path');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not open $uri'),
          backgroundColor: AppTheme.errorRed,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.spacingL),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Text(
            'AI Agent Orchestration',
            style: AppTheme.bodySmall.copyWith(
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Manage evals, monitor agent processing, and run diagnostics.',
            style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: AppTheme.spacingL),

          // Agent processing stats card
          _buildStatsCard(),
          const SizedBox(height: AppTheme.spacingL),

          // Dashboard links
          Text(
            'Eval Dashboard',
            style: AppTheme.bodySmall.copyWith(
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: AppTheme.spacingM),
          _buildLinkCard(
            icon: Icons.science_outlined,
            title: 'Test Cases',
            subtitle: 'View, create, and manage eval test cases',
            path: '/evals/test-cases',
            color: AppTheme.primaryIndigo,
          ),
          const SizedBox(height: AppTheme.spacingS),
          _buildLinkCard(
            icon: Icons.play_circle_outline,
            title: 'Eval Runs',
            subtitle: 'Trigger and review eval run results',
            path: '/evals/runs',
            color: Colors.green.shade700,
          ),
          const SizedBox(height: AppTheme.spacingS),
          _buildLinkCard(
            icon: Icons.trending_up,
            title: 'Trends & Regressions',
            subtitle: 'Track score trends and detect regressions',
            path: '/evals/trends',
            color: Colors.orange.shade700,
          ),
          const SizedBox(height: AppTheme.spacingS),
          _buildLinkCard(
            icon: Icons.dataset_outlined,
            title: 'Seed Test Cases',
            subtitle: 'Auto-generate test cases from production voice notes',
            path: '/evals/seed',
            color: Colors.teal.shade700,
          ),

          const SizedBox(height: AppTheme.spacingXL),

          // Tools section
          Text(
            'Agent Tools',
            style: AppTheme.bodySmall.copyWith(
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: AppTheme.spacingM),
          _buildLinkCard(
            icon: Icons.monitor_heart_outlined,
            title: 'Health & Stats',
            subtitle: 'Agent processing statistics and system health',
            path: '/api/health',
            color: Colors.blue.shade700,
          ),
          const SizedBox(height: AppTheme.spacingS),
          _buildLinkCard(
            icon: Icons.open_in_browser,
            title: 'Open Full Dashboard',
            subtitle: _baseUrl,
            path: '/evals',
            color: AppTheme.primaryIndigo,
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCard() {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusM),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _totalProcessed > 0
                      ? (_failedCount == 0
                          ? Icons.check_circle
                          : Icons.warning_amber_rounded)
                      : Icons.hourglass_empty,
                  color: _totalProcessed > 0
                      ? (_failedCount == 0
                          ? AppTheme.successGreen
                          : AppTheme.warningOrange)
                      : AppTheme.textSecondary,
                  size: 22,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Agent Processing Stats',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const Spacer(),
                if (_loadingStats)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  IconButton(
                    icon: const Icon(Icons.refresh, size: 20),
                    onPressed: _fetchStats,
                    tooltip: 'Refresh',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
              ],
            ),
            const SizedBox(height: AppTheme.spacingM),
            const Divider(height: 1),
            const SizedBox(height: AppTheme.spacingM),
            _buildStatRow(
              'Total Processed',
              '$_totalProcessed',
              AppTheme.textPrimary,
            ),
            _buildStatRow(
              'Successful',
              '$_successCount',
              AppTheme.successGreen,
            ),
            _buildStatRow(
              'Failed (Pending Retry)',
              '$_failedCount',
              _failedCount > 0 ? AppTheme.errorRed : AppTheme.textSecondary,
            ),
            if (_lastProcessed != null)
              _buildStatRow(
                'Last Processed',
                '${_lastProcessed!['agent_name']} — ${_lastProcessed!['status']}',
                AppTheme.textSecondary,
              ),
            if (_totalProcessed == 0 && !_loadingStats)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'No agent processing yet. Deploy the agent service and process a voice note to see stats here.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, String value, Color valueColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
                fontSize: 13, color: AppTheme.textSecondary),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLinkCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required String path,
    required Color color,
  }) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusM),
      ),
      child: InkWell(
        onTap: () => _openUrl(path),
        borderRadius: BorderRadius.circular(AppTheme.radiusM),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spacingL,
            vertical: AppTheme.spacingM,
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: AppTheme.spacingM),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.open_in_new,
                size: 16,
                color: AppTheme.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
