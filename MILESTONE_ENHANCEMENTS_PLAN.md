# Milestone System Enhancements — Implementation Plan

## Overview
Three enhancements to the existing milestone system. Two are partially implemented (Enhancement 1), one is fully pending (Enhancements 2 & 3).

---

## Current State (what was already done this session)

### Enhancement 1 — Partially implemented
The following files were already edited and are correct as-is:

**`lib/features/milestones/screens/milestone_setup_screen.dart`** — DONE
- Wizard expanded from 3 → 4 steps
- New state vars: `_siteType`, `_areaController`, `_floorsController`, `_budgetController`, `_q3WorkTypes` (renamed from `_q2WorkTypes`)
- Step indicator updated to 4 steps: Start → Details → Work Type → Timeline
- New page `_buildQ2ProjectDetailsPage()` added
- Old pages renamed: `_buildQ2Page` → `_buildQ3WorkTypePage`, `_buildQ3Page` → `_buildQ4TimelinePage`
- `_generatePlan()` passes new params: `siteType`, `areaSqft`, `numberOfFloors`, `estimatedBudgetLakhs`
- Nav bar updated: `canProceed` uses `switch`, generate button on step 3

**`lib/features/milestones/services/milestone_service.dart`** — DONE
- `generateMilestonePlan()` accepts new optional params: `siteType`, `areaSqft`, `numberOfFloors`, `estimatedBudgetLakhs`
- These are conditionally added to the request body sent to the edge function

**`supabase/Functions/generate-milestone-plan/index.ts`** — PARTIALLY DONE
- New fields destructured from request body: `site_type`, `area_sqft`, `number_of_floors`, `estimated_budget_lakhs`
- **NOT YET DONE**: These variables are not yet used in the AI system prompt

---

## Remaining Work

### Enhancement 1 — Complete the edge function

**File**: `supabase/Functions/generate-milestone-plan/index.ts`

After the line:
```ts
const startingContext = STARTING_POINT_CONTEXT[q1] || STARTING_POINT_CONTEXT.empty_plot
```

Add a project details context string:
```ts
// Build project details context from optional fields
const projectDetailsLines: string[] = []
if (site_type) projectDetailsLines.push(`Site type: ${site_type.replace('_', ' ')}`)
if (area_sqft) projectDetailsLines.push(`Construction area: ${area_sqft} sq ft`)
if (number_of_floors !== undefined && number_of_floors !== null) {
  projectDetailsLines.push(`Number of floors: ${number_of_floors === 0 ? 'Ground floor only' : number_of_floors}`)
}
if (estimated_budget_lakhs) projectDetailsLines.push(`Estimated budget: ₹${estimated_budget_lakhs} Lakhs`)
const projectDetailsContext = projectDetailsLines.length > 0
  ? `\nPROJECT DETAILS:\n${projectDetailsLines.join('\n')}`
  : ''
```

Then update the system prompt (currently around line 92) — add `${projectDetailsContext}` after the `STARTING POINT:` line:
```ts
const systemPrompt = `You are an expert Indian construction project manager. Generate a realistic milestone plan for a construction project.

${MODULE_TEMPLATES}

STARTING POINT: ${startingContext}
WORK TYPES REQUESTED: ${q2}
TIMELINE & CONSTRAINTS: ${q3}${projectDetailsContext}

OUTPUT REQUIREMENTS:
...`
```

Also update the user message (around line 144) to include project details:
```ts
{ role: 'user', content: `Generate the construction milestone plan for project "${project?.name || 'Construction Project'}". Starting point: ${q1}, Work types: ${q2}, Timeline: ${q3}${projectDetailsContext ? '. ' + projectDetailsContext.trim() : ''}` }
```

---

### Enhancement 2 — Phase & KR editing

**File 1**: `lib/features/milestones/services/milestone_service.dart`

Add these 5 methods at the end of the `// PHASE CRUD` section (before the `// AI PLAN GENERATION` section):

