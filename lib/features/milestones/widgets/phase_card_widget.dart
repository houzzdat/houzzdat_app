import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';
import 'package:houzzdat_app/core/theme/app_theme.dart';
import 'package:houzzdat_app/features/milestones/services/milestone_service.dart';
import 'package:houzzdat_app/features/milestones/widgets/gate_checklist_sheet.dart';
import 'package:houzzdat_app/features/milestones/widgets/key_result_tile.dart';
import 'package:houzzdat_app/models/models.dart';

class PhaseCardWidget extends StatefulWidget {
  final MilestonePhase phase;
  final String projectId;
  final String accountId;
  final bool isManager;
  final VoidCallback onPhaseUpdated;

  const PhaseCardWidget({
    super.key,
    required this.phase,
    required this.projectId,
    required this.accountId,
    required this.isManager,
    required this.onPhaseUpdated,
  });

  @override
  State<PhaseCardWidget> createState() => _PhaseCardWidgetState();
}

class _PhaseCardWidgetState extends State<PhaseCardWidget> {
  bool _expanded = false;
  final _milestoneService = MilestoneService();

  @override
  Widget build(BuildContext context) {
    final phase = widget.phase;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      elevation: _expanded ? 2 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: _statusColor(phase.status).withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          // Collapsed header
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // Phase order circle
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: _statusColor(phase.status).withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '${phase.phaseOrder}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: _statusColor(phase.status),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          phase.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      _buildStatusChip(phase.status),
                      if (widget.isManager)
                        PopupMenuButton<String>(
                          icon: const Icon(LucideIcons.moreVertical, size: 16, color: AppTheme.textSecondary),
                          itemBuilder: (_) => [
                            const PopupMenuItem(value: 'edit', child: Row(children: [Icon(LucideIcons.pencil, size: 14), SizedBox(width: 8), Text('Edit Phase')])),
                            const PopupMenuItem(value: 'add_kr', child: Row(children: [Icon(LucideIcons.plus, size: 14), SizedBox(width: 8), Text('Add Key Result')])),
                            const PopupMenuItem(value: 'delete', child: Row(children: [Icon(LucideIcons.trash2, size: 14, color: Colors.red), SizedBox(width: 8), Text('Delete Phase', style: TextStyle(color: Colors.red))])),
                          ],
                          onSelected: (value) {
                            if (value == 'edit') _showEditPhaseSheet();
                            if (value == 'add_kr') _showAddKeyResultSheet();
                            if (value == 'delete') _confirmDeletePhase();
                          },
                        ),
                      const SizedBox(width: 6),
                      Icon(
                        _expanded ? LucideIcons.chevronUp : LucideIcons.chevronDown,
                        size: 16,
                        color: AppTheme.textSecondary,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Date range + budget
                  Row(
                    children: [
                      if (phase.plannedStart != null && phase.plannedEnd != null) ...[
                        const Icon(LucideIcons.calendar, size: 12, color: AppTheme.textSecondary),
                        const SizedBox(width: 4),
                        Text(
                          '${_formatDate(phase.plannedStart!)} – ${_formatDate(phase.plannedEnd!)}',
                          style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                        ),
                        const SizedBox(width: 12),
                      ],
                      if (phase.budgetAllocated != null) ...[
                        const Icon(LucideIcons.indianRupee, size: 12, color: AppTheme.textSecondary),
                        const SizedBox(width: 4),
                        Text(
                          '${_formatCurrency(phase.budgetAllocated!)} allocated',
                          style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                        ),
                      ],
                    ],
                  ),

                  // Overall KR progress bar
                  if (phase.keyResults.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(3),
                            child: LinearProgressIndicator(
                              value: (phase.completionPercent / 100).clamp(0, 1),
                              minHeight: 5,
                              backgroundColor: Colors.grey[200],
                              valueColor: AlwaysStoppedAnimation(
                                  _statusColor(phase.status)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${phase.completionPercent.round()}%',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: _statusColor(phase.status),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Expanded content
          if (_expanded) _buildExpandedContent(phase),
        ],
      ),
    );
  }

  Widget _buildExpandedContent(MilestonePhase phase) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Colors.grey[200]!),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Description
            if (phase.description != null && phase.description!.isNotEmpty) ...[
              Text(
                phase.description!,
                style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 12),
            ],

