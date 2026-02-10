import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:houzzdat_app/core/theme/app_theme.dart';
import 'package:intl/intl.dart';

/// Bottom sheet form for creating a new invoice.
/// Returns a Map with invoice data on submit, or null if cancelled.
class AddInvoiceSheet extends StatefulWidget {
  final List<Map<String, dynamic>> projects;

  const AddInvoiceSheet({super.key, required this.projects});

  static Future<Map<String, dynamic>?> show(
    BuildContext context, {
    required List<Map<String, dynamic>> projects,
  }) {
    return showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.radiusXL)),
      ),
      builder: (_) => AddInvoiceSheet(projects: projects),
    );
  }

  @override
  State<AddInvoiceSheet> createState() => _AddInvoiceSheetState();
}

class _AddInvoiceSheetState extends State<AddInvoiceSheet> {
  final _formKey = GlobalKey<FormState>();
  final _invoiceNumberController = TextEditingController();
  final _vendorController = TextEditingController();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _notesController = TextEditingController();

  String? _selectedProjectId;
  DateTime? _dueDate;
  bool _submitForApproval = false;

  @override
  void dispose() {
    _invoiceNumberController.dispose();
    _vendorController.dispose();
    _amountController.dispose();
    _descriptionController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDueDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: AppTheme.primaryIndigo),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => _dueDate = picked);
    }
  }

  void _handleSubmit() {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedProjectId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a site')),
      );
      return;
    }

    final data = {
      'invoice_number': _invoiceNumberController.text.trim(),
      'vendor': _vendorController.text.trim(),
      'amount': double.tryParse(_amountController.text.trim()) ?? 0,
      'description': _descriptionController.text.trim(),
      'notes': _notesController.text.trim(),
      'project_id': _selectedProjectId,
      'due_date': _dueDate?.toIso8601String().split('T').first,
      'status': _submitForApproval ? 'submitted' : 'draft',
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

              // Title
              const Text(
                'New Invoice',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: AppTheme.spacingL),

              // Invoice Number
              TextFormField(
                controller: _invoiceNumberController,
                decoration: _inputDecoration('Invoice Number *'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: AppTheme.spacingM),

              // Vendor
              TextFormField(
                controller: _vendorController,
                decoration: _inputDecoration('Vendor / Supplier *'),
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

              // Site dropdown
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

              // Due Date
              InkWell(
                onTap: _pickDueDate,
                child: InputDecorator(
                  decoration: _inputDecoration('Due Date'),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _dueDate != null
                            ? DateFormat('dd MMM yyyy').format(_dueDate!)
                            : 'Select due date',
                        style: TextStyle(
                          color: _dueDate != null ? AppTheme.textPrimary : AppTheme.textSecondary,
                        ),
                      ),
                      const Icon(Icons.calendar_today, size: 18, color: AppTheme.textSecondary),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppTheme.spacingM),

              // Description
              TextFormField(
                controller: _descriptionController,
                decoration: _inputDecoration('Description'),
                maxLines: 3,
              ),
              const SizedBox(height: AppTheme.spacingM),

              // Notes
              TextFormField(
                controller: _notesController,
                decoration: _inputDecoration('Notes'),
                maxLines: 2,
              ),
              const SizedBox(height: AppTheme.spacingM),

              // Submit for approval toggle
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Submit for approval immediately',
                  style: TextStyle(fontSize: 14),
                ),
                value: _submitForApproval,
                activeColor: AppTheme.primaryIndigo,
                onChanged: (v) => setState(() => _submitForApproval = v),
              ),
              const SizedBox(height: AppTheme.spacingM),

              // Submit button
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
                child: Text(
                  _submitForApproval ? 'Create & Submit' : 'Save as Draft',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
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
