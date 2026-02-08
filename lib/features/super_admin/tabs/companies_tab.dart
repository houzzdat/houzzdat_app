import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:houzzdat_app/core/theme/app_theme.dart';
import 'package:houzzdat_app/features/super_admin/widgets/company_card_widget.dart';
import 'package:houzzdat_app/features/super_admin/screens/company_detail_screen.dart';

/// Tab displaying all companies with status filtering and management actions.
/// Uses a FutureBuilder with manual refresh instead of stream (since Realtime
/// may not be enabled on the accounts table).
class CompaniesTab extends StatefulWidget {
  const CompaniesTab({super.key});

  @override
  State<CompaniesTab> createState() => CompaniesTabState();
}

class CompaniesTabState extends State<CompaniesTab> {
  final _supabase = Supabase.instance.client;
  String _statusFilter = 'all';
  bool _isLoading = true;
  List<Map<String, dynamic>> _companies = [];
  Map<String, int> _userCounts = {};
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadCompanies();
  }

  /// Public method to trigger a refresh from the parent widget.
  void refresh() => _loadCompanies();

  /// Fetch all companies from the accounts table.
  Future<void> _loadCompanies() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await _supabase
          .from('accounts')
          .select()
          .order('company_name', ascending: true);

      final companies = List<Map<String, dynamic>>.from(result);

      // Fetch user counts for each company
      final userCounts = <String, int>{};
      for (final company in companies) {
        final accountId = company['id']?.toString();
        if (accountId != null) {
          try {
            final users = await _supabase
                .from('users')
                .select('id')
                .eq('account_id', accountId);
            userCounts[accountId] = (users as List).length;
          } catch (e) {
            userCounts[accountId] = 0;
          }
        }
      }

      if (mounted) {
        setState(() {
          _companies = companies;
          _userCounts = userCounts;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading companies: $e');
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  /// Filter companies by status.
  /// Note: Existing companies may not have a 'status' column if the migration
  /// hasn't been run yet — treat null status as 'active' (the default).
  List<Map<String, dynamic>> _getFilteredCompanies() {
    if (_statusFilter == 'all') return _companies;
    return _companies.where((c) {
      final status = c['status']?.toString() ?? 'active';
      return status == _statusFilter;
    }).toList();
  }

  Future<void> _handleDeactivateCompany(Map<String, dynamic> company) async {
    final companyName = company['company_name'] ?? 'Company';

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.pause_circle,
                color: AppTheme.warningOrange, size: 28),
            const SizedBox(width: AppTheme.spacingS),
            const Expanded(child: Text('Deactivate Company?')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RichText(
              text: TextSpan(
                style:
                    AppTheme.bodyMedium.copyWith(color: AppTheme.textPrimary),
                children: [
                  TextSpan(
                    text: companyName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const TextSpan(
                    text: ' will be deactivated.',
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppTheme.spacingM),
            Container(
              padding: const EdgeInsets.all(AppTheme.spacingM),
              decoration: BoxDecoration(
                color: AppTheme.backgroundGrey,
                borderRadius: BorderRadius.circular(AppTheme.radiusM),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInfoRow(Icons.warning, AppTheme.warningOrange,
                      'All users will lose access'),
                  const SizedBox(height: AppTheme.spacingS),
                  _buildInfoRow(Icons.check_circle, AppTheme.successGreen,
                      'All data will be preserved'),
                  const SizedBox(height: AppTheme.spacingS),
                  _buildInfoRow(Icons.check_circle, AppTheme.successGreen,
                      'Can be reactivated anytime'),
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
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.warningOrange,
              foregroundColor: Colors.white,
            ),
            child: const Text('Deactivate'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _invokeCompanyAction('deactivate', company);
    }
  }

  Future<void> _handleActivateCompany(Map<String, dynamic> company) async {
    final companyName = company['company_name'] ?? 'Company';

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.play_circle,
                color: AppTheme.successGreen, size: 28),
            const SizedBox(width: AppTheme.spacingS),
            const Text('Activate Company?'),
          ],
        ),
        content: RichText(
          text: TextSpan(
            style: AppTheme.bodyMedium.copyWith(color: AppTheme.textPrimary),
            children: [
              TextSpan(
                text: companyName,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const TextSpan(
                text:
                    ' will be reactivated. All previously active users will regain access.',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.successGreen,
              foregroundColor: Colors.white,
            ),
            child: const Text('Activate'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _invokeCompanyAction('activate', company);
    }
  }

  Future<void> _handleArchiveCompany(Map<String, dynamic> company) async {
    final companyName = company['company_name'] ?? 'Company';

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.archive, color: AppTheme.errorRed, size: 28),
            const SizedBox(width: AppTheme.spacingS),
            const Expanded(child: Text('Archive Company?')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RichText(
              text: TextSpan(
                style:
                    AppTheme.bodyMedium.copyWith(color: AppTheme.textPrimary),
                children: [
                  TextSpan(
                    text: companyName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const TextSpan(
                    text: ' will be permanently archived.',
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppTheme.spacingM),
            Container(
              padding: const EdgeInsets.all(AppTheme.spacingM),
              decoration: BoxDecoration(
                color: AppTheme.errorRed.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(AppTheme.radiusM),
                border: Border.all(
                  color: AppTheme.errorRed.withValues(alpha: 0.2),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInfoRow(Icons.warning, AppTheme.errorRed,
                      'This action cannot be undone'),
                  const SizedBox(height: AppTheme.spacingS),
                  _buildInfoRow(Icons.check_circle, AppTheme.successGreen,
                      'All data is preserved for viewing'),
                  const SizedBox(height: AppTheme.spacingS),
                  _buildInfoRow(Icons.info, AppTheme.infoBlue,
                      'Company becomes read-only'),
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
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorRed,
              foregroundColor: Colors.white,
            ),
            child: const Text('Archive'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _invokeCompanyAction('archive', company);
    }
  }

  Future<void> _invokeCompanyAction(
      String action, Map<String, dynamic> company) async {
    try {
      final response = await _supabase.functions.invoke(
        'manage-company-status',
        body: {
          'action': action,
          'account_id': company['id'],
          'actor_id': _supabase.auth.currentUser!.id,
        },
      );

      if (response.status == 200 && mounted) {
        final message =
            response.data?['message'] ?? 'Action completed successfully';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: AppTheme.successGreen,
          ),
        );
        // Refresh the list after action
        _loadCompanies();
      } else if (mounted) {
        final error = response.data?['error'] ?? 'Failed to $action company';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $error'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    }
  }

  void _navigateToDetails(Map<String, dynamic> company) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CompanyDetailScreen(
          accountId: company['id'],
          companyName: company['company_name'] ?? 'Company',
          status: company['status'] ?? 'active',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Filter chips
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spacingM,
            vertical: AppTheme.spacingS,
          ),
          child: Row(
            children: [
              _buildFilterChip('All', 'all'),
              const SizedBox(width: AppTheme.spacingS),
              _buildFilterChip('Active', 'active'),
              const SizedBox(width: AppTheme.spacingS),
              _buildFilterChip('Inactive', 'inactive'),
              const SizedBox(width: AppTheme.spacingS),
              _buildFilterChip('Archived', 'archived'),
            ],
          ),
        ),
        const Divider(height: 1),

        // Company list
        Expanded(
          child: _buildBody(),
        ),
      ],
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: AppTheme.primaryIndigo),
            SizedBox(height: AppTheme.spacingM),
            Text('Loading companies...', style: AppTheme.bodySmall),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingL),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline,
                  size: 48, color: AppTheme.errorRed),
              const SizedBox(height: AppTheme.spacingM),
              Text(
                'Error loading companies',
                style: AppTheme.headingSmall,
              ),
              const SizedBox(height: AppTheme.spacingS),
              Text(
                _errorMessage!,
                style: AppTheme.bodySmall
                    .copyWith(color: AppTheme.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppTheme.spacingL),
              ElevatedButton.icon(
                onPressed: _loadCompanies,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final companies = _getFilteredCompanies();

    if (companies.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingL),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.business,
                  size: 48,
                  color: AppTheme.textSecondary.withValues(alpha: 0.5)),
              const SizedBox(height: AppTheme.spacingM),
              Text(
                _statusFilter == 'all'
                    ? 'No companies found'
                    : 'No $_statusFilter companies',
                style: AppTheme.headingSmall,
              ),
              const SizedBox(height: AppTheme.spacingS),
              Text(
                _statusFilter == 'all'
                    ? 'Onboard a new company using the Onboard tab'
                    : 'No companies with $_statusFilter status',
                style: AppTheme.bodySmall
                    .copyWith(color: AppTheme.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadCompanies,
      child: ListView.builder(
        padding: const EdgeInsets.all(AppTheme.spacingM),
        itemCount: companies.length,
        itemBuilder: (context, index) {
          final company = companies[index];
          final status = company['status']?.toString() ?? 'active';
          final accountId = company['id']?.toString() ?? '';

          return CompanyCardWidget(
            company: company,
            userCount: _userCounts[accountId] ?? 0,
            onViewDetails: () => _navigateToDetails(company),
            onDeactivate: status == 'active'
                ? () => _handleDeactivateCompany(company)
                : null,
            onActivate: status == 'inactive'
                ? () => _handleActivateCompany(company)
                : null,
            onArchive: status != 'archived'
                ? () => _handleArchiveCompany(company)
                : null,
          );
        },
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _statusFilter == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() => _statusFilter = selected ? value : 'all');
      },
      selectedColor: AppTheme.primaryIndigo.withValues(alpha: 0.15),
      checkmarkColor: AppTheme.primaryIndigo,
      labelStyle: TextStyle(
        color: isSelected ? AppTheme.primaryIndigo : AppTheme.textSecondary,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        fontSize: 13,
      ),
      side: BorderSide(
        color: isSelected
            ? AppTheme.primaryIndigo
            : AppTheme.textSecondary.withValues(alpha: 0.3),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, Color color, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: AppTheme.spacingS),
        Expanded(
          child: Text(
            text,
            style: AppTheme.bodySmall.copyWith(color: AppTheme.textPrimary),
          ),
        ),
      ],
    );
  }
}
