import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:houzzdat_app/core/theme/app_theme.dart';
import 'package:houzzdat_app/core/widgets/shared_widgets.dart';
import 'package:houzzdat_app/features/reports/screens/report_detail_screen.dart';

/// Screen for configuring and generating a new AI report.
class GenerateReportScreen extends StatefulWidget {
  final String accountId;
  const GenerateReportScreen({super.key, required this.accountId});

  @override
  State<GenerateReportScreen> createState() => _GenerateReportScreenState();
}

class _GenerateReportScreenState extends State<GenerateReportScreen> {
  final _supabase = Supabase.instance.client;

  // Configuration
  String _reportType = 'daily'; // daily, weekly, custom
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();
  bool _allSites = true;
  final List<String> _selectedProjectIds = [];
  List<Map<String, dynamic>> _projects = [];

  // State
  bool _isLoadingProjects = true;
  bool _isGenerating = false;
  String _generatingMessage = 'Preparing data...';

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
          _isLoadingProjects = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading projects: $e');
      if (mounted) setState(() => _isLoadingProjects = false);
    }
  }

  void _setReportType(String type) {
    setState(() {
      _reportType = type;
      final now = DateTime.now();
      switch (type) {
        case 'daily':
          _startDate = now;
          _endDate = now;
          break;
        case 'weekly':
          // Monday to Sunday of current week
          _startDate = now.subtract(Duration(days: now.weekday - 1));
          _endDate = _startDate.add(const Duration(days: 6));
          break;
        case 'custom':
          // Keep current selection
          break;
      }
    });
  }

  Future<void> _pickDate(bool isStart) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _startDate : _endDate,
      firstDate: DateTime(2024),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppTheme.primaryIndigo,
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
          if (_endDate.isBefore(_startDate)) _endDate = _startDate;
        } else {
          _endDate = picked;
          if (_startDate.isAfter(_endDate)) _startDate = _endDate;
        }
        _reportType = 'custom';
      });
    }
  }

  Future<void> _generateReport() async {
    setState(() {
      _isGenerating = true;
      _generatingMessage = 'Fetching data from all sources...';
    });

    try {
      // Short delay for UI feedback
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) {
        setState(() => _generatingMessage = 'Generating AI reports...');
      }

      final fmt = DateFormat('yyyy-MM-dd');
      final response = await _supabase.functions.invoke(
        'generate-report',
        body: {
          'account_id': widget.accountId,
          'start_date': fmt.format(_startDate),
          'end_date': fmt.format(_endDate),
          'project_ids': _allSites ? [] : _selectedProjectIds,
        },
      );

      final data = response.data;
      if (data['success'] == true) {
        if (mounted) {
          // Navigate to the detail screen with the generated content
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => ReportDetailScreen(
                reportId: data['report_id'].toString(),
                accountId: widget.accountId,
                initialManagerContent: data['manager_report']?.toString(),
                initialOwnerContent: data['owner_report']?.toString(),
              ),
            ),
          );
        }
      } else {
        throw Exception(data['error'] ?? 'Report generation failed');
      }
    } catch (e) {
      debugPrint('Error generating report: $e');
      if (mounted) {
        setState(() => _isGenerating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not generate report. Please try again later.'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('d MMM yyyy');
    final dateLabel = _startDate == _endDate || _reportType == 'daily'
        ? 'Daily Report for ${fmt.format(_startDate)}'
        : 'Report for ${fmt.format(_startDate)} to ${fmt.format(_endDate)}';

    return Scaffold(
      backgroundColor: AppTheme.backgroundGrey,
      appBar: AppBar(
        title: const Text('Generate Report', style: TextStyle(fontSize: 16)),
        backgroundColor: AppTheme.primaryIndigo,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isGenerating ? _buildGeneratingState() : _buildConfigForm(dateLabel, fmt),
    );
  }

  Widget _buildGeneratingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 60,
            height: 60,
            child: CircularProgressIndicator(
              color: AppTheme.primaryIndigo,
              strokeWidth: 3,
            ),
          ),
          const SizedBox(height: AppTheme.spacingL),
          Text(
            _generatingMessage,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: AppTheme.spacingS),
          const Text(
            'This may take 10-30 seconds...',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildConfigForm(String dateLabel, DateFormat fmt) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.spacingM),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header card
          Container(
            padding: const EdgeInsets.all(AppTheme.spacingM),
            decoration: BoxDecoration(
              color: AppTheme.primaryIndigo.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(AppTheme.radiusL),
              border: Border.all(
                color: AppTheme.primaryIndigo.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.auto_awesome, color: AppTheme.accentAmber, size: 28),
                const SizedBox(width: AppTheme.spacingS),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'AI Report Generator',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          color: AppTheme.primaryIndigo,
                        ),
                      ),
                      Text(
                        dateLabel,
                        style: AppTheme.caption.copyWith(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: AppTheme.spacingL),

          // Report Period section
          _buildSectionTitle('Report Period'),
          const SizedBox(height: AppTheme.spacingS),
          _buildReportTypeSelector(),

          const SizedBox(height: AppTheme.spacingM),

          // Date range
          _buildSectionTitle('Date Range'),
          const SizedBox(height: AppTheme.spacingS),
          Row(
            children: [
              Expanded(
                child: _buildDateButton(
                  label: 'From',
                  date: fmt.format(_startDate),
                  onTap: () => _pickDate(true),
                ),
              ),
              const SizedBox(width: AppTheme.spacingS),
              Expanded(
                child: _buildDateButton(
                  label: 'To',
                  date: fmt.format(_endDate),
                  onTap: () => _pickDate(false),
                ),
              ),
            ],
          ),

          const SizedBox(height: AppTheme.spacingL),

          // Sites selection
          _buildSectionTitle('Sites to Include'),
          const SizedBox(height: AppTheme.spacingS),
          _buildSiteSelector(),

          const SizedBox(height: AppTheme.spacingXL),

          // Generate button
          SizedBox(
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _isLoadingProjects ? null : _generateReport,
              icon: const Icon(Icons.auto_awesome, size: 20),
              label: const Text(
                'Generate Reports',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentAmber,
                foregroundColor: AppTheme.textPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusL),
                ),
                elevation: 2,
              ),
            ),
          ),

          const SizedBox(height: AppTheme.spacingM),

          // Info text
          const Text(
            'Two reports will be generated: an internal Manager Report and a professional Owner Report. Both can be edited before saving or sending.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.4),
          ),

          const SizedBox(height: AppTheme.spacingXL),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontWeight: FontWeight.w700,
        fontSize: 14,
        color: AppTheme.textPrimary,
      ),
    );
  }

  Widget _buildReportTypeSelector() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusL),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          _buildTypeChip('Daily', 'daily'),
          _buildTypeChip('Weekly', 'weekly'),
          _buildTypeChip('Custom', 'custom'),
        ],
      ),
    );
  }

  Widget _buildTypeChip(String label, String value) {
    final isActive = _reportType == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => _setReportType(value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isActive ? AppTheme.primaryIndigo : Colors.transparent,
            borderRadius: BorderRadius.circular(AppTheme.radiusL),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: isActive ? Colors.white : AppTheme.textSecondary,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDateButton({
    required String label,
    required String date,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacingM,
          vertical: AppTheme.spacingS + 2,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppTheme.radiusM),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today, size: 16, color: AppTheme.primaryIndigo),
            const SizedBox(width: AppTheme.spacingS),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppTheme.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    date,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSiteSelector() {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingM),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusL),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          // All sites toggle
          GestureDetector(
            onTap: () {
              setState(() {
                _allSites = true;
                _selectedProjectIds.clear();
              });
            },
            child: Row(
              children: [
                Icon(
                  _allSites ? Icons.check_box : Icons.check_box_outline_blank,
                  color: _allSites ? AppTheme.primaryIndigo : AppTheme.textSecondary,
                  size: 22,
                ),
                const SizedBox(width: AppTheme.spacingS),
                const Text(
                  'All Sites',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const Spacer(),
                if (_allSites)
                  const CategoryBadge(
                    text: 'Default',
                    color: AppTheme.successGreen,
                  ),
              ],
            ),
          ),

          if (_isLoadingProjects)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppTheme.spacingS),
              child: SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),

          if (!_isLoadingProjects && _projects.isNotEmpty) ...[
            const Divider(height: AppTheme.spacingM),
            ..._projects.map((project) {
              final id = project['id']?.toString() ?? '';
              final name = project['name']?.toString() ?? 'Unnamed Site';
              final isSelected = _selectedProjectIds.contains(id);

              return GestureDetector(
                onTap: () {
                  setState(() {
                    _allSites = false;
                    if (isSelected) {
                      _selectedProjectIds.remove(id);
                      if (_selectedProjectIds.isEmpty) _allSites = true;
                    } else {
                      _selectedProjectIds.add(id);
                    }
                  });
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Icon(
                        !_allSites && isSelected
                            ? Icons.check_box
                            : Icons.check_box_outline_blank,
                        color: !_allSites && isSelected
                            ? AppTheme.primaryIndigo
                            : AppTheme.textSecondary,
                        size: 22,
                      ),
                      const SizedBox(width: AppTheme.spacingS),
                      Expanded(
                        child: Text(
                          name,
                          style: TextStyle(
                            fontSize: 14,
                            color: !_allSites && isSelected
                                ? AppTheme.textPrimary
                                : AppTheme.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}