            // Budget burn
            if (phase.budgetAllocated != null) ...[
              Row(
                children: [
                  const Text('Budget:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(width: 8),
                  Text(
                    '₹${_formatCurrency(phase.budgetSpent)} / ₹${_formatCurrency(phase.budgetAllocated!)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: phase.budgetBurnPercent > 100 ? AppTheme.errorRed : AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '(${phase.budgetBurnPercent.round()}%)',
                    style: TextStyle(
                      fontSize: 11,
                      color: phase.budgetBurnPercent > 100 ? AppTheme.errorRed : AppTheme.warningOrange,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],

            // Key results
            if (phase.keyResults.isNotEmpty) ...[
              const Text(
                'Key Results',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.3),
              ),
              const SizedBox(height: 4),
              ...phase.keyResults.map((kr) => KeyResultTile(
                keyResult: kr,
                canEdit: widget.isManager && phase.isActive,
                onTap: () => _editKeyResult(kr),
                onEditTap: widget.isManager ? () => _showEditKrSheet(kr) : null,
                onDeleteTap: widget.isManager ? () => _confirmDeleteKr(kr) : null,
              )),
              const SizedBox(height: 12),
            ],

            // Gate action buttons
            if (widget.isManager) _buildGateActions(phase),
          ],
        ),
      ),
    );
  }

  Widget _buildGateActions(MilestonePhase phase) {
    if (phase.isCompleted) {
      return const Row(
        children: [
          Icon(LucideIcons.checkCircle, size: 14, color: AppTheme.successGreen),
          SizedBox(width: 6),
          Text('Phase completed', style: TextStyle(fontSize: 12, color: AppTheme.successGreen)),
        ],
      );
    }

    if (phase.status == MilestonePhaseStatus.pending) {
      return SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: () => _openGate(ChecklistGateType.preStart),
          icon: const Icon(LucideIcons.playCircle, size: 16),
          label: const Text('Start Gate Checklist'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppTheme.primaryIndigo,
            side: const BorderSide(color: AppTheme.primaryIndigo),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      );
    }

    if (phase.isActive) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () => _openGate(ChecklistGateType.postCompletion),
          icon: const Icon(LucideIcons.checkSquare, size: 16),
          label: const Text('Complete Phase Gate'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.successGreen,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      );
    }

    if (phase.isBlocked) {
      return const Row(
        children: [
          Icon(LucideIcons.alertOctagon, size: 14, color: AppTheme.errorRed),
          SizedBox(width: 6),
          Text('Phase blocked', style: TextStyle(fontSize: 12, color: AppTheme.errorRed)),
        ],
      );
    }

    return const SizedBox.shrink();
  }

  void _openGate(ChecklistGateType gateType) {
    GateChecklistSheet.show(
      context,
      phase: widget.phase,
      gateType: gateType,
      projectId: widget.projectId,
      accountId: widget.accountId,
      onGateCompleted: widget.onPhaseUpdated,
    );
  }

  Future<void> _editKeyResult(KeyResult kr) async {
    await UpdateKeyResultDialog.show(context, kr, (newValue) async {
      await _milestoneService.updateKeyResultValue(
        keyResultId: kr.id,
        newValue: newValue,
        projectId: widget.projectId,
        accountId: widget.accountId,
        phaseId: kr.phaseId,
      );
      widget.onPhaseUpdated();
    });
  }

  void _showEditPhaseSheet() {
    final nameController = TextEditingController(text: widget.phase.name);
    final descController = TextEditingController(text: widget.phase.description ?? '');
    final budgetController = TextEditingController(
      text: widget.phase.budgetAllocated?.toStringAsFixed(0) ?? '',
    );
    DateTime? plannedStart = widget.phase.plannedStart;
    DateTime? plannedEnd = widget.phase.plannedEnd;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(
            left: 20, right: 20, top: 20,
            bottom: 20 + MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Edit Phase', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Phase name', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descController,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Description (optional)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: _dateField(ctx, 'Start date', plannedStart, (d) => setSheetState(() => plannedStart = d))),
                const SizedBox(width: 12),
                Expanded(child: _dateField(ctx, 'End date', plannedEnd, (d) => setSheetState(() => plannedEnd = d))),
              ]),
              const SizedBox(height: 12),
              TextField(
                controller: budgetController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Budget allocated (₹)',
                  prefixIcon: Icon(LucideIcons.indianRupee, size: 16),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    await _milestoneService.updatePhase(
                      phaseId: widget.phase.id,
                      name: nameController.text.trim().isEmpty ? null : nameController.text.trim(),
                      description: descController.text.trim(),
                      plannedStart: plannedStart,
                      plannedEnd: plannedEnd,
                      budgetAllocated: double.tryParse(budgetController.text),
                    );
                    widget.onPhaseUpdated();
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryIndigo, foregroundColor: Colors.white),
                  child: const Text('Save Changes'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dateField(BuildContext ctx, String label, DateTime? value, void Function(DateTime) onPick) {
    return InkWell(
      onTap: () async {
        final d = await showDatePicker(
          context: ctx,
          initialDate: value ?? DateTime.now(),
          firstDate: DateTime(2020),
          lastDate: DateTime(2030),
        );
        if (d != null) onPick(d);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          border: Border.all(color: value != null ? AppTheme.primaryIndigo : Colors.grey[350]!),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          value != null ? DateFormat('dd MMM yy').format(value) : label,
          style: TextStyle(fontSize: 12, color: value != null ? AppTheme.primaryIndigo : AppTheme.textSecondary),
        ),
      ),
    );
  }

  void _showAddKeyResultSheet() {
    final titleController = TextEditingController();
    final targetController = TextEditingController(text: '1');
    final unitController = TextEditingController();
    String metricType = 'boolean';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(
            left: 20, right: 20, top: 20,
            bottom: 20 + MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Add Key Result', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              TextField(
                controller: titleController,
                decoration: const InputDecoration(labelText: 'Title', hintText: 'e.g. Pour foundation slab', border: OutlineInputBorder()),
                autofocus: true,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: metricType,
                decoration: const InputDecoration(labelText: 'Metric type', border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: 'boolean', child: Text('Boolean (done/not done)')),
                  DropdownMenuItem(value: 'percentage', child: Text('Percentage (0–100%)')),
                  DropdownMenuItem(value: 'count', child: Text('Count (e.g. 5 slabs)')),
                  DropdownMenuItem(value: 'numeric', child: Text('Numeric (custom unit)')),
                ],
                onChanged: (v) => setSheetState(() => metricType = v!),
              ),
              if (metricType != 'boolean') ...[
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: TextField(
                    controller: targetController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Target value', border: OutlineInputBorder()),
                  )),
                  const SizedBox(width: 12),
                  Expanded(child: TextField(
                    controller: unitController,
                    decoration: const InputDecoration(labelText: 'Unit (optional)', hintText: 'e.g. slabs, %', border: OutlineInputBorder()),
                  )),
                ]),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    if (titleController.text.trim().isEmpty) return;
                    Navigator.pop(ctx);
                    await _milestoneService.addKeyResult(
                      phaseId: widget.phase.id,
                      projectId: widget.projectId,
                      accountId: widget.accountId,
                      title: titleController.text.trim(),
                      metricType: metricType,
                      targetValue: double.tryParse(targetController.text) ?? 1,
                      unit: unitController.text.trim().isEmpty ? null : unitController.text.trim(),
                    );
                    widget.onPhaseUpdated();
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryIndigo, foregroundColor: Colors.white),
                  child: const Text('Add Key Result'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDeletePhase() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Phase'),
        content: Text('Delete "${widget.phase.name}"? This will also remove all ${widget.phase.keyResults.length} key results. This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _milestoneService.deletePhase(widget.phase.id);
              widget.onPhaseUpdated();
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorRed, foregroundColor: Colors.white),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showEditKrSheet(KeyResult kr) {
    final titleController = TextEditingController(text: kr.title);
    final targetController = TextEditingController(
      text: kr.targetValue?.toStringAsFixed(kr.targetValue! % 1 == 0 ? 0 : 1) ?? '1',
    );
    final unitController = TextEditingController(text: kr.unit ?? '');
    String metricType = kr.metricType.dbValue;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(
            left: 20, right: 20, top: 20,
            bottom: 20 + MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Edit Key Result', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              TextField(
                controller: titleController,
                decoration: const InputDecoration(labelText: 'Title', border: OutlineInputBorder()),
                autofocus: true,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: metricType,
                decoration: const InputDecoration(labelText: 'Metric type', border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: 'boolean', child: Text('Boolean (done/not done)')),
                  DropdownMenuItem(value: 'percentage', child: Text('Percentage (0–100%)')),
                  DropdownMenuItem(value: 'count', child: Text('Count')),
                  DropdownMenuItem(value: 'numeric', child: Text('Numeric')),
                ],
                onChanged: (v) => setSheetState(() => metricType = v!),
              ),
              if (metricType != 'boolean') ...[
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: TextField(
                    controller: targetController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Target value', border: OutlineInputBorder()),
                  )),
                  const SizedBox(width: 12),
                  Expanded(child: TextField(
                    controller: unitController,
                    decoration: const InputDecoration(labelText: 'Unit (optional)', border: OutlineInputBorder()),
                  )),
                ]),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    await _milestoneService.updateKeyResult(
                      keyResultId: kr.id,
                      title: titleController.text.trim().isEmpty ? null : titleController.text.trim(),
                      metricType: metricType,
                      targetValue: double.tryParse(targetController.text),
                      unit: unitController.text.trim().isEmpty ? null : unitController.text.trim(),
                    );
                    widget.onPhaseUpdated();
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryIndigo, foregroundColor: Colors.white),
                  child: const Text('Save'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDeleteKr(KeyResult kr) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Key Result'),
        content: Text('Delete "${kr.title}"? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _milestoneService.deleteKeyResult(kr.id);
              widget.onPhaseUpdated();
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorRed, foregroundColor: Colors.white),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(MilestonePhaseStatus status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _statusColor(status).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: _statusColor(status),
        ),
      ),
    );
  }

  Color _statusColor(MilestonePhaseStatus status) {
    switch (status) {
      case MilestonePhaseStatus.active: return AppTheme.primaryIndigo;
      case MilestonePhaseStatus.completed: return AppTheme.successGreen;
      case MilestonePhaseStatus.blocked: return AppTheme.errorRed;
      case MilestonePhaseStatus.gateReview: return AppTheme.warningOrange;
      default: return Colors.grey;
    }
  }

  String _formatDate(DateTime d) => DateFormat('dd MMM').format(d);

  String _formatCurrency(double amount) {
    if (amount >= 100000) return '${(amount / 100000).toStringAsFixed(1)}L';
    if (amount >= 1000) return '${(amount / 1000).toStringAsFixed(0)}K';
    return amount.toStringAsFixed(0);
  }
}
