import 'package:flutter/material.dart';
import 'package:houzzdat_app/core/theme/app_theme.dart';
import 'package:houzzdat_app/core/widgets/shared_widgets.dart';
import 'package:houzzdat_app/features/insights/services/project_state_agent.dart';
import 'package:houzzdat_app/features/insights/services/financial_state_agent.dart';
import 'package:houzzdat_app/features/insights/services/material_state_agent.dart';
import 'package:houzzdat_app/features/insights/models/project_state.dart';
import 'package:houzzdat_app/features/insights/models/financial_state.dart';
import 'package:houzzdat_app/features/insights/models/material_state.dart';
import 'package:houzzdat_app/features/insights/widgets/project_health_card.dart';
import 'package:houzzdat_app/features/insights/widgets/financial_position_card.dart';
import 'package:houzzdat_app/features/insights/widgets/material_pipeline_card.dart';
import 'package:houzzdat_app/features/insights/screens/plan_setup_screen.dart';
import 'package:houzzdat_app/core/widgets/page_transitions.dart';
import 'package:houzzdat_app/features/insights/widgets/project_health_detail.dart';
import 'package:houzzdat_app/features/insights/widgets/financial_position_detail.dart';
import 'package:houzzdat_app/features/insights/widgets/material_pipeline_detail.dart';
import 'package:houzzdat_app/features/insights/widgets/review_tab_content.dart';
import 'package:houzzdat_app/features/insights/services/review_queue_service.dart';
import 'package:houzzdat_app/features/milestones/widgets/milestone_tab_content.dart';

/// Embedded tab body for Insights — no Scaffold/AppBar, used inside the
/// manager dashboard's IndexedStack so the bottom nav stays persistent.
class InsightsTabBody extends StatefulWidget {
  final String accountId;

  const InsightsTabBody({super.key, required this.accountId});

  @override
  State<InsightsTabBody> createState() => _InsightsTabBodyState();
}