```dart
/// Update a phase's editable fields
Future<void> updatePhase({
  required String phaseId,
  String? name,
  String? description,
  DateTime? plannedStart,
  DateTime? plannedEnd,
  double? budgetAllocated,
}) async {
  final updates = <String, dynamic>{};
  if (name != null) updates['name'] = name;
  if (description != null) updates['description'] = description;
  if (plannedStart != null) updates['planned_start'] = plannedStart.toIso8601String().split('T')[0];
  if (plannedEnd != null) updates['planned_end'] = plannedEnd.toIso8601String().split('T')[0];
  if (budgetAllocated != null) updates['budget_allocated'] = budgetAllocated;
  if (updates.isEmpty) return;
  await _supabase.from('milestone_phases').update(updates).eq('id', phaseId);
}

/// Delete a phase (cascades to key_results via DB constraint)
Future<void> deletePhase(String phaseId) async {
  await _supabase.from('milestone_phases').delete().eq('id', phaseId);
}

/// Add a new key result to a phase
Future<void> addKeyResult({
  required String phaseId,
  required String projectId,
  required String accountId,
  required String title,
  required String metricType,
  double? targetValue,
  String? unit,
}) async {
  await _supabase.from('key_results').insert({
    'phase_id': phaseId,
    'project_id': projectId,
    'account_id': accountId,
    'title': title,
    'metric_type': metricType,
    'target_value': targetValue ?? 1,
    'current_value': 0,
    'unit': unit,
    'auto_track': false,
    'completed': false,
  });
}

/// Update a key result's definition (not its progress value)
Future<void> updateKeyResult({
  required String keyResultId,
  String? title,
  String? metricType,
  double? targetValue,
  String? unit,
}) async {
  final updates = <String, dynamic>{};
  if (title != null) updates['title'] = title;
  if (metricType != null) updates['metric_type'] = metricType;
  if (targetValue != null) updates['target_value'] = targetValue;
  if (unit != null) updates['unit'] = unit;
  if (updates.isEmpty) return;
  await _supabase.from('key_results').update(updates).eq('id', keyResultId);
}

/// Delete a key result
Future<void> deleteKeyResult(String keyResultId) async {
  await _supabase.from('key_results').delete().eq('id', keyResultId);
}
```

---

**File 2**: `lib/features/milestones/widgets/phase_card_widget.dart`

Add a `PopupMenuButton` in the phase header row (managers only). The header Row currently ends with the chevron icon. Add the popup before the chevron:

```dart
// In _PhaseCardWidgetState, add service reference (already exists):
// final _milestoneService = MilestoneService();  ← already there

// In the header Row, insert between status chip and chevron:
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
```

Add these 3 methods to `_PhaseCardWidgetState`:

```dart
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
```

