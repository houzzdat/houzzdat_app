import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:houzzdat_app/core/theme/app_theme.dart';
import 'package:houzzdat_app/core/widgets/shared_widgets.dart';
import 'package:houzzdat_app/features/milestones/services/milestone_service.dart';

/// 4-step wizard to set up a milestone plan using AI generation.
/// Q1: Starting point (empty plot / existing structure / interior / occupied)
/// Q2: Project details (site type, area, floors, budget)
/// Q3: Work type (multi-select: structural, MEP, finishing, etc.)
/// Q4: Timeline & constraints (target date + special notes)
class MilestoneSetupScreen extends StatefulWidget {
  final String accountId;
  final String projectId;
  final String projectName;

  const MilestoneSetupScreen({
    super.key,
    required this.accountId,
    required this.projectId,
    required this.projectName,
  });

  @override
  State<MilestoneSetupScreen> createState() => _MilestoneSetupScreenState();
}

class _MilestoneSetupScreenState extends State<MilestoneSetupScreen> {
  final _service = MilestoneService();
  final _pageController = PageController();
  final _q3Controller = TextEditingController();
  final _areaController = TextEditingController();
  final _floorsController = TextEditingController(text: '1');
  final _budgetController = TextEditingController();

  int _currentStep = 0;
  bool _isGenerating = false;

  // Q1: Starting point
  String? _q1 = 'empty_plot';

  // Q2: Project details
  String? _siteType = 'residential';

  // Q3: Work types (multi-select)
  final Set<String> _q3WorkTypes = {'structural', 'mep', 'finishing'};

  // Q4: Timeline
  DateTime? _targetDate;

  final _startingPoints = [
    {'id': 'empty_plot', 'label': 'Empty Plot', 'icon': LucideIcons.square, 'desc': 'Starting from scratch on bare land'},
    {'id': 'existing_structure', 'label': 'Existing Structure', 'icon': LucideIcons.building2, 'desc': 'Building on/modifying existing construction'},
    {'id': 'interior_shell', 'label': 'Interior Shell', 'icon': LucideIcons.home, 'desc': 'Structure complete, interior work needed'},
    {'id': 'occupied_space', 'label': 'Occupied Space', 'icon': LucideIcons.users, 'desc': 'Renovation while space is in use'},
  ];

  final _siteTypes = [
    {'id': 'residential', 'label': 'Residential', 'icon': LucideIcons.home, 'desc': 'Individual house, villa, or apartment'},
    {'id': 'commercial', 'label': 'Commercial', 'icon': LucideIcons.store, 'desc': 'Office, shop, mall, or showroom'},
    {'id': 'industrial', 'label': 'Industrial', 'icon': LucideIcons.factory, 'desc': 'Factory, warehouse, or workshop'},
    {'id': 'mixed_use', 'label': 'Mixed Use', 'icon': LucideIcons.building2, 'desc': 'Combination of residential and commercial'},
  ];

  final _workTypes = [
    {'id': 'structural', 'label': 'Structural', 'icon': LucideIcons.layers},
    {'id': 'mep', 'label': 'MEP', 'icon': LucideIcons.zap},
    {'id': 'finishing', 'label': 'Finishing', 'icon': LucideIcons.paintBucket},
    {'id': 'waterproofing', 'label': 'Waterproofing', 'icon': LucideIcons.droplets},
    {'id': 'external', 'label': 'External Works', 'icon': LucideIcons.trees},
    {'id': 'legal', 'label': 'Legal / Approvals', 'icon': LucideIcons.scale},
  ];

