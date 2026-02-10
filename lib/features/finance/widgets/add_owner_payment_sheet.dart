import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:houzzdat_app/core/theme/app_theme.dart';
import 'package:intl/intl.dart';

/// Bottom sheet form for recording a payment received from the owner.
class AddOwnerPaymentSheet extends StatefulWidget {
  final List<Map<String, dynamic>> projects;
  final List<Map<String, dynamic>> owners;

  const AddOwnerPaymentSheet({
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
      builder: (_) => AddOwnerPaymentSheet(projects: projects, owners: owners),
    );
  }

  @override
  State<AddOwnerPaymentSheet> createState() => _AddOwnerPaymentSheetState();
}

class _AddOwnerPaymentSheetState extends State<AddOwnerPaymentSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _refController = TextEditingController();
  final _descriptionController = TextEditingController();

  String? _selectedOwnerId;
  String? _selectedProjectId;
  String _paymentMethod = 'bank_transfer';
  DateTime _receivedDate = DateTime.now();

  @override
  void dispose() {
    _amountController.dispose();
    _refController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _receivedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: AppTheme.primaryIndigo),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _receivedDate = picked);
  }

  void _handleSubmit() {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedOwnerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an owner')),
      );
      return;
    }

    final data = {
      'amount': double.tryParse(_amountController.text.trim()) ?? 0,
      'owner_id': _selectedOwnerId,
      'payment_method': _paymentMethod,
      'reference_number': _refController.text.trim(),
      'description': _descriptionController.text.trim(),
      'project_id': _selectedProjectId,
      'allocated_to_project': _selectedProjectId,
      'received_date': _receivedDate.toIso8601String().split('T').first,
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
                'Record Owner Payment',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: AppTheme.spacingL),

              // Owner dropdown
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

              // Payment method
              DropdownButtonFormField<String>(
                value: _paymentMethod,
                decoration: _inputDecoration('Payment Method'),
                items: const [
                  DropdownMenuItem(value: 'cash', child: Text('Cash')),
                  DropdownMenuItem(value: 'bank_transfer', child: Text('Bank Transfer')),
                  DropdownMenuItem(value: 'upi', child: Text('UPI')),
                  DropdownMenuItem(value: 'cheque', child: Text('Cheque')),
                  DropdownMenuItem(value: 'other', child: Text('Other')),
                ],
                onChanged: (v) => setState(() => _paymentMethod = v ?? _paymentMethod),
              ),
              const SizedBox(height: AppTheme.spacingM),

              // Reference number
              TextFormField(
                controller: _refController,
                decoration: _inputDecoration('Reference Number'),
              ),
              const SizedBox(height: AppTheme.spacingM),

              // Allocate to site
              DropdownButtonFormField<String?>(
                value: _selectedProjectId,
                decoration: _inputDecoration('Allocate to Site (optional)'),
                items: [
                  const DropdownMenuItem<String?>(value: null, child: Text('Unallocated')),
                  ...widget.projects.map((p) => DropdownMenuItem<String?>(
                        value: p['id']?.toString(),
                        child: Text(p['name']?.toString() ?? 'Site'),
                      )),
                ],
                onChanged: (v) => setState(() => _selectedProjectId = v),
              ),
              const SizedBox(height: AppTheme.spacingM),

              // Received date
              InkWell(
                onTap: _pickDate,
                child: InputDecorator(
                  decoration: _inputDecoration('Received Date'),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(DateFormat('dd MMM yyyy').format(_receivedDate)),
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
                maxLines: 2,
              ),
              const SizedBox(height: AppTheme.spacingL),

              // Submit
              ElevatedButton(
                onPressed: _handleSubmit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.successGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusM),
                  ),
                ),
                child: const Text(
                  'Record Payment',
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
