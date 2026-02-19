import 'package:flutter/material.dart';
import 'package:houzzdat_app/core/theme/app_theme.dart';
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
import 'package:houzzdat_app/features/insights/widgets/project_health_detail.dart';
import 'package:houzzdat_app/features/insights/widgets/financial_position_detail.dart';
import 'package:houzzdat_app/features/insights/widgets/material_pipeline_detail.dart';

/// Main Insights screen with 3 tabs: Project Health, Finances, Materials.
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

  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_onTabChanged);
    _loadProjectData();
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

  Future<void> _loadProjectData() async {
    setState(() => _loadingProjects = true);
    try {
      final states = await _projectAgent.computeAllProjects(widget.accountId);
      if (mounted) setState(() { _projectStates = states; _loadingProjects = false; });
    } catch (e) {
      debugPrint('Error loading project insights: $e');
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
    }
  }

  void _navigateToPlanSetup(String projectId, String projectName) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => PlanSetupScreen(
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
      backgroundColor: AppTheme.backgroundGrey,
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
          labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
          tabs: const [
            Tab(text: 'PROJECT HEALTH'),
            Tab(text: 'FINANCES'),
            Tab(text: 'MATERIALS'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildProjectHealthTab(),
          _buildFinancesTab(),
          _buildMaterialsTab(),
        ],
      ),
    );
  }

  Widget _buildProjectHealthTab() {
    if (_loadingProjects) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.primaryIndigo));
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
              Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => ProjectHealthDetail(
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
      return const Center(child: CircularProgressIndicator(color: AppTheme.primaryIndigo));
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
              Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => FinancialPositionDetail(state: state),
              ));
            },
          );
        },
      ),
    );
  }

  Widget _buildMaterialsTab() {
    if (_loadingMaterials) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.primaryIndigo));
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
              Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => MaterialPipelineDetail(state: state),
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
