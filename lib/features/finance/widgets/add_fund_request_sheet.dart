import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:houzzdat_app/core/theme/app_theme.dart';

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
      backgroundColor: Colors.white,
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
    if (_selectedProjectId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a site')),
      );
      return;
    }
    if (_selectedOwnerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an owner')),
      );
      return;
    }

    final data = {
      'title': _titleController.text.trim(),
      'description': _descriptionController.text.trim(),
      'amount': double.tryParse(_amountController.text.trim()) ?? 0,
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

              // Title
              TextFormField(
                controller: _titleController,
                decoration: _inputDecoration('Title *'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: AppTheme.spacingM),

              // Amount
              TextFormField(
                controller: _amountController,
                decoration: _inputDecoration('Amount (\u20B9) *'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Required';
                  if (double.tryParse(v.trim()) == null) return 'Invalid amount';
                  return null;
                },
              ),
              const SizedBox(height: AppTheme.spacingM),

              // Site
              DropdownButtonFormField<String>(
                value: _selectedProjectId,
                decoration: _inputDecoration('Site *'),
                items: widget.projects
                    .map((p) => DropdownMenuItem<String>(
                          value: p['id']?.toString(),
                          child: Text(p['name']?.toString() ?? 'Site'),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _selectedProjectId = v),
              ),
              const SizedBox(height: AppTheme.spacingM),

              // Owner
              DropdownButtonFormField<String>(
                value: _selectedOwnerId,
                decoration: _inputDecoration('Owner *'),
                items: widget.owners
                    .map((o) => DropdownMenuItem<String>(
                          value: o['owner_id']?.toString(),
                          child: Text(o['full_name']?.toString() ?? o['email']?.toString() ?? 'Owner'),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _selectedOwnerId = v),
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

              // Description
              TextFormField(
                controller: _descriptionController,
                decoration: _inputDecoration('Description'),
                maxLines: 3,
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
        borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
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
