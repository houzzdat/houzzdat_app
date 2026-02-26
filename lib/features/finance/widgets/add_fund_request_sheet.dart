import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:houzzdat_app/core/theme/app_theme.dart';
import 'package:houzzdat_app/core/widgets/input_formatters.dart';
import 'package:houzzdat_app/core/widgets/page_transitions.dart';

/// Bottom sheet form for creating a fund request to the owner.
class AddFundRequestSheet extends StatefulWidget {
  final List<Map<String, dynamic>> projects;
  final List<Map<String, dynamic>> owners;

  const AddFundRequestSheet({
    super.key,
    required this.projects,
    required this.owners,
  });

  static Future<Map<String, dynamic>?> show(
    BuildContext context, {
    required List<Map<String, dynamic>> projects,
    required List<Map<String, dynamic>> owners,
  }) {
    return showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.radiusXL)),
      ),
      builder: (_) => AddFundRequestSheet(projects: projects, owners: owners),
    );
  }

  @override
  State<AddFundRequestSheet> createState() => _AddFundRequestSheetState();
}

class _AddFundRequestSheetState extends State<AddFundRequestSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();

  String? _selectedProjectId;
  String? _selectedOwnerId;
  String _urgency = 'normal';

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  void _handleSubmit() {
    if (!_formKey.currentState!.validate()) return;

    final data = {
      'title': _titleController.text.trim(),
      'description': _descriptionController.text.trim(),
      'amount': double.tryParse(_amountController.text.trim().replaceAll(',', '')) ?? 0,
      'project_id': _selectedProjectId,
      'owner_id': _selectedOwnerId,
      'urgency': _urgency,
    };

    Navigator.of(context).pop(data);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(
        left: AppTheme.spacingM,
        right: AppTheme.spacingM,
        top: AppTheme.spacingM,
        bottom: bottomInset + AppTheme.spacingM,
      ),
      child: SingleChildScrollView(
        child: FocusTraversalGroup(
          policy: OrderedTraversalPolicy(), // UX-audit #22: logical keyboard nav order
          child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: AppTheme.spacingM),

              const Text(
                'New Fund Request',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: AppTheme.spacingL),

              // Title — UX-audit CI-11: input validation
              TextFormField(
                controller: _titleController,
                decoration: _inputDecoration('Title *'),
                maxLength: 100,
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: AppTheme.spacingM),

              // Amount
              TextFormField(
                controller: _amountController,
                decoration: _inputDecoration('Amount (\u20B9) *'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[\d.,]')),
                  _SingleDecimalFormatter(),
                  IndianNumberFormatter(), // UX-audit #13: live currency formatting
                ],
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Required';
                  final amount = double.tryParse(v.trim().replaceAll(',', ''));
                  if (amount == null) return 'Invalid amount';
                  if (amount <= 0) return 'Amount must be greater than zero';
                  return null;
                },
              ),
              const SizedBox(height: AppTheme.spacingM),

              // Site — UX-audit #14: searchable dropdown for 10+ items
              SearchableDropdown<String>(
                label: 'Site *',
                hint: 'Select a site',
                value: _selectedProjectId,
                items: widget.projects
                    .map((p) => SearchableDropdownItem<String>(
                          value: p['id']?.toString() ?? '',
                          label: p['name']?.toString() ?? 'Site',
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _selectedProjectId = v),
                validator: (v) => v == null ? 'Please select a site' : null,
              ),
              const SizedBox(height: AppTheme.spacingM),

              // Owner — UX-audit #14: searchable dropdown for 10+ items
              SearchableDropdown<String>(
                label: 'Owner *',
                hint: 'Select an owner',
                value: _selectedOwnerId,
                items: widget.owners
                    .map((o) => SearchableDropdownItem<String>(
                          value: o['owner_id']?.toString() ?? '',
                          label: o['full_name']?.toString() ?? o['email']?.toString() ?? 'Owner',
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _selectedOwnerId = v),
                validator: (v) => v == null ? 'Please select an owner' : null,
              ),
              const SizedBox(height: AppTheme.spacingM),

              // Urgency
              DropdownButtonFormField<String>(
                value: _urgency,
                decoration: _inputDecoration('Urgency'),
                items: const [
                  DropdownMenuItem(value: 'low', child: Text('Low')),
                  DropdownMenuItem(value: 'normal', child: Text('Normal')),
                  DropdownMenuItem(value: 'high', child: Text('High')),
                  DropdownMenuItem(value: 'critical', child: Text('Critical')),
                ],
                onChanged: (v) => setState(() => _urgency = v ?? _urgency),
              ),
              const SizedBox(height: AppTheme.spacingM),

              // Description — UX-audit CI-11: input validation
              TextFormField(
                controller: _descriptionController,
                decoration: _inputDecoration('Description'),
                maxLines: 3,
                maxLength: 500,
              ),
              const SizedBox(height: AppTheme.spacingL),

              // Submit
              ElevatedButton(
                onPressed: _handleSubmit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryIndigo,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusM),
                  ),
                ),
                child: const Text(
                  'Submit Request',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
            ],
          ),
        ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: AppTheme.textSecondary),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusM),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusM),
        borderSide: const BorderSide(color: AppTheme.dividerColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusM),
        borderSide: const BorderSide(color: AppTheme.primaryIndigo, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingM,
        vertical: AppTheme.spacingS,
      ),
    );
  }
}

/// Prevents multiple decimal points in numeric input.
class _SingleDecimalFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;
    if ('.'.allMatches(text).length > 1) return oldValue;
    return newValue;
  }
}
