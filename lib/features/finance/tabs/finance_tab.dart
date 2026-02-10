import 'package:flutter/material.dart';
import 'package:houzzdat_app/core/theme/app_theme.dart';
import 'package:houzzdat_app/core/widgets/shared_widgets.dart';
import 'package:houzzdat_app/features/finance/widgets/site_finances_subtab.dart';
import 'package:houzzdat_app/features/finance/widgets/owner_finances_subtab.dart';

/// Finance tab with two sub-tabs: SITE FINANCES and OWNER FINANCES.
/// Follows the same sub-tab pattern as ProjectsTab (Sites + Attendance).
class FinanceTab extends StatefulWidget {
  final String? accountId;
  const FinanceTab({super.key, required this.accountId});

  @override
  State<FinanceTab> createState() => _FinanceTabState();
}

class _FinanceTabState extends State<FinanceTab>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.accountId == null || widget.accountId!.isEmpty) {
      return const LoadingWidget();
    }

    return Column(
      children: [
        // Sub-tab bar
        Container(
          color: Colors.white,
          child: TabBar(
            controller: _tabController,
            labelColor: AppTheme.primaryIndigo,
            unselectedLabelColor: AppTheme.textSecondary,
            indicatorColor: AppTheme.primaryIndigo,
            indicatorWeight: 3,
            labelStyle: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
            unselectedLabelStyle: const TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 13,
            ),
            tabs: const [
              Tab(text: 'SITE FINANCES'),
              Tab(text: 'OWNER FINANCES'),
            ],
          ),
        ),
        const Divider(height: 1, thickness: 1, color: Color(0xFFE0E0E0)),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              SiteFinancesSubtab(accountId: widget.accountId!),
              OwnerFinancesSubtab(accountId: widget.accountId!),
            ],
          ),
        ),
      ],
    );
  }
}
