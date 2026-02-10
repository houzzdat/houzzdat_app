import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:houzzdat_app/core/theme/app_theme.dart';
import 'package:houzzdat_app/core/services/company_context_service.dart';
import 'package:houzzdat_app/core/widgets/shared_widgets.dart';

/// Screen shown when a user belongs to multiple companies.
/// Allows selecting which company to work in for this session.
class CompanySelectorScreen extends StatefulWidget {
  const CompanySelectorScreen({super.key});

  @override
  State<CompanySelectorScreen> createState() => _CompanySelectorScreenState();
}

class _CompanySelectorScreenState extends State<CompanySelectorScreen> {
  final _companyService = CompanyContextService();
  bool _isSelecting = false;
  String? _selectedAccountId;

  Future<void> _selectCompany(CompanyAssociation company) async {
    if (_isSelecting) return;

    setState(() {
      _isSelecting = true;
      _selectedAccountId = company.accountId;
    });

    try {
      await _companyService.switchCompany(company.accountId);

      // Navigate back to AuthWrapper which will now route to the correct dashboard
      if (mounted) {
        // Force rebuild by triggering a state change in the auth stream
        // The AuthWrapper's FutureBuilder will re-resolve with the saved selection
        Navigator.of(context).pushNamedAndRemoveUntil('/', (_) => false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSelecting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not switch company. Please try again.'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    }
  }

  Future<void> _handleLogout() async {
    await _companyService.reset();
    await Supabase.instance.client.auth.signOut();
  }

  Color _getRoleColor(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
      case 'manager':
        return AppTheme.infoBlue;
      case 'owner':
        return AppTheme.accentAmber;
      case 'worker':
        return AppTheme.primaryIndigo;
      default:
        return AppTheme.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final companies = _companyService.activeCompanies;

    return Scaffold(
      backgroundColor: AppTheme.backgroundGrey,
      appBar: AppBar(
        title: const Text('Select Company'),
        backgroundColor: AppTheme.primaryIndigo,
        foregroundColor: AppTheme.textOnPrimary,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _handleLogout,
            tooltip: 'Logout',
          ),
        ],
      ),
      body: companies.isEmpty
          ? const EmptyStateWidget(
              icon: Icons.business_outlined,
              title: 'No companies found',
              subtitle: 'Contact your administrator to be added to a company.',
            )
          : Padding(
              padding: const EdgeInsets.all(AppTheme.spacingL),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Choose a company to continue',
                    style: AppTheme.headingMedium.copyWith(
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacingS),
                  Text(
                    'You belong to ${companies.length} companies. Select one to access its dashboard.',
                    style: AppTheme.bodyMedium.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacingXL),
                  Expanded(
                    child: ListView.separated(
                      itemCount: companies.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: AppTheme.spacingM),
                      itemBuilder: (context, index) {
                        final company = companies[index];
                        final isSelected =
                            _selectedAccountId == company.accountId;
                        final roleColor = _getRoleColor(company.role);

                        return GestureDetector(
                          onTap: () => _selectCompany(company),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius:
                                  BorderRadius.circular(AppTheme.radiusXL),
                              border: Border.all(
                                color: isSelected
                                    ? AppTheme.primaryIndigo
                                    : Colors.black.withValues(alpha: 0.05),
                                width: isSelected ? 2 : 1,
                              ),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: AppTheme.primaryIndigo
                                            .withValues(alpha: 0.15),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(AppTheme.spacingL),
                              child: Row(
                                children: [
                                  // Company Icon
                                  CircleAvatar(
                                    radius: 28,
                                    backgroundColor: AppTheme.primaryIndigo
                                        .withValues(alpha: 0.1),
                                    child: Text(
                                      company.companyName.isNotEmpty
                                          ? company.companyName[0].toUpperCase()
                                          : '?',
                                      style: TextStyle(
                                        color: AppTheme.primaryIndigo,
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: AppTheme.spacingM),
                                  // Company Details
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          company.companyName,
                                          style: AppTheme.bodyLarge.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            CategoryBadge(
                                              text:
                                                  company.role.toUpperCase(),
                                              color: roleColor,
                                            ),
                                            if (company.isPrimary) ...[
                                              const SizedBox(
                                                  width: AppTheme.spacingS),
                                              const CategoryBadge(
                                                text: 'PRIMARY',
                                                color: AppTheme.successGreen,
                                                icon: Icons.star,
                                              ),
                                            ],
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Selection indicator
                                  if (isSelected && _isSelecting)
                                    const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  else
                                    Icon(
                                      Icons.arrow_forward_ios,
                                      size: 18,
                                      color: AppTheme.textSecondary,
                                    ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
