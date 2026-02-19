import 'package:flutter/material.dart';
import 'package:houzzdat_app/core/theme/app_theme.dart';
import 'package:houzzdat_app/core/services/file_import_service.dart';

/// Screen for managers to upload/enter project plan, budget, and BOQ.
class PlanSetupScreen extends StatefulWidget {
  final String accountId;
  final String projectId;
  final String projectName;

  const PlanSetupScreen({
    super.key,
    required this.accountId,
    required this.projectId,
    required this.projectName,
  });

  @override
  State<PlanSetupScreen> createState() => _PlanSetupScreenState();
}

class _PlanSetupScreenState extends State<PlanSetupScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _importService = FileImportService();

  // Plan fields
  final _planNameController = TextEditingController(text: 'Project Plan');
  final _totalBudgetController = TextEditingController();
  DateTime? _startDate;
  DateTime? _endDate;
  String? _planId;

  // Milestones
  List<MilestoneImportRow> _milestones = [];
  List<String> _milestoneWarnings = [];

  // Budget items
  List<BudgetImportRow> _budgetItems = [];
  List<String> _budgetWarnings = [];

  // BOQ items
  List<BOQImportRow> _boqItems = [];
  List<String> _boqWarnings = [];

  bool _isSaving = false;
  bool _existingPlanLoaded = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadExistingPlan();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _planNameController.dispose();
    _totalBudgetController.dispose();
    super.dispose();
  }

  Future<void> _loadExistingPlan() async {
    final plan = await _importService.getProjectPlan(widget.projectId);
    if (plan != null && mounted) {
      setState(() {
        _planId = plan['id'] as String?;
        _planNameController.text = plan['name']?.toString() ?? 'Project Plan';
        if (plan['total_budget'] != null) {
          _totalBudgetController.text = plan['total_budget'].toString();
        }
        if (plan['start_date'] != null) _startDate = DateTime.tryParse(plan['start_date'].toString());
        if (plan['end_date'] != null) _endDate = DateTime.tryParse(plan['end_date'].toString());
        _existingPlanLoaded = true;
      });
    } else {
      setState(() => _existingPlanLoaded = true);
    }
  }

  Future<void> _pickDate(bool isStart) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? (_startDate ?? DateTime.now()) : (_endDate ?? DateTime.now().add(const Duration(days: 180))),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  Future<void> _importMilestonesCSV() async {
    final file = await _importService.pickCSVFile();
    if (file?.bytes == null) return;
    final result = _importService.parseMilestones(file!.bytes!);
    setState(() {
      _milestones = result.rows;
      _milestoneWarnings = result.warnings;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Parsed ${result.validRows} milestones from ${result.totalParsed} rows')),
      );
    }
  }

  Future<void> _importBudgetCSV() async {
    final file = await _importService.pickCSVFile();
    if (file?.bytes == null) return;
    final result = _importService.parseBudget(file!.bytes!);
    setState(() {
      _budgetItems = result.rows;
      _budgetWarnings = result.warnings;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Parsed ${result.validRows} budget items from ${result.totalParsed} rows')),
      );
    }
  }

  Future<void> _importBOQCSV() async {
    final file = await _importService.pickCSVFile();
    if (file?.bytes == null) return;
    final result = _importService.parseBOQ(file!.bytes!);
    setState(() {
      _boqItems = result.rows;
      _boqWarnings = result.warnings;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Parsed ${result.validRows} BOQ items from ${result.totalParsed} rows')),
      );
    }
  }

  void _addManualMilestone() {
    final nameCtrl = TextEditingController();
    final weightCtrl = TextEditingController(text: '0');
    DateTime? start, end;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Add Milestone'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Name *')),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextButton.icon(
                        icon: const Icon(Icons.calendar_today, size: 16),
                        label: Text(start != null ? '${start!.day}/${start!.month}/${start!.year}' : 'Start Date'),
                        onPressed: () async {
                          final d = await showDatePicker(context: ctx, initialDate: DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime(2030));
                          if (d != null) setDialogState(() => start = d);
                        },
                      ),
                    ),
                    Expanded(
                      child: TextButton.icon(
                        icon: const Icon(Icons.calendar_today, size: 16),
                        label: Text(end != null ? '${end!.day}/${end!.month}/${end!.year}' : 'End Date'),
                        onPressed: () async {
                          final d = await showDatePicker(context: ctx, initialDate: DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime(2030));
                          if (d != null) setDialogState(() => end = d);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(controller: weightCtrl, decoration: const InputDecoration(labelText: 'Weight %'), keyboardType: TextInputType.number),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                if (nameCtrl.text.trim().isEmpty) return;
                setState(() {
                  _milestones.add(MilestoneImportRow(
                    name: nameCtrl.text.trim(),
                    plannedStart: start,
                    plannedEnd: end,
                    weightPercent: double.tryParse(weightCtrl.text) ?? 0,
                    sortOrder: _milestones.length,
                  ));
                });
                Navigator.pop(ctx);
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  void _addManualBudgetItem() {
    final categoryCtrl = TextEditingController();
    final lineItemCtrl = TextEditingController();
    final amountCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Budget Item'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'Category *'),
                items: ['material', 'labour', 'overhead', 'equipment', 'other']
                    .map((c) => DropdownMenuItem(value: c, child: Text(c[0].toUpperCase() + c.substring(1))))
                    .toList(),
                onChanged: (v) => categoryCtrl.text = v ?? '',
              ),
              const SizedBox(height: 12),
              TextField(controller: lineItemCtrl, decoration: const InputDecoration(labelText: 'Line Item *')),
              const SizedBox(height: 12),
              TextField(controller: amountCtrl, decoration: const InputDecoration(labelText: 'Amount *'), keyboardType: TextInputType.number),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final amount = double.tryParse(amountCtrl.text);
              if (categoryCtrl.text.isEmpty || lineItemCtrl.text.trim().isEmpty || amount == null) return;
              setState(() {
                _budgetItems.add(BudgetImportRow(
                  category: categoryCtrl.text,
                  lineItem: lineItemCtrl.text.trim(),
                  budgetedAmount: amount,
                ));
              });
              Navigator.pop(ctx);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _addManualBOQItem() {
    final nameCtrl = TextEditingController();
    final categoryCtrl = TextEditingController();
    final qtyCtrl = TextEditingController();
    final unitCtrl = TextEditingController();
    final rateCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add BOQ Item'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Material Name *')),
              const SizedBox(height: 12),
              TextField(controller: categoryCtrl, decoration: const InputDecoration(labelText: 'Category')),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: TextField(controller: qtyCtrl, decoration: const InputDecoration(labelText: 'Qty *'), keyboardType: TextInputType.number)),
                  const SizedBox(width: 12),
                  Expanded(child: TextField(controller: unitCtrl, decoration: const InputDecoration(labelText: 'Unit *'))),
                ],
              ),
              const SizedBox(height: 12),
              TextField(controller: rateCtrl, decoration: const InputDecoration(labelText: 'Rate per unit'), keyboardType: TextInputType.number),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final qty = double.tryParse(qtyCtrl.text);
              if (nameCtrl.text.trim().isEmpty || qty == null || unitCtrl.text.trim().isEmpty) return;
              setState(() {
                _boqItems.add(BOQImportRow(
                  materialName: nameCtrl.text.trim(),
                  category: categoryCtrl.text.trim().isEmpty ? null : categoryCtrl.text.trim(),
                  plannedQuantity: qty,
                  unit: unitCtrl.text.trim(),
                  budgetedRate: double.tryParse(rateCtrl.text),
                ));
              });
              Navigator.pop(ctx);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveAll() async {
    if (_planNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a plan name'), backgroundColor: AppTheme.errorRed),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      // Create or reuse plan
      _planId ??= await _importService.createProjectPlan(
        projectId: widget.projectId,
        accountId: widget.accountId,
        name: _planNameController.text.trim(),
        totalBudget: double.tryParse(_totalBudgetController.text),
        startDate: _startDate,
        endDate: _endDate,
      );

      // Save milestones
      if (_milestones.isNotEmpty) {
        await _importService.saveMilestones(
          milestones: _milestones,
          planId: _planId!,
          projectId: widget.projectId,
          accountId: widget.accountId,
        );
      }

      // Save budget items
      if (_budgetItems.isNotEmpty) {
        await _importService.saveBudget(
          items: _budgetItems,
          planId: _planId!,
          projectId: widget.projectId,
          accountId: widget.accountId,
        );
      }

      // Save BOQ items
      if (_boqItems.isNotEmpty) {
        await _importService.saveBOQ(
          items: _boqItems,
          planId: _planId!,
          projectId: widget.projectId,
          accountId: widget.accountId,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Plan saved successfully'), backgroundColor: AppTheme.successGreen),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      debugPrint('Error saving plan: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.errorRed),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundGrey,
      appBar: AppBar(
        title: Text('Plan: ${widget.projectName}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        backgroundColor: AppTheme.primaryIndigo,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
            )
          else
            TextButton(
              onPressed: _saveAll,
              child: const Text('SAVE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.accentAmber,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
          tabs: [
            Tab(text: 'MILESTONES (${_milestones.length})'),
            Tab(text: 'BUDGET (${_budgetItems.length})'),
            Tab(text: 'BOQ (${_boqItems.length})'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Plan header fields
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  controller: _planNameController,
                  decoration: const InputDecoration(labelText: 'Plan Name', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _totalBudgetController,
                        decoration: const InputDecoration(labelText: 'Total Budget', border: OutlineInputBorder(), prefixText: '\u20B9 '),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 12),
                    _buildDateButton('Start', _startDate, () => _pickDate(true)),
                    const SizedBox(width: 8),
                    _buildDateButton('End', _endDate, () => _pickDate(false)),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Tab content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildMilestonesTab(),
                _buildBudgetTab(),
                _buildBOQTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateButton(String label, DateTime? date, VoidCallback onTap) {
    return OutlinedButton(
      onPressed: onTap,
      child: Text(
        date != null ? '${date.day}/${date.month}/${date.year}' : label,
        style: TextStyle(fontSize: 12, color: date != null ? AppTheme.textPrimary : AppTheme.textSecondary),
      ),
    );
  }

  Widget _buildMilestonesTab() {
    return Column(
      children: [
        _buildImportBar(
          onUpload: _importMilestonesCSV,
          onAdd: _addManualMilestone,
          csvHint: 'Name, Description, Start Date, End Date, Weight %',
        ),
        if (_milestoneWarnings.isNotEmpty) _buildWarnings(_milestoneWarnings),
        Expanded(
          child: _milestones.isEmpty
              ? _buildEmptyHint('Add milestones via CSV upload or manually')
              : ListView.builder(
                  itemCount: _milestones.length,
                  itemBuilder: (context, index) {
                    final m = _milestones[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: AppTheme.primaryIndigo.withValues(alpha: 0.1),
                        child: Text('${index + 1}', style: const TextStyle(color: AppTheme.primaryIndigo)),
                      ),
                      title: Text(m.name, style: AppTheme.bodyMedium),
                      subtitle: Text(
                        '${_formatDate(m.plannedStart)} - ${_formatDate(m.plannedEnd)} · Weight: ${m.weightPercent}%',
                        style: AppTheme.caption,
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline, size: 20, color: AppTheme.errorRed),
                        onPressed: () => setState(() => _milestones.removeAt(index)),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildBudgetTab() {
    return Column(
      children: [
        _buildImportBar(
          onUpload: _importBudgetCSV,
          onAdd: _addManualBudgetItem,
          csvHint: 'Category, Line Item, Amount, Quantity, Unit',
        ),
        if (_budgetWarnings.isNotEmpty) _buildWarnings(_budgetWarnings),
        Expanded(
          child: _budgetItems.isEmpty
              ? _buildEmptyHint('Add budget line items via CSV or manually')
              : ListView.builder(
                  itemCount: _budgetItems.length,
                  itemBuilder: (context, index) {
                    final b = _budgetItems[index];
                    return ListTile(
                      leading: _buildCategoryChip(b.category),
                      title: Text(b.lineItem, style: AppTheme.bodyMedium),
                      subtitle: Text('\u20B9 ${b.budgetedAmount.toStringAsFixed(0)}', style: AppTheme.caption),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline, size: 20, color: AppTheme.errorRed),
                        onPressed: () => setState(() => _budgetItems.removeAt(index)),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildBOQTab() {
    return Column(
      children: [
        _buildImportBar(
          onUpload: _importBOQCSV,
          onAdd: _addManualBOQItem,
          csvHint: 'Material Name, Category, Quantity, Unit, Rate',
        ),
        if (_boqWarnings.isNotEmpty) _buildWarnings(_boqWarnings),
        Expanded(
          child: _boqItems.isEmpty
              ? _buildEmptyHint('Add BOQ items via CSV or manually')
              : ListView.builder(
                  itemCount: _boqItems.length,
                  itemBuilder: (context, index) {
                    final b = _boqItems[index];
                    final total = b.budgetedRate != null ? b.budgetedRate! * b.plannedQuantity : null;
                    return ListTile(
                      title: Text(b.materialName, style: AppTheme.bodyMedium),
                      subtitle: Text(
                        '${b.plannedQuantity} ${b.unit}${b.budgetedRate != null ? ' @ \u20B9${b.budgetedRate!.toStringAsFixed(0)}' : ''}${total != null ? ' = \u20B9${total.toStringAsFixed(0)}' : ''}',
                        style: AppTheme.caption,
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline, size: 20, color: AppTheme.errorRed),
                        onPressed: () => setState(() => _boqItems.removeAt(index)),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildImportBar({
    required VoidCallback onUpload,
    required VoidCallback onAdd,
    required String csvHint,
  }) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          OutlinedButton.icon(
            onPressed: onUpload,
            icon: const Icon(Icons.upload_file, size: 16),
            label: const Text('Upload CSV'),
            style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Add Manually'),
            style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(csvHint, style: AppTheme.caption, overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }

  Widget _buildWarnings(List<String> warnings) {
    return Container(
      width: double.infinity,
      color: AppTheme.warningOrange.withValues(alpha: 0.1),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: warnings.map((w) => Text(w, style: const TextStyle(fontSize: 11, color: AppTheme.warningOrange))).toList(),
      ),
    );
  }

  Widget _buildEmptyHint(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(message, style: AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondary), textAlign: TextAlign.center),
      ),
    );
  }

  Widget _buildCategoryChip(String category) {
    final colors = {
      'material': AppTheme.infoBlue,
      'labour': AppTheme.warningOrange,
      'overhead': Colors.purple,
      'equipment': Colors.teal,
      'other': Colors.grey,
    };
    final color = colors[category] ?? Colors.grey;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(category[0].toUpperCase() + category.substring(1), style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600)),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '--';
    return '${date.day}/${date.month}/${date.year}';
  }
}