Note: `_dateField` uses `DateFormat` — ensure `import 'package:intl/intl.dart';` is already at the top (it is, it's used for `_formatDate`).

---

**File 3**: `lib/features/milestones/widgets/key_result_tile.dart`

Wrap the `GestureDetector` in `KeyResultTile.build()` with a `GestureDetector` that handles long-press. Change:

```dart
return GestureDetector(
  onTap: canEdit ? onTap : null,
  child: Padding(...),
);
```

To:

```dart
return GestureDetector(
  onTap: canEdit ? onTap : null,
  onLongPress: canEdit ? () => _showKrOptions(context) : null,
  child: Padding(...),
);
```

Add a static method (or convert to StatefulWidget if needed — but simpler to use a callback approach). Since `KeyResultTile` is `StatelessWidget`, pass the edit/delete callbacks as optional params:

**Better approach** — add two optional callbacks to `KeyResultTile`:
```dart
class KeyResultTile extends StatelessWidget {
  final KeyResult keyResult;
  final bool canEdit;
  final VoidCallback? onTap;
  final VoidCallback? onEditTap;     // ADD
  final VoidCallback? onDeleteTap;   // ADD
  ...
}
```

In the build method:
```dart
return GestureDetector(
  onTap: canEdit ? onTap : null,
  onLongPress: (canEdit && (onEditTap != null || onDeleteTap != null))
      ? () => showModalBottomSheet(
            context: context,
            builder: (_) => SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (onEditTap != null)
                    ListTile(
                      leading: const Icon(LucideIcons.pencil),
                      title: const Text('Edit Key Result'),
                      onTap: () { Navigator.pop(context); onEditTap!(); },
                    ),
                  if (onDeleteTap != null)
                    ListTile(
                      leading: const Icon(LucideIcons.trash2, color: Colors.red),
                      title: const Text('Delete Key Result', style: TextStyle(color: Colors.red)),
                      onTap: () { Navigator.pop(context); onDeleteTap!(); },
                    ),
                ],
              ),
            ),
          )
      : null,
  child: Padding(...),
);
```

In `phase_card_widget.dart`, update the `KeyResultTile` usage inside `_buildExpandedContent`:

```dart
...phase.keyResults.map((kr) => KeyResultTile(
  keyResult: kr,
  canEdit: widget.isManager && phase.isActive,
  onTap: () => _editKeyResult(kr),
  onEditTap: widget.isManager ? () => _showEditKrSheet(kr) : null,
  onDeleteTap: widget.isManager ? () => _confirmDeleteKr(kr) : null,
)),
```

Add these two methods to `_PhaseCardWidgetState`:

```dart
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
```

---

### Enhancement 3 — Radio button KR completion

**File**: `lib/features/milestones/widgets/key_result_tile.dart`

Replace the entire `UpdateKeyResultDialog` class (lines 86–182) with:

```dart
/// Dialog to update a key result's progress via radio buttons
class UpdateKeyResultDialog extends StatefulWidget {
  final KeyResult keyResult;
  final void Function(double newValue) onUpdate;

  const UpdateKeyResultDialog({
    super.key,
    required this.keyResult,
    required this.onUpdate,
  });

  static Future<void> show(
    BuildContext context,
    KeyResult kr,
    void Function(double) onUpdate,
  ) {
    return showDialog(
      context: context,
      builder: (_) => UpdateKeyResultDialog(keyResult: kr, onUpdate: onUpdate),
    );
  }

  @override
  State<UpdateKeyResultDialog> createState() => _UpdateKeyResultDialogState();
}

class _UpdateKeyResultDialogState extends State<UpdateKeyResultDialog> {
  late double _selectedValue;

  @override
  void initState() {
    super.initState();
    // Determine current radio selection from currentValue
    final current = widget.keyResult.currentValue;
    final target = widget.keyResult.targetValue ?? 1;
    if (current <= 0) {
      _selectedValue = 0;
    } else if (current >= target) {
      _selectedValue = target;
    } else {
      _selectedValue = target * 0.5; // In Progress
    }
  }

  @override
  Widget build(BuildContext context) {
    final target = widget.keyResult.targetValue ?? 1;
    final inProgressValue = target * 0.5;

    return AlertDialog(
      title: Row(
        children: [
          const Icon(LucideIcons.clipboardCheck, size: 18, color: AppTheme.primaryIndigo),
          const SizedBox(width: 8),
          const Text('Update Progress', style: TextStyle(fontSize: 16)),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.keyResult.title,
            style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 16),
          RadioListTile<double>(
            value: 0,
            groupValue: _selectedValue,
            onChanged: (v) => setState(() => _selectedValue = v!),
            title: const Text('Not Started', style: TextStyle(fontSize: 14)),
            secondary: const Icon(LucideIcons.circle, size: 16, color: AppTheme.textSecondary),
            contentPadding: EdgeInsets.zero,
            activeColor: AppTheme.primaryIndigo,
          ),
          RadioListTile<double>(
            value: inProgressValue,
            groupValue: _selectedValue,
            onChanged: (v) => setState(() => _selectedValue = v!),
            title: const Text('In Progress', style: TextStyle(fontSize: 14)),
            secondary: const Icon(LucideIcons.clock, size: 16, color: AppTheme.warningOrange),
            contentPadding: EdgeInsets.zero,
            activeColor: AppTheme.primaryIndigo,
          ),
          RadioListTile<double>(
            value: target,
            groupValue: _selectedValue,
            onChanged: (v) => setState(() => _selectedValue = v!),
            title: const Text('Completed', style: TextStyle(fontSize: 14)),
            secondary: const Icon(LucideIcons.checkCircle, size: 16, color: AppTheme.successGreen),
            contentPadding: EdgeInsets.zero,
            activeColor: AppTheme.primaryIndigo,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            widget.onUpdate(_selectedValue);
            Navigator.pop(context);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryIndigo,
            foregroundColor: Colors.white,
          ),
          child: const Text('Update'),
        ),
      ],
    );
  }
}
```

Note: `LucideIcons.clipboardCheck`, `LucideIcons.clock` must exist in the lucide_icons package. If not, replace with `LucideIcons.checkSquare` and `LucideIcons.timer` respectively.

---

## Files Summary

| File | Status | Change |
|------|--------|--------|
| `lib/features/milestones/screens/milestone_setup_screen.dart` | **DONE** | 4-step wizard with project details page |
| `lib/features/milestones/services/milestone_service.dart` | **DONE** (Enh 1) + **TODO** (Enh 2) | New params added; still need 5 CRUD methods |
| `supabase/Functions/generate-milestone-plan/index.ts` | **PARTIAL** | Fields destructured, not yet in prompt |
| `lib/features/milestones/widgets/key_result_tile.dart` | **TODO** | Radio dialog + long-press callbacks |
| `lib/features/milestones/widgets/phase_card_widget.dart` | **TODO** | 3-dot menu + edit/delete/add KR sheets |

## Verification
1. Setup wizard: open Insights → Milestones → Setup Milestones → verify 4 steps appear with Details step showing site type cards + area/floors/budget fields
2. Generate plan → check Supabase edge function logs for project details in the prompt
3. Expand a phase → verify 3-dot menu appears for manager role → test Edit/Delete/Add KR
4. Tap a KR tile → verify radio button dialog with 3 options, not a text field
5. Select "Completed" on a KR → verify it shows green checkmark and progress bar fills
6. Long-press a KR → verify Edit/Delete bottom sheet appears
