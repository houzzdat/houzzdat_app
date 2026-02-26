import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:houzzdat_app/core/theme/app_theme.dart';
import 'package:houzzdat_app/core/widgets/shared_widgets.dart';
import 'package:houzzdat_app/features/milestones/services/checklist_service.dart';
import 'package:houzzdat_app/features/milestones/widgets/evidence_capture_widget.dart';
import 'package:houzzdat_app/models/models.dart';

/// Modal bottom sheet that displays and manages checklist items for a phase gate.
/// Supports evidence upload, override reasons, and gate submission.
class GateChecklistSheet extends StatefulWidget {
  final MilestonePhase phase;
  final ChecklistGateType gateType;
  final String projectId;
  final String accountId;
  final VoidCallback onGateCompleted;

  const GateChecklistSheet({
    super.key,
    required this.phase,
    required this.gateType,
    required this.projectId,
    required this.accountId,
    required this.onGateCompleted,
  });

  static Future<void> show(
    BuildContext context, {
    required MilestonePhase phase,
    required ChecklistGateType gateType,
    required String projectId,
    required String accountId,
    required VoidCallback onGateCompleted,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => GateChecklistSheet(
        phase: phase,
        gateType: gateType,
        projectId: projectId,
        accountId: accountId,
        onGateCompleted: onGateCompleted,
      ),
    );
  }

  @override
  State<GateChecklistSheet> createState() => _GateChecklistSheetState();
}

class _GateChecklistSheetState extends State<GateChecklistSheet> {
  final _service = ChecklistService();

  List<ChecklistItemWithCompletion> _items = [];
  bool _isLoading = true;
  bool _isSubmitting = false;

  // Track uploading state per item id
  final Map<String, bool> _uploadingEvidence = {};

  @override
  void initState() {
    super.initState();
    _loadChecklist();
  }

  Future<void> _loadChecklist() async {
    if (widget.phase.moduleId == null) {
      setState(() { _items = []; _isLoading = false; });
      return;
    }

    setState(() => _isLoading = true);
    final items = await _service.getChecklistForPhase(
      phaseId: widget.phase.id,
      moduleId: widget.phase.moduleId!,
      gateType: widget.gateType,
      projectId: widget.projectId,
      accountId: widget.accountId,
    );

    if (mounted) setState(() { _items = items; _isLoading = false; });
  }

  Future<void> _toggleItem(ChecklistItemWithCompletion itemWithComp, bool value) async {
    setState(() {
      final idx = _items.indexOf(itemWithComp);
      if (idx == -1) return;
      _items[idx] = ChecklistItemWithCompletion(
        item: itemWithComp.item,
        completion: ChecklistCompletion(
          id: itemWithComp.completion?.id ?? '',
          phaseId: widget.phase.id,
          checklistItemId: itemWithComp.item.id,
          projectId: widget.projectId,
          accountId: widget.accountId,
          isCompleted: value,
          createdAt: DateTime.now(),
        ),
      );
    });

    try {
      final updated = await _service.toggleItemComplete(
        existingCompletionId: itemWithComp.completion?.id.isNotEmpty == true
            ? itemWithComp.completion!.id
            : null,
        checklistItemId: itemWithComp.item.id,
        phaseId: widget.phase.id,
        projectId: widget.projectId,
        accountId: widget.accountId,
        isCompleted: value,
        evidenceUrl: itemWithComp.completion?.evidenceUrl,
        evidenceType: itemWithComp.completion?.evidenceType,
      );

      if (mounted) {
        final idx = _items.indexWhere((i) => i.item.id == itemWithComp.item.id);
        if (idx != -1) {
          setState(() {
            _items[idx] = ChecklistItemWithCompletion(
              item: itemWithComp.item,
              completion: updated,
            );
          });
        }
      }
    } catch (e) {
      debugPrint('[GateChecklistSheet] toggleItem error: $e');
    }
  }