  @override
  void dispose() {
    _pageController.dispose();
    _q3Controller.dispose();
    _areaController.dispose();
    _floorsController.dispose();
    _budgetController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep < 3) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      setState(() => _currentStep++);
    } else {
      _generatePlan();
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      setState(() => _currentStep--);
    }
  }

  Future<void> _generatePlan() async {
    if (_q1 == null || _q3WorkTypes.isEmpty) return;

    setState(() => _isGenerating = true);
    try {
      final workTypesString = _q3WorkTypes.join(', ');
      final timelineString = [
        if (_targetDate != null)
          'Target completion: ${_targetDate!.day}/${_targetDate!.month}/${_targetDate!.year}',
        if (_q3Controller.text.trim().isNotEmpty) _q3Controller.text.trim(),
      ].join('. ');

      await _service.generateMilestonePlan(
        projectId: widget.projectId,
        accountId: widget.accountId,
        q1StartingPoint: _q1!,
        q2WorkTypes: workTypesString,
        q3Timeline: timelineString.isEmpty ? 'No specific timeline' : timelineString,
        siteType: _siteType,
        areaSqft: double.tryParse(_areaController.text),
        numberOfFloors: int.tryParse(_floorsController.text),
        estimatedBudgetLakhs: double.tryParse(_budgetController.text),
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Milestone plan generated successfully!'),
            backgroundColor: AppTheme.successGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to generate plan: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundGrey,
      appBar: AppBar(
        backgroundColor: AppTheme.primaryIndigo,
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Setup Milestones', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            Text(widget.projectName, style: const TextStyle(fontSize: 12, color: Colors.white70)),
          ],
        ),
      ),
      body: Column(
        children: [
          // Step indicator
          _buildStepIndicator(),

          // Page content
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildQ1Page(),
                _buildQ2ProjectDetailsPage(),
                _buildQ3WorkTypePage(),
                _buildQ4TimelinePage(),
              ],
            ),
          ),

          // Navigation buttons
          _buildNavBar(),
        ],
      ),
    );
  }

  Widget _buildStepIndicator() {
    final stepTitles = ['Start', 'Details', 'Work Type', 'Timeline'];
    return Container(
      color: AppTheme.primaryIndigo,
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
      child: Row(
        children: List.generate(4, (i) {
          final isActive = i == _currentStep;
          final isDone = i < _currentStep;
          return Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: isActive || isDone ? AppTheme.accentAmber : Colors.white24,
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: isDone
                                  ? const Icon(LucideIcons.check, size: 14, color: Colors.black)
                                  : Text(
                                      '${i + 1}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: isActive ? Colors.black : Colors.white,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        stepTitles[i],
                        style: TextStyle(
                          fontSize: 10,
                          color: isActive ? Colors.white : Colors.white54,
                          fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                if (i < 3)
                  Container(
                    width: 16,
                    height: 1,
                    color: i < _currentStep ? AppTheme.accentAmber : Colors.white24,
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildQ1Page() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'What is your starting point?',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        const Text(
          'This helps us understand what construction phases to include',
          style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
        ),
        const SizedBox(height: 20),
        ..._startingPoints.map((sp) {
          final isSelected = _q1 == sp['id'];
          return GestureDetector(
            onTap: () => setState(() => _q1 = sp['id'] as String),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                border: Border.all(
                  color: isSelected ? AppTheme.primaryIndigo : Colors.grey[300]!,
                  width: isSelected ? 2 : 1,
                ),
                borderRadius: BorderRadius.circular(12),
                color: isSelected
                    ? AppTheme.primaryIndigo.withValues(alpha: 0.06)
                    : Colors.white,
              ),
              child: Row(
                children: [
                  Icon(
                    sp['icon'] as IconData,
                    size: 28,
                    color: isSelected ? AppTheme.primaryIndigo : Colors.grey,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          sp['label'] as String,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isSelected ? AppTheme.primaryIndigo : null,
                          ),
                        ),
                        Text(
                          sp['desc'] as String,
                          style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  if (isSelected)
                    const Icon(LucideIcons.checkCircle, color: AppTheme.primaryIndigo),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildQ2ProjectDetailsPage() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'Tell us about the project',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        const Text(
          'These details help generate a more accurate plan',
          style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
        ),
        const SizedBox(height: 20),

        // Site type selector
        const Text('Site Type', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        ..._siteTypes.map((st) {
          final isSelected = _siteType == st['id'];
          return GestureDetector(
            onTap: () => setState(() => _siteType = st['id'] as String),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(
                  color: isSelected ? AppTheme.primaryIndigo : Colors.grey[300]!,
                  width: isSelected ? 2 : 1,
                ),
                borderRadius: BorderRadius.circular(10),
                color: isSelected
                    ? AppTheme.primaryIndigo.withValues(alpha: 0.06)
                    : Colors.white,
              ),
              child: Row(
                children: [
                  Icon(
                    st['icon'] as IconData,
                    size: 22,
                    color: isSelected ? AppTheme.primaryIndigo : Colors.grey,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          st['label'] as String,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: isSelected ? AppTheme.primaryIndigo : null,
                          ),
                        ),
                        Text(
                          st['desc'] as String,
                          style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  if (isSelected)
                    const Icon(LucideIcons.checkCircle, size: 18, color: AppTheme.primaryIndigo),
                ],
              ),
            ),
          );
        }),

        const SizedBox(height: 16),

        // Construction area
        TextField(
          controller: _areaController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Construction area (sq ft)',
            hintText: 'e.g. 2000',
            prefixIcon: Icon(LucideIcons.ruler, size: 18),
            border: OutlineInputBorder(),
            helperText: 'Total built-up area in square feet',
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 16),

        // Number of floors
        TextField(
          controller: _floorsController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Number of floors',
            hintText: 'e.g. 2',
            prefixIcon: Icon(LucideIcons.layers, size: 18),
            border: OutlineInputBorder(),
            helperText: 'Ground + upper floors (0 = single storey)',
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 16),

        // Estimated budget
        TextField(
          controller: _budgetController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Estimated budget (in Lakhs)',
            hintText: 'e.g. 50',
            prefixIcon: Icon(LucideIcons.indianRupee, size: 18),
            border: OutlineInputBorder(),
            helperText: 'Approximate total budget in lakhs (optional)',
          ),
        ),
      ],
    );
  }

  Widget _buildQ3WorkTypePage() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'What type of work is needed?',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        const Text(
          'Select all that apply — this determines your phase modules',
          style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: _workTypes.map((wt) {
            final isSelected = _q3WorkTypes.contains(wt['id'] as String);
            return GestureDetector(
              onTap: () {
                setState(() {
                  if (isSelected) {
                    _q3WorkTypes.remove(wt['id']);
                  } else {
                    _q3WorkTypes.add(wt['id'] as String);
                  }
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: isSelected ? AppTheme.primaryIndigo : Colors.grey[300]!,
                    width: isSelected ? 2 : 1,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  color: isSelected
                      ? AppTheme.primaryIndigo.withValues(alpha: 0.08)
                      : Colors.white,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      wt['icon'] as IconData,
                      size: 16,
                      color: isSelected ? AppTheme.primaryIndigo : Colors.grey,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      wt['label'] as String,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected ? AppTheme.primaryIndigo : null,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildQ4TimelinePage() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'Timeline & constraints?',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        const Text(
          'Optionally set a target date and any special requirements',
          style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
        ),
        const SizedBox(height: 20),

        // Target date picker
        InkWell(
          onTap: () async {
            final date = await showDatePicker(
              context: context,
              initialDate: DateTime.now().add(const Duration(days: 180)),
              firstDate: DateTime.now().add(const Duration(days: 30)),
              lastDate: DateTime.now().add(const Duration(days: 1825)),
            );
            if (date != null) setState(() => _targetDate = date);
          },
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(
                color: _targetDate != null ? AppTheme.primaryIndigo : Colors.grey[350]!,
                width: _targetDate != null ? 2 : 1,
              ),
              borderRadius: BorderRadius.circular(10),
              color: _targetDate != null
                  ? AppTheme.primaryIndigo.withValues(alpha: 0.05)
                  : Colors.white,
            ),
            child: Row(
              children: [
                Icon(
                  LucideIcons.calendarDays,
                  color: _targetDate != null ? AppTheme.primaryIndigo : Colors.grey,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Text(
                  _targetDate != null
                      ? 'Target: ${_targetDate!.day}/${_targetDate!.month}/${_targetDate!.year}'
                      : 'Set target completion date (recommended)',
                  style: TextStyle(
                    color: _targetDate != null ? AppTheme.primaryIndigo : AppTheme.textSecondary,
                  ),
                ),
                if (_targetDate != null) ...[
                  const Spacer(),
                  GestureDetector(
                    onTap: () => setState(() => _targetDate = null),
                    child: const Icon(LucideIcons.x, size: 16, color: AppTheme.textSecondary),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Special constraints
        TextField(
          controller: _q3Controller,
          maxLines: 4,
          decoration: InputDecoration(
            labelText: 'Special requirements (optional)',
            hintText: 'e.g. Avoid monsoon for exterior work, Site is occupied by tenants, Festival deadline for handover...',
            border: const OutlineInputBorder(),
            alignLabelWithHint: true,
          ),
        ),
        const SizedBox(height: 16),

        // Indian context hints
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.accentAmber.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(LucideIcons.info, size: 14, color: AppTheme.accentAmber),
                  SizedBox(width: 6),
                  Text(
                    'Indian Construction Tips',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ...const [
                '• Monsoon buffer (Jun–Sep) added automatically for exterior phases',
                '• Festival breaks (Diwali, Pongal) add 7-day buffer each',
                '• IS codes and NBC 2016 standards applied to phase templates',
              ].map((tip) => Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(tip, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
              )),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNavBar() {
    final canProceed = switch (_currentStep) {
      0 => _q1 != null,
      1 => _siteType != null && _areaController.text.trim().isNotEmpty,
      2 => _q3WorkTypes.isNotEmpty,
      _ => true,
    };

    return Container(
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 12,
        bottom: 12 + MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 8)],
      ),
      child: Row(
        children: [
          if (_currentStep > 0)
            TextButton(
              onPressed: _prevStep,
              child: const Text('Back'),
            ),
          const Spacer(),
          SizedBox(
            height: 48,
            child: ElevatedButton.icon(
              onPressed: (canProceed && !_isGenerating) ? _nextStep : null,
              icon: _isGenerating
                  ? const SizedBox(width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Icon(_currentStep == 3 ? LucideIcons.sparkles : LucideIcons.arrowRight),
              label: Text(
                _isGenerating
                    ? 'Generating plan...'
                    : _currentStep == 3
                        ? 'Generate Plan'
                        : 'Next',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryIndigo,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
