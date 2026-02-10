import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:houzzdat_app/core/theme/app_theme.dart';

/// Read-only detail view for a company, primarily used for archived companies.
/// Shows company info, user list, project list, and statistics.
class CompanyDetailScreen extends StatefulWidget {
  final String accountId;
  final String companyName;
  final String status;

  const CompanyDetailScreen({
    super.key,
    required this.accountId,
    required this.companyName,
    required this.status,
  });

  @override
  State<CompanyDetailScreen> createState() => _CompanyDetailScreenState();
}

class _CompanyDetailScreenState extends State<CompanyDetailScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;

  Map<String, dynamic>? _companyInfo;
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _projects = [];
  int _voiceNoteCount = 0;
  int _actionItemCount = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      // Load all data in parallel
      final results = await Future.wait([
        // Company info
        _supabase
            .from('accounts')
            .select()
            .eq('id', widget.accountId)
            .maybeSingle(),
        // Users via associations
        _supabase
            .from('user_company_associations')
            .select('id, user_id, role, status, is_primary, joined_at, deactivated_at')
            .eq('account_id', widget.accountId)
            .order('role'),
        // Projects
        _supabase
            .from('projects')
            .select('id, name, address, created_at')
            .eq('account_id', widget.accountId)
            .order('created_at'),
        // Voice note count
        _supabase
            .from('voice_notes')
            .select('id')
            .eq('account_id', widget.accountId),
        // Action item count
        _supabase
            .from('action_items')
            .select('id')
            .eq('account_id', widget.accountId),
      ]);

      final companyInfo = results[0] as Map<String, dynamic>?;
      final associations = results[1] as List;
      final projects = results[2] as List;
      final voiceNotes = results[3] as List;
      final actionItems = results[4] as List;

      // Enrich user associations with user details
      List<Map<String, dynamic>> enrichedUsers = [];
      if (associations.isNotEmpty) {
        final userIds =
            associations.map((a) => a['user_id'] as String).toList();
        final users = await _supabase
            .from('users')
            .select('id, email, full_name')
            .inFilter('id', userIds);

        final userMap = <String, Map<String, dynamic>>{};
        for (final u in users) {
          userMap[u['id']] = u;
        }

        enrichedUsers = associations.map((assoc) {
          final userData = userMap[assoc['user_id']] ?? {};
          return {
            ...Map<String, dynamic>.from(userData),
            'role': assoc['role'],
            'status': assoc['status'],
            'is_primary': assoc['is_primary'],
            'joined_at': assoc['joined_at'],
            'deactivated_at': assoc['deactivated_at'],
          };
        }).toList();
      }

      if (mounted) {
        setState(() {
          _companyInfo = companyInfo;
          _users = enrichedUsers;
          _projects = projects.cast<Map<String, dynamic>>();
          _voiceNoteCount = voiceNotes.length;
          _actionItemCount = actionItems.length;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading company details: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundGrey,
      appBar: AppBar(
        title: Text(widget.companyName),
        backgroundColor: AppTheme.primaryIndigo,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryIndigo),
            )
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.all(AppTheme.spacingM),
                children: [
                  _buildCompanyInfoCard(),
                  const SizedBox(height: AppTheme.spacingM),
                  _buildStatisticsCard(),
                  const SizedBox(height: AppTheme.spacingM),
                  _buildUsersSection(),
                  const SizedBox(height: AppTheme.spacingM),
                  _buildProjectsSection(),
                ],
              ),
            ),
    );
  }

  Widget _buildCompanyInfoCard() {
    final createdAt = _companyInfo?['created_at'] != null
        ? DateTime.tryParse(_companyInfo!['created_at'].toString())
        : null;
    final deactivatedAt = _companyInfo?['deactivated_at'] != null
        ? DateTime.tryParse(_companyInfo!['deactivated_at'].toString())
        : null;
    final archivedAt = _companyInfo?['archived_at'] != null
        ? DateTime.tryParse(_companyInfo!['archived_at'].toString())
        : null;
    final provider =
        _companyInfo?['transcription_provider']?.toString() ?? 'groq';

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
                CircleAvatar(
                  radius: 28,
                  backgroundColor:
                      AppTheme.primaryIndigo.withValues(alpha: 0.1),
                  child: Text(
                    widget.companyName.isNotEmpty
                        ? widget.companyName[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryIndigo,
                    ),
                  ),
                ),
                const SizedBox(width: AppTheme.spacingM),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.companyName,
                        style: AppTheme.headingSmall,
                      ),
                      const SizedBox(height: 4),
                      _buildStatusChip(widget.status),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spacingL),
            const Divider(),
            const SizedBox(height: AppTheme.spacingM),
            _buildProviderRow(provider),
            if (createdAt != null) ...[
              const SizedBox(height: AppTheme.spacingS),
              _buildInfoRow(Icons.calendar_today, 'Created',
                  DateFormat('MMM d, yyyy').format(createdAt)),
            ],
            if (deactivatedAt != null) ...[
              const SizedBox(height: AppTheme.spacingS),
              _buildInfoRow(Icons.pause_circle, 'Deactivated',
                  DateFormat('MMM d, yyyy').format(deactivatedAt)),
            ],
            if (archivedAt != null) ...[
              const SizedBox(height: AppTheme.spacingS),
              _buildInfoRow(Icons.archive, 'Archived',
                  DateFormat('MMM d, yyyy').format(archivedAt)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatisticsCard() {
    final activeUsers = _users.where((u) => u['status'] == 'active').length;
    final inactiveUsers = _users.where((u) => u['status'] != 'active').length;

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusM),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Statistics', style: AppTheme.headingSmall),
            const SizedBox(height: AppTheme.spacingM),
            Row(
              children: [
                _buildStatItem('Active Users', activeUsers.toString(),
                    Icons.people, AppTheme.successGreen),
                _buildStatItem('Inactive Users', inactiveUsers.toString(),
                    Icons.person_off, AppTheme.textSecondary),
                _buildStatItem('Projects', _projects.length.toString(),
                    Icons.business, AppTheme.primaryIndigo),
              ],
            ),
            const SizedBox(height: AppTheme.spacingM),
            Row(
              children: [
                _buildStatItem('Voice Notes', _voiceNoteCount.toString(),
                    Icons.mic, AppTheme.infoBlue),
                _buildStatItem('Action Items', _actionItemCount.toString(),
                    Icons.checklist, AppTheme.accentAmber),
                const Expanded(child: SizedBox()),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(
      String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(AppTheme.spacingM),
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppTheme.radiusM),
        ),
        child: Column(
          children: [
            Icon(icon, size: 24, color: color),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: AppTheme.bodySmall.copyWith(
                color: AppTheme.textSecondary,
                fontSize: 11,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUsersSection() {
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
                Text('Team Members', style: AppTheme.headingSmall),
                const Spacer(),
                Text(
                  '${_users.length} total',
                  style: AppTheme.bodySmall
                      .copyWith(color: AppTheme.textSecondary),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spacingM),
            if (_users.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(AppTheme.spacingL),
                  child: Text(
                    'No users found',
                    style: AppTheme.bodySmall,
                  ),
                ),
              )
            else
              ..._users.map((user) => _buildUserRow(user)),
          ],
        ),
      ),
    );
  }

  Widget _buildUserRow(Map<String, dynamic> user) {
    final email = user['email']?.toString() ?? 'Unknown';
    final fullName = user['full_name']?.toString();
    final role = user['role']?.toString() ?? 'worker';
    final status = user['status']?.toString() ?? 'active';
    final isPrimary = user['is_primary'] == true;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          // Status dot
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: status == 'active'
                  ? AppTheme.successGreen
                  : status == 'removed'
                      ? AppTheme.errorRed
                      : AppTheme.textSecondary,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: AppTheme.spacingS),

          // User info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fullName ?? email,
                  style: AppTheme.bodyMedium.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (fullName != null)
                  Text(
                    email,
                    style: AppTheme.bodySmall
                        .copyWith(color: AppTheme.textSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),

          // Role badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: AppTheme.primaryIndigo.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              role.toUpperCase(),
              style: const TextStyle(
                color: AppTheme.primaryIndigo,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          if (isPrimary) ...[
            const SizedBox(width: 4),
            const Icon(Icons.star, size: 16, color: AppTheme.accentAmber),
          ],

          // Status badge for non-active
          if (status != 'active') ...[
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: status == 'removed'
                    ? AppTheme.errorRed.withValues(alpha: 0.1)
                    : AppTheme.textSecondary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                status.toUpperCase(),
                style: TextStyle(
                  color: status == 'removed'
                      ? AppTheme.errorRed
                      : AppTheme.textSecondary,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildProjectsSection() {
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
                Text('Projects', style: AppTheme.headingSmall),
                const Spacer(),
                Text(
                  '${_projects.length} total',
                  style: AppTheme.bodySmall
                      .copyWith(color: AppTheme.textSecondary),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spacingM),
            if (_projects.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(AppTheme.spacingL),
                  child: Text(
                    'No projects found',
                    style: AppTheme.bodySmall,
                  ),
                ),
              )
            else
              ..._projects.map((project) => _buildProjectRow(project)),
          ],
        ),
      ),
    );
  }

  Widget _buildProjectRow(Map<String, dynamic> project) {
    final name = project['name']?.toString() ?? 'Unknown';
    final address = project['address']?.toString();
    final createdAt = project['created_at'] != null
        ? DateTime.tryParse(project['created_at'].toString())
        : null;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          const Icon(Icons.business, size: 20, color: AppTheme.primaryIndigo),
          const SizedBox(width: AppTheme.spacingS),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: AppTheme.bodyMedium
                      .copyWith(fontWeight: FontWeight.w500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (address != null)
                  Text(
                    address,
                    style: AppTheme.bodySmall
                        .copyWith(color: AppTheme.textSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          if (createdAt != null)
            Text(
              DateFormat('MMM d, yyyy').format(createdAt),
              style:
                  AppTheme.bodySmall.copyWith(color: AppTheme.textSecondary),
            ),
        ],
      ),
    );
  }

  Widget _buildProviderRow(String provider) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppTheme.radiusS),
      onTap: () => _showChangeProviderDialog(provider),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            const Icon(Icons.record_voice_over,
                size: 18, color: AppTheme.textSecondary),
            const SizedBox(width: AppTheme.spacingS),
            Text(
              'Transcription: ',
              style: AppTheme.bodySmall.copyWith(
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
            Expanded(
              child: Text(
                _getProviderLabel(provider),
                style: AppTheme.bodySmall.copyWith(
                  color: AppTheme.primaryIndigo,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const Icon(Icons.edit,
                size: 16, color: AppTheme.primaryIndigo),
          ],
        ),
      ),
    );
  }

  Future<void> _showChangeProviderDialog(String currentProvider) async {
    String selectedProvider = currentProvider;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Change AI Provider'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Select the AI provider for voice note transcription, translation, and classification.',
                style: AppTheme.bodySmall,
              ),
              const SizedBox(height: AppTheme.spacingL),
              ...['groq', 'openai', 'gemini'].map((provider) {
                final isSelected = selectedProvider == provider;
                return RadioListTile<String>(
                  title: Text(
                    _getProviderLabel(provider),
                    style: TextStyle(
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                  subtitle: Text(
                    _getProviderDescription(provider),
                    style: const TextStyle(fontSize: 12),
                  ),
                  value: provider,
                  groupValue: selectedProvider,
                  activeColor: AppTheme.primaryIndigo,
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => selectedProvider = value);
                    }
                  },
                );
              }),
              const SizedBox(height: AppTheme.spacingS),
              Container(
                padding: const EdgeInsets.all(AppTheme.spacingM),
                decoration: BoxDecoration(
                  color: AppTheme.warningOrange.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(AppTheme.radiusM),
                  border: Border.all(
                    color: AppTheme.warningOrange.withValues(alpha: 0.3),
                  ),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline,
                        color: AppTheme.warningOrange, size: 18),
                    SizedBox(width: AppTheme.spacingS),
                    Expanded(
                      child: Text(
                        'Changes apply to all future voice notes for this company.',
                        style: TextStyle(fontSize: 12, color: AppTheme.warningOrange),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: selectedProvider == currentProvider
                  ? null
                  : () => Navigator.pop(context, true),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true && selectedProvider != currentProvider && mounted) {
      try {
        await _supabase.from('accounts').update({
          'transcription_provider': selectedProvider,
        }).eq('id', widget.accountId);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'Provider changed to ${_getProviderLabel(selectedProvider)}'),
              backgroundColor: AppTheme.successGreen,
            ),
          );
          _loadData(); // Refresh to show updated provider
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not update provider. Please try again.'),
              backgroundColor: AppTheme.errorRed,
            ),
          );
        }
      }
    }
  }

  String _getProviderDescription(String provider) {
    switch (provider) {
      case 'groq':
        return 'Fast, free tier available. Uses Whisper Large V3.';
      case 'openai':
        return 'High accuracy, paid. Uses Whisper + GPT-4o Mini.';
      case 'gemini':
        return 'Google AI. Uses Gemini 1.5 Flash multimodal.';
      default:
        return '';
    }
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppTheme.textSecondary),
        const SizedBox(width: AppTheme.spacingS),
        Text(
          '$label: ',
          style: AppTheme.bodySmall.copyWith(
            color: AppTheme.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: AppTheme.bodySmall.copyWith(
              color: AppTheme.textPrimary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusChip(String status) {
    Color bgColor;
    Color textColor;

    switch (status) {
      case 'active':
        bgColor = AppTheme.successGreen.withValues(alpha: 0.1);
        textColor = AppTheme.successGreen;
        break;
      case 'inactive':
        bgColor = AppTheme.textSecondary.withValues(alpha: 0.1);
        textColor = AppTheme.textSecondary;
        break;
      case 'archived':
        bgColor = AppTheme.warningOrange.withValues(alpha: 0.1);
        textColor = AppTheme.warningOrange;
        break;
      default:
        bgColor = AppTheme.textSecondary.withValues(alpha: 0.1);
        textColor = AppTheme.textSecondary;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: textColor,
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  String _getProviderLabel(String provider) {
    switch (provider) {
      case 'groq':
        return 'Groq Whisper (Free)';
      case 'openai':
        return 'OpenAI Whisper (Paid)';
      case 'gemini':
        return 'Gemini Flash (Google)';
      default:
        return provider;
    }
  }
}