  Future<void> _handlePhotoEvidence(
    ChecklistItemWithCompletion itemWithComp,
    XFile photo,
  ) async {
    setState(() => _uploadingEvidence[itemWithComp.item.id] = true);
    try {
      final url = await _service.uploadPhotoEvidence(
        photo: photo,
        phaseId: widget.phase.id,
        itemId: itemWithComp.item.id,
        accountId: widget.accountId,
      );

      final updated = await _service.toggleItemComplete(
        existingCompletionId: itemWithComp.completion?.id.isNotEmpty == true
            ? itemWithComp.completion!.id
            : null,
        checklistItemId: itemWithComp.item.id,
        phaseId: widget.phase.id,
        projectId: widget.projectId,
        accountId: widget.accountId,
        isCompleted: true,
        evidenceUrl: url,
        evidenceType: EvidenceRequiredType.photo,
      );

      if (mounted) {
        final idx = _items.indexWhere((i) => i.item.id == itemWithComp.item.id);
        if (idx != -1) {
          setState(() {
            _items[idx] = ChecklistItemWithCompletion(
              item: itemWithComp.item,
              completion: updated,
            );
          });
        }
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Evidence upload failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _uploadingEvidence.remove(itemWithComp.item.id));
    }
  }

  Future<void> _handleDocumentEvidence(
    ChecklistItemWithCompletion itemWithComp,
    File file,
  ) async {
    setState(() => _uploadingEvidence[itemWithComp.item.id] = true);
    try {
      final url = await _service.uploadDocumentEvidence(
        file: file,
        phaseId: widget.phase.id,
        itemId: itemWithComp.item.id,
        accountId: widget.accountId,
      );

      final updated = await _service.toggleItemComplete(
        existingCompletionId: itemWithComp.completion?.id.isNotEmpty == true
            ? itemWithComp.completion!.id
            : null,
        checklistItemId: itemWithComp.item.id,
        phaseId: widget.phase.id,
        projectId: widget.projectId,
        accountId: widget.accountId,
        isCompleted: true,
        evidenceUrl: url,
        evidenceType: EvidenceRequiredType.document,
      );

      if (mounted) {
        final idx = _items.indexWhere((i) => i.item.id == itemWithComp.item.id);
        if (idx != -1) {
          setState(() {
            _items[idx] = ChecklistItemWithCompletion(
              item: itemWithComp.item,
              completion: updated,
            );
          });
        }
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Evidence upload failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _uploadingEvidence.remove(itemWithComp.item.id));
    }
  }

