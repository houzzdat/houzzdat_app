import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:houzzdat_app/core/theme/app_theme.dart';

/// Dialog for confirming and customizing the "Send to Owner" action.
class SendReportDialog extends StatefulWidget {
  final Map<String, dynamic> report;
  final List<Map<String, dynamic>> owners;
  final String ownerContent;

  const SendReportDialog({
    super.key,
    required this.report,
    required this.owners,
    required this.ownerContent,
  });

  /// Shows the dialog and returns result with email, subject, message, or null if cancelled.
  static Future<Map<String, dynamic>?> show(
    BuildContext context, {
    required Map<String, dynamic> report,
    required List<Map<String, dynamic>> owners,
    required String ownerContent,
  }) {
    return showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => SendReportDialog(
        report: report,
        owners: owners,
        ownerContent: ownerContent,
      ),
    );
  }

  @override
  State<SendReportDialog> createState() => _SendReportDialogState();
}

class _SendReportDialogState extends State<SendReportDialog> {
  late TextEditingController _emailController;
  late TextEditingController _subjectController;
  late TextEditingController _messageController;

  @override
  void initState() {
    super.initState();

    // Pre-populate owner email
    String ownerEmail = '';
    String ownerName = '';
    if (widget.owners.isNotEmpty) {
      final firstOwner = widget.owners.first;
      ownerEmail = firstOwner['users']?['email']?.toString() ?? '';
      ownerName = firstOwner['users']?['full_name']?.toString() ?? 'Owner';
    }

    // Build date range label
    final startDate = widget.report['start_date']?.toString() ?? '';
    final endDate = widget.report['end_date']?.toString() ?? '';
    String dateRange;
    try {
      final start = DateTime.parse(startDate);
      final end = DateTime.parse(endDate);
      final fmt = DateFormat('d MMM yyyy');
      dateRange = startDate == endDate
          ? fmt.format(start)
          : '${fmt.format(start)} to ${fmt.format(end)}';
    } catch (_) {
      dateRange = startDate;
    }

    _emailController = TextEditingController(text: ownerEmail);
    _subjectController = TextEditingController(
      text: 'Project Progress Report \u2014 $dateRange',
    );
    _messageController = TextEditingController(
      text: 'Dear $ownerName,\n\n'
          'Please find attached the progress report for $dateRange. '
          'The report summarizes work completed, progress highlights, and any items '
          'requiring your attention.\n\n'
          'Please let me know if you have any questions.\n\n'
          'Best regards',
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _subjectController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusXL),
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingL),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  const Icon(Icons.send, color: AppTheme.primaryIndigo, size: 24),
                  const SizedBox(width: AppTheme.spacingS),
                  const Expanded(
                    child: Text(
                      'Send Report to Owner',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),

              const SizedBox(height: AppTheme.spacingM),

              // Email field
              _buildLabel('Owner Email'),
              const SizedBox(height: 4),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: _inputDecoration('owner@example.com'),
              ),

              const SizedBox(height: AppTheme.spacingM),

              // Subject field
              _buildLabel('Email Subject'),
              const SizedBox(height: 4),
              TextField(
                controller: _subjectController,
                decoration: _inputDecoration('Subject line'),
              ),

              const SizedBox(height: AppTheme.spacingM),

              // Message field
              _buildLabel('Email Message'),
              const SizedBox(height: 4),
              TextField(
                controller: _messageController,
                maxLines: 6,
                decoration: _inputDecoration('Email body'),
              ),

              const SizedBox(height: AppTheme.spacingM),

              // Attachment indicator
              Container(
                padding: const EdgeInsets.all(AppTheme.spacingS),
                decoration: BoxDecoration(
                  color: AppTheme.backgroundGrey,
                  borderRadius: BorderRadius.circular(AppTheme.radiusM),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.picture_as_pdf, color: AppTheme.errorRed, size: 20),
                    SizedBox(width: AppTheme.spacingS),
                    Expanded(
                      child: Text(
                        'Owner Report will be attached as PDF',
                        style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppTheme.spacingS),

              // Warning
              Container(
                padding: const EdgeInsets.all(AppTheme.spacingS),
                decoration: BoxDecoration(
                  color: AppTheme.warningOrange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radiusM),
                  border: Border.all(
                    color: AppTheme.warningOrange.withValues(alpha: 0.3),
                  ),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.warning_amber, color: AppTheme.warningOrange, size: 18),
                    SizedBox(width: AppTheme.spacingS),
                    Expanded(
                      child: Text(
                        'Once sent, the owner report cannot be edited.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.warningOrange,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppTheme.spacingL),

              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.textSecondary,
                        side: const BorderSide(color: AppTheme.textSecondary),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: AppTheme.spacingM),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _handleSend,
                      icon: const Icon(Icons.send, size: 18),
                      label: const Text('Send Report'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.successGreen,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: AppTheme.textSecondary,
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: AppTheme.textSecondary, fontSize: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusM),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusM),
        borderSide: const BorderSide(color: AppTheme.primaryIndigo, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingM,
        vertical: AppTheme.spacingS,
      ),
      isDense: true,
    );
  }

  void _handleSend() {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid email address'),
          backgroundColor: AppTheme.errorRed,
        ),
      );
      return;
    }

    Navigator.pop(context, {
      'confirmed': true,
      'email': email,
      'subject': _subjectController.text.trim(),
      'message': _messageController.text.trim(),
    });
  }
}
