import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:houzzdat_app/core/theme/app_theme.dart';
import 'package:intl/intl.dart';

/// Bottom sheet form for adding a payment.
/// Can optionally link to an invoice.
class AddPaymentSheet extends StatefulWidget {
  final List<Map<String, dynamic>> projects;
  final List<Map<String, dynamic>> invoices;
  final String? preselectedInvoiceId;
  final String? preselectedProjectId;

  const AddPaymentSheet({
    super.key,
    required this.projects,
    this.invoices = const [],
    this.preselectedInvoiceId,
    this.preselectedProjectId,
  });

  static Future<Map<String, dynamic>?> show(
    BuildContext context, {
    required List<Map<String, dynamic>> projects,
    List<Map<String, dynamic>> invoices = const [],
    String? preselectedInvoiceId,
    String? preselectedProjectId,
  }) {
    return showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.radiusXL)),
      ),
      builder: (_) => AddPaymentSheet(
        projects: projects,
        invoices: invoices,
        preselectedInvoiceId: preselectedInvoiceId,
        preselectedProjectId: preselectedProjectId,
      ),
    );
  }

  @override
  State<AddPaymentSheet> createState() => _AddPaymentSheetState();
}

class _AddPaymentSheetState extends State<AddPaymentSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _refController = TextEditingController();
  final _paidToController = TextEditingController();
  final _descriptionController = TextEditingController();

  String? _selectedProjectId;
  String? _selectedInvoiceId;
  String _paymentMethod = 'bank_transfer';
  DateTime _paymentDate = DateTime.now();

  static final _currencyFormat =
      NumberFormat.currency(locale: 'en_IN', symbol: '\u20B9', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _selectedInvoiceId = widget.preselectedInvoiceId;
    _selectedProjectId = widget.preselectedProjectId;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _refController.dispose();
    _paidToController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _paymentDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: AppTheme.primaryIndigo),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _paymentDate = picked);
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
      'amount': double.tryParse(_amountController.text.trim()) ?? 0,
      'payment_method': _paymentMethod,
      'reference_number': _refController.text.trim(),
      'paid_to': _paidToController.text.trim(),
      'description': _descriptionController.text.trim(),
      'project_id': _selectedProjectId,
      'invoice_id': _selectedInvoiceId,
      'payment_date': _paymentDate.toIso8601String().split('T').first,
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
                'Add Payment',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: AppTheme.spacingL),

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

              // Paid to
              TextFormField(
                controller: _paidToController,
                decoration: _inputDecoration('Paid To'),
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

              // Link to invoice (optional)
              if (widget.invoices.isNotEmpty)
                DropdownButtonFormField<String?>(
                  value: _selectedInvoiceId,
                  decoration: _inputDecoration('Link to Invoice (optional)'),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('None'),
                    ),
                    ...widget.invoices.map((inv) => DropdownMenuItem<String?>(
                          value: inv['id']?.toString(),
                          child: Text(
                            '#${inv['invoice_number']} - ${inv['vendor']} (${_currencyFormat.format((inv['amount'] as num?)?.toDouble() ?? 0)})',
                          ),
                        )),
                  ],
                  onChanged: (v) => setState(() => _selectedInvoiceId = v),
                ),
              if (widget.invoices.isNotEmpty) const SizedBox(height: AppTheme.spacingM),

              // Payment Date
              InkWell(
                onTap: _pickDate,
                child: InputDecorator(
                  decoration: _inputDecoration('Payment Date'),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(DateFormat('dd MMM yyyy').format(_paymentDate)),
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
                child: const Text(
                  'Add Payment',
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