class _InsightsTabBodyState extends State<InsightsTabBody>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final _projectAgent = ProjectStateAgent();

  final _financialAgent = FinancialStateAgent();
  final _materialAgent = MaterialStateAgent();

  List<ProjectHealthState>? _projectStates;
  List<FinancialPosition>? _financialPositions;
  List<MaterialPipeline>? _materialPipelines;

  bool _loadingProjects = true;
  bool _loadingFinances = true;
  bool _loadingMaterials = true;

  int _reviewBadgeCount = 0;

  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _tabController.addListener(_onTabChanged);
    _loadProjectData();
    _loadReviewBadgeCount();
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging) {
      switch (_tabController.index) {
        case 0:
          if (_projectStates == null) _loadProjectData();
          break;
        case 1:
          if (_financialPositions == null) _loadFinancialData();
          break;
        case 2:
          if (_materialPipelines == null) _loadMaterialData();
          break;
      }
    }
  }

  Future<void> _loadReviewBadgeCount() async {
    try {
      final count = await ReviewQueueService().getUnreviewedCount(widget.accountId);
      if (mounted) setState(() => _reviewBadgeCount = count);
    } catch (e) {
      debugPrint('Error loading review badge count: $e');
    }
  }

  Future<void> _loadProjectData() async {
    setState(() => _loadingProjects = true);
    try {
      debugPrint('[Insights] Loading projects for accountId=${widget.accountId}');
      final states = await _projectAgent.computeAllProjects(widget.accountId);
      debugPrint('[Insights] Got ${states.length} project(s)');
      if (mounted) setState(() { _projectStates = states; _loadingProjects = false; });
    } catch (e) {
      debugPrint('[Insights] Error loading project insights: $e');
      if (mounted) setState(() { _error = e.toString(); _loadingProjects = false; });
    }
  }

  Future<void> _loadFinancialData() async {
    setState(() => _loadingFinances = true);
    try {
      final positions = await _financialAgent.computeAllProjects(widget.accountId);
      if (mounted) setState(() { _financialPositions = positions; _loadingFinances = false; });
    } catch (e) {
      debugPrint('Error loading financial insights: $e');
      if (mounted) setState(() { _loadingFinances = false; });
    }
  }

  Future<void> _loadMaterialData() async {
    setState(() => _loadingMaterials = true);
    try {
      final pipelines = await _materialAgent.computeAllProjects(widget.accountId);
      if (mounted) setState(() { _materialPipelines = pipelines; _loadingMaterials = false; });
    } catch (e) {
      debugPrint('Error loading material insights: $e');
      if (mounted) setState(() { _loadingMaterials = false; });
    }
  }

  Future<void> _refreshAll() async {
    switch (_tabController.index) {
      case 0: await _loadProjectData(); break;
      case 1: await _loadFinancialData(); break;
      case 2: await _loadMaterialData(); break;
      case 3: await _loadReviewBadgeCount(); break;
    }
  }

  void _navigateToPlanSetup(String projectId, String projectName) {
    Navigator.of(context).push(
      FadeSlideRoute(
        page: PlanSetupScreen(
          accountId: widget.accountId,
          projectId: projectId,
          projectName: projectName,
        ),
      ),
    ).then((_) => _refreshAll());
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Insights tab header — styled to match the AppBar colour
        Material(
          color: AppTheme.primaryIndigo,
          child: TabBar(
            controller: _tabController,
            indicatorColor: AppTheme.accentAmber,
            indicatorWeight: 3,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white60,
            labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            tabs: [
              const Tab(text: 'PROJECT HEALTH'),
              const Tab(text: 'FINANCES'),
              const Tab(text: 'MATERIALS'),
              Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('REVIEW'),
                    if (_reviewBadgeCount > 0) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppTheme.accentAmber,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          _reviewBadgeCount > 99 ? '99+' : '$_reviewBadgeCount',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const Tab(text: 'MILESTONES'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildProjectHealthTab(),
              _buildFinancesTab(),
              _buildMaterialsTab(),
              ReviewTabContent(
                accountId: widget.accountId,
                onCountChanged: _loadReviewBadgeCount,
              ),
              MilestoneTabContent(accountId: widget.accountId),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProjectHealthTab() {
    if (_loadingProjects) return const ShimmerLoadingList();
    if (_error != null) {
      return _buildEmptyState('Error: $_error', Icons.error_outline);
    }
    if (_projectStates == null || _projectStates!.isEmpty) {
      return _buildEmptyState('No projects found', Icons.business);
    }
    return RefreshIndicator(
      onRefresh: _loadProjectData,
      child: ListView.builder(
        padding: const EdgeInsets.only(top: 8, bottom: 96),
        itemCount: _projectStates!.length,
        itemBuilder: (context, index) {
          final state = _projectStates![index];
          return ProjectHealthCard(
            state: state,
            onTap: () {
              Navigator.of(context).push(FadeSlideRoute(
                page: ProjectHealthDetail(
                  state: state,
                  onSetupPlan: state.hasPlan
                      ? null
                      : () => _navigateToPlanSetup(state.projectId, state.projectName),
                ),
              ));
            },
            onSetupPlan: state.hasPlan
                ? null
                : () => _navigateToPlanSetup(state.projectId, state.projectName),
          );
        },
      ),
    );
  }

  Widget _buildFinancesTab() {
    if (_loadingFinances) return const ShimmerLoadingList();
    if (_financialPositions == null || _financialPositions!.isEmpty) {
      return _buildEmptyState('No financial data', Icons.account_balance);
    }
    return RefreshIndicator(
      onRefresh: _loadFinancialData,
      child: ListView.builder(
        padding: const EdgeInsets.only(top: 8, bottom: 96),
        itemCount: _financialPositions!.length,
        itemBuilder: (context, index) {
          final state = _financialPositions![index];
          return FinancialPositionCard(
            state: state,
            onTap: () {
              Navigator.of(context).push(FadeSlideRoute(
                page: FinancialPositionDetail(state: state),
              ));
            },
          );
        },
      ),
    );
  }

  Widget _buildMaterialsTab() {
    if (_loadingMaterials) return const ShimmerLoadingList();
    if (_materialPipelines == null || _materialPipelines!.isEmpty) {
      return _buildEmptyState('No material data', Icons.inventory_2);
    }
    return RefreshIndicator(
      onRefresh: _loadMaterialData,
      child: ListView.builder(
        padding: const EdgeInsets.only(top: 8, bottom: 96),
        itemCount: _materialPipelines!.length,
        itemBuilder: (context, index) {
          final state = _materialPipelines![index];
          return MaterialPipelineCard(
            state: state,
            onTap: () {
              Navigator.of(context).push(FadeSlideRoute(
                page: MaterialPipelineDetail(state: state),
              ));
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(String message, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: AppTheme.textSecondary),
          const SizedBox(height: 16),
          Text(message, style: AppTheme.headingMedium.copyWith(color: AppTheme.textSecondary)),
        ],
      ),
    );
  }
}

/// Standalone Insights screen (used when pushed as a full-screen route).
class InsightsScreen extends StatefulWidget {
  final String accountId;

  const InsightsScreen({super.key, required this.accountId});

  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final _projectAgent = ProjectStateAgent();
  final _financialAgent = FinancialStateAgent();
  final _materialAgent = MaterialStateAgent();

  List<ProjectHealthState>? _projectStates;
  List<FinancialPosition>? _financialPositions;
  List<MaterialPipeline>? _materialPipelines;

  bool _loadingProjects = true;
  bool _loadingFinances = true;
  bool _loadingMaterials = true;

  int _reviewBadgeCount = 0;

  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _tabController.addListener(_onTabChanged);
    _loadProjectData();
    _loadReviewBadgeCount();
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging) {
      switch (_tabController.index) {
        case 0:
          if (_projectStates == null) _loadProjectData();
          break;
        case 1:
          if (_financialPositions == null) _loadFinancialData();
          break;
        case 2:
          if (_materialPipelines == null) _loadMaterialData();
          break;
        // case 3 (Review) is handled by its own stateful widget
      }
    }
  }

  Future<void> _loadReviewBadgeCount() async {
    try {
      final count = await ReviewQueueService().getUnreviewedCount(widget.accountId);
      if (mounted) setState(() => _reviewBadgeCount = count);
    } catch (e) {
      debugPrint('Error loading review badge count: $e');
    }
  }

  Future<void> _loadProjectData() async {
    setState(() => _loadingProjects = true);
    try {
      debugPrint('[Insights] Loading projects for accountId=${widget.accountId}');
      final states = await _projectAgent.computeAllProjects(widget.accountId);
      debugPrint('[Insights] Got ${states.length} project(s)');
      if (mounted) setState(() { _projectStates = states; _loadingProjects = false; });
    } catch (e) {
      debugPrint('[Insights] Error loading project insights: $e');
      if (mounted) setState(() { _error = e.toString(); _loadingProjects = false; });
    }
  }

  Future<void> _loadFinancialData() async {
    setState(() => _loadingFinances = true);
    try {
      final positions = await _financialAgent.computeAllProjects(widget.accountId);
      if (mounted) setState(() { _financialPositions = positions; _loadingFinances = false; });
    } catch (e) {
      debugPrint('Error loading financial insights: $e');
      if (mounted) setState(() { _loadingFinances = false; });
    }
  }

  Future<void> _loadMaterialData() async {
    setState(() => _loadingMaterials = true);
    try {
      final pipelines = await _materialAgent.computeAllProjects(widget.accountId);
      if (mounted) setState(() { _materialPipelines = pipelines; _loadingMaterials = false; });
    } catch (e) {
      debugPrint('Error loading material insights: $e');
      if (mounted) setState(() { _loadingMaterials = false; });
    }
  }

  Future<void> _refreshAll() async {
    switch (_tabController.index) {
      case 0:
        await _loadProjectData();
        break;
      case 1:
        await _loadFinancialData();
        break;
      case 2:
        await _loadMaterialData();
        break;
      case 3:
        await _loadReviewBadgeCount();
        break;
    }
  }

  void _navigateToPlanSetup(String projectId, String projectName) {
    Navigator.of(context).push(
      FadeSlideRoute(
        page: PlanSetupScreen(
          accountId: widget.accountId,
          projectId: projectId,
          projectName: projectName,
        ),
      ),
    ).then((_) => _refreshAll());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('INSIGHTS', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        backgroundColor: AppTheme.primaryIndigo,
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.accentAmber,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          tabs: [
            const Tab(text: 'PROJECT HEALTH'),
            const Tab(text: 'FINANCES'),
            const Tab(text: 'MATERIALS'),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('REVIEW'),
                  if (_reviewBadgeCount > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: AppTheme.accentAmber,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        _reviewBadgeCount > 99 ? '99+' : '$_reviewBadgeCount',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
              const Tab(text: 'MILESTONES'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildProjectHealthTab(),
          _buildFinancesTab(),
          _buildMaterialsTab(),
          ReviewTabContent(
            accountId: widget.accountId,
            onCountChanged: _loadReviewBadgeCount,
          ),
          MilestoneTabContent(accountId: widget.accountId),
        ],
      ),
    );
  }

  Widget _buildProjectHealthTab() {
    if (_loadingProjects) {
      return const ShimmerLoadingList(); // UX-audit #4: shimmer instead of spinner
    }

    if (_error != null) {
      return _buildEmptyState('Error: $_error', Icons.error_outline);
    }

    if (_projectStates == null || _projectStates!.isEmpty) {
      return _buildEmptyState('No projects found', Icons.business);
    }

    return RefreshIndicator(
      onRefresh: _loadProjectData,
      child: ListView.builder(
        padding: const EdgeInsets.only(top: 8, bottom: 24),
        itemCount: _projectStates!.length,
        itemBuilder: (context, index) {
          final state = _projectStates![index];
          return ProjectHealthCard(
            state: state,
            onTap: () {
              Navigator.of(context).push(FadeSlideRoute(
                page: ProjectHealthDetail(
                  state: state,
                  onSetupPlan: state.hasPlan
                      ? null
                      : () => _navigateToPlanSetup(state.projectId, state.projectName),
                ),
              ));
            },
            onSetupPlan: state.hasPlan
                ? null
                : () => _navigateToPlanSetup(state.projectId, state.projectName),
          );
        },
      ),
    );
  }

  Widget _buildFinancesTab() {
    if (_loadingFinances) {
      return const ShimmerLoadingList(); // UX-audit #4: shimmer instead of spinner
    }

    if (_financialPositions == null || _financialPositions!.isEmpty) {
      return _buildEmptyState('No financial data', Icons.account_balance);
    }

    return RefreshIndicator(
      onRefresh: _loadFinancialData,
      child: ListView.builder(
        padding: const EdgeInsets.only(top: 8, bottom: 24),
        itemCount: _financialPositions!.length,
        itemBuilder: (context, index) {
          final state = _financialPositions![index];
          return FinancialPositionCard(
            state: state,
            onTap: () {
              Navigator.of(context).push(FadeSlideRoute(
                page: FinancialPositionDetail(state: state),
              ));
            },
          );
        },
      ),
    );
  }

  Widget _buildMaterialsTab() {
    if (_loadingMaterials) {
      return const ShimmerLoadingList(); // UX-audit #4: shimmer instead of spinner
    }

    if (_materialPipelines == null || _materialPipelines!.isEmpty) {
      return _buildEmptyState('No material data', Icons.inventory_2);
    }

    return RefreshIndicator(
      onRefresh: _loadMaterialData,
      child: ListView.builder(
        padding: const EdgeInsets.only(top: 8, bottom: 24),
        itemCount: _materialPipelines!.length,
        itemBuilder: (context, index) {
          final state = _materialPipelines![index];
          return MaterialPipelineCard(
            state: state,
            onTap: () {
              Navigator.of(context).push(FadeSlideRoute(
                page: MaterialPipelineDetail(state: state),
              ));
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(String message, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: AppTheme.textSecondary),
          const SizedBox(height: 16),
          Text(message, style: AppTheme.headingMedium.copyWith(color: AppTheme.textSecondary)),
        ],
      ),
    );
  }
}