  Future<void> _submitGate() async {
    setState(() => _isSubmitting = true);
    try {
      final error = await _service.submitGate(
        phaseId: widget.phase.id,
        projectId: widget.projectId,
        accountId: widget.accountId,
        gateType: widget.gateType,
        items: _items,
      );

      if (error != null) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error), backgroundColor: AppTheme.errorRed),
        );
        return;
      }

      if (mounted) {
        Navigator.pop(context);
        widget.onGateCompleted();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.gateType == ChecklistGateType.preStart
                ? 'Phase started successfully!'
                : 'Phase marked complete!'),
            backgroundColor: AppTheme.successGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Submission failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  int get _criticalIncompleteCount => _items
      .where((i) => i.item.isCritical && !i.isCompleted && !i.isOverridden)
      .length;

  int get _totalCompleted => _items.where((i) => i.isCompleted).length;

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    return Container(
      height: screenHeight * 0.88,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          _buildHeader(),
          _buildProgress(),
          Expanded(child: _buildChecklistContent()),
          _buildSubmitButton(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Column(
        children: [
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryIndigo.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  widget.gateType == ChecklistGateType.preStart
                      ? LucideIcons.playCircle
                      : LucideIcons.checkSquare,
                  color: AppTheme.primaryIndigo,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.gateType.label,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      widget.phase.name,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildProgress() {
    if (_items.isEmpty) return const SizedBox.shrink();
    final progress = _totalCompleted / _items.length;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$_totalCompleted of ${_items.length} completed',
                style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
              if (_criticalIncompleteCount > 0)
                Row(
                  children: [
                    const Icon(LucideIcons.alertCircle, size: 12, color: AppTheme.errorRed),
                    const SizedBox(width: 4),
                    Text(
                      '$_criticalIncompleteCount critical remaining',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.errorRed,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation(
                _criticalIncompleteCount > 0 ? AppTheme.warningOrange : AppTheme.successGreen,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChecklistContent() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_items.isEmpty) {
      return const EmptyStateWidget(
        icon: LucideIcons.clipboardList,
        title: 'No checklist items',
        subtitle: 'This phase has no checklist configured',
      );
    }

    // Group by role
    final grouped = <ChecklistRole, List<ChecklistItemWithCompletion>>{};
    for (final item in _items) {
      grouped.putIfAbsent(item.item.role, () => []).add(item);
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      children: [
        for (final role in ChecklistRole.values)
          if (grouped.containsKey(role)) ...[
            _buildRoleHeader(role),
            ...grouped[role]!.map((item) => _buildChecklistItem(item)),
            const SizedBox(height: 8),
          ],
      ],
    );
  }

  Widget _buildRoleHeader(ChecklistRole role) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 12, 4, 6),
      child: Row(
        children: [
          Icon(_roleIcon(role), size: 14, color: AppTheme.textSecondary),
          const SizedBox(width: 6),
          Text(
            '${role.label.toUpperCase()} CHECKLIST',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: AppTheme.textSecondary,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChecklistItem(ChecklistItemWithCompletion itemWithComp) {
    final item = itemWithComp.item;
    final isUploading = _uploadingEvidence[item.id] == true;

    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      elevation: 0,
      color: itemWithComp.isCompleted
          ? AppTheme.successGreen.withValues(alpha: 0.04)
          : item.isCritical
              ? AppTheme.errorRed.withValues(alpha: 0.03)
              : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: itemWithComp.isCompleted
              ? AppTheme.successGreen.withValues(alpha: 0.3)
              : item.isCritical
                  ? AppTheme.errorRed.withValues(alpha: 0.3)
                  : Colors.grey[200]!,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Checkbox
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: SizedBox(
                width: 24,
                height: 24,
                child: Checkbox(
                  value: itemWithComp.isCompleted,
                  onChanged: isUploading
                      ? null
                      : (val) => _toggleItem(itemWithComp, val ?? false),
                  activeColor: AppTheme.successGreen,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ),
            const SizedBox(width: 10),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (item.isCritical) ...[
                        const Icon(LucideIcons.alertCircle, size: 12, color: AppTheme.errorRed),
                        const SizedBox(width: 4),
                      ],
                      Expanded(
                        child: Text(
                          item.itemText,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            decoration: itemWithComp.isCompleted
                                ? TextDecoration.lineThrough
                                : null,
                            color: itemWithComp.isCompleted
                                ? AppTheme.textSecondary
                                : null,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (item.isCritical)
                    const Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: Text(
                        'Critical — must complete',
                        style: TextStyle(fontSize: 10, color: AppTheme.errorRed),
                      ),
                    ),
                  if (item.evidenceRequired.hasEvidence) ...[
                    const SizedBox(height: 6),
                    if (isUploading)
                      const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else
                      EvidenceCaptureWidget(
                        type: item.evidenceRequired,
                        existingUrl: itemWithComp.completion?.evidenceUrl,
                        isCompleted: itemWithComp.isCompleted,
                        onPhotoCaptured: (photo) => _handlePhotoEvidence(itemWithComp, photo),
                        onDocumentPicked: (file) => _handleDocumentEvidence(itemWithComp, file),
                      ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    final canSubmit = _criticalIncompleteCount == 0;
    final label = widget.gateType == ChecklistGateType.preStart
        ? 'Start Phase'
        : 'Mark Phase Complete';

    return Container(
      padding: EdgeInsets.only(
        left: 16, right: 16, top: 12,
        bottom: 12 + MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 8)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!canSubmit)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                '$_criticalIncompleteCount critical item(s) must be completed first',
                style: const TextStyle(fontSize: 12, color: AppTheme.errorRed),
                textAlign: TextAlign.center,
              ),
            ),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: (canSubmit && !_isSubmitting) ? _submitGate : null,
              icon: _isSubmitting
                  ? const SizedBox(width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Icon(widget.gateType == ChecklistGateType.preStart
                      ? LucideIcons.playCircle
                      : LucideIcons.checkCircle),
              label: Text(_isSubmitting ? 'Submitting...' : label),
              style: ElevatedButton.styleFrom(
                backgroundColor: canSubmit ? AppTheme.primaryIndigo : Colors.grey,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _roleIcon(ChecklistRole role) {
    switch (role) {
      case ChecklistRole.manager: return LucideIcons.briefcase;
      case ChecklistRole.worker: return LucideIcons.hardHat;
      case ChecklistRole.owner: return LucideIcons.user;
    }
  }
}
