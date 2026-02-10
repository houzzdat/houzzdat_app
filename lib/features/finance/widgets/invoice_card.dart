import 'package:flutter/material.dart';
import 'package:houzzdat_app/core/theme/app_theme.dart';
import 'package:houzzdat_app/core/widgets/shared_widgets.dart';
import 'package:intl/intl.dart';

/// Expandable invoice card widget.
/// Collapsed: Invoice #, Vendor, Amount, Status, Due date.
/// Expanded: Description, payment history, approve/reject/pay actions.
class InvoiceCard extends StatelessWidget {
  final Map<String, dynamic> invoice;
  final List<Map<String, dynamic>> linkedPayments;
  final bool isExpanded;
  final VoidCallback onTap;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;
  final VoidCallback? onAddPayment;
  final VoidCallback? onSubmit;

  const InvoiceCard({
    super.key,
    required this.invoice,
    this.linkedPayments = const [],
    required this.isExpanded,
    required this.onTap,
    this.onApprove,
    this.onReject,
    this.onAddPayment,
    this.onSubmit,
  });

  static final _currencyFormat =
      NumberFormat.currency(locale: 'en_IN', symbol: '\u20B9', decimalDigits: 0);

  static final _dateFormat = DateFormat('dd MMM yyyy');

  Color _statusColor(String status) {
    switch (status) {
      case 'draft':
        return Colors.grey;
      case 'submitted':
        return AppTheme.infoBlue;
      case 'approved':
        return AppTheme.successGreen;
      case 'rejected':
        return AppTheme.errorRed;
      case 'paid':
        return AppTheme.successGreen;
      case 'overdue':
        return AppTheme.errorRed;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = invoice['status']?.toString() ?? 'draft';
    final amount = (invoice['amount'] as num?)?.toDouble() ?? 0;
    final vendor = invoice['vendor']?.toString() ?? '';
    final invoiceNumber = invoice['invoice_number']?.toString() ?? '';
    final dueDateStr = invoice['due_date']?.toString();
    final description = invoice['description']?.toString() ?? '';
    final projectName = invoice['projects']?['name']?.toString() ?? '';
    final submittedByName =
        invoice['users']?['full_name']?.toString() ?? '';
    final rejectionReason = invoice['rejection_reason']?.toString() ?? '';
    final notes = invoice['notes']?.toString() ?? '';

    DateTime? dueDate;
    if (dueDateStr != null && dueDateStr.isNotEmpty) {
      try {
        dueDate = DateTime.parse(dueDateStr);
      } catch (_) {}
    }

    final statusColor = _statusColor(status);
    final totalPaid = linkedPayments.fold<double>(
      0,
      (sum, p) => sum + ((p['amount'] as num?)?.toDouble() ?? 0),
    );
    final paymentProgress = amount > 0 ? (totalPaid / amount).clamp(0.0, 1.0) : 0.0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacingM,
          vertical: AppTheme.spacingXS,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppTheme.radiusL),
          border: Border.all(
            color: isExpanded ? statusColor.withValues(alpha: 0.4) : const Color(0xFFE0E0E0),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Collapsed content ──
            Padding(
              padding: const EdgeInsets.all(AppTheme.spacingM),
              child: Row(
                children: [
                  // Left color indicator
                  Container(
                    width: 4,
                    height: 48,
                    decoration: BoxDecoration(
                      color: statusColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: AppTheme.spacingS),
                  // Main info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              '#$invoiceNumber',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                backgroundColor: AppTheme.textPrimary,
                              ),
                            ),
                            if (projectName.isNotEmpty) ...[
                              const SizedBox(width: AppTheme.spacingS),
                              Flexible(
                                child: Text(
                                  projectName,
                                  style: AppTheme.caption,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          vendor,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppTheme.textSecondary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  // Amount + status
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        _currencyFormat.format(amount),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      CategoryBadge(
                        text: status.toUpperCase().replaceAll('_', ' '),
                        color: statusColor,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Due date row
            if (dueDate != null)
              Padding(
                padding: const EdgeInsets.only(
                  left: AppTheme.spacingM + 12,
                  right: AppTheme.spacingM,
                  bottom: AppTheme.spacingS,
                ),
                child: Row(
                  children: [
                    Icon(Icons.calendar_today, size: 12, color: AppTheme.textSecondary),
                    const SizedBox(width: 4),
                    Text(
                      'Due: ${_dateFormat.format(dueDate)}',
                      style: AppTheme.caption.copyWith(
                        color: status == 'overdue' ? AppTheme.errorRed : AppTheme.textSecondary,
                        fontWeight: status == 'overdue' ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),

            // Payment progress bar (if any payments exist)
            if (linkedPayments.isNotEmpty && status != 'draft')
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingM),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Paid: ${_currencyFormat.format(totalPaid)} / ${_currencyFormat.format(amount)}',
                          style: AppTheme.caption.copyWith(fontWeight: FontWeight.w500),
                        ),
                        Text(
                          '${(paymentProgress * 100).toStringAsFixed(0)}%',
                          style: AppTheme.caption.copyWith(
                            color: AppTheme.successGreen,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: paymentProgress,
                        backgroundColor: Colors.grey.shade200,
                        valueColor: const AlwaysStoppedAnimation(AppTheme.successGreen),
                        minHeight: 6,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacingS),
                  ],
                ),
              ),

            // ── Expanded content ──
            if (isExpanded) ...[
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(AppTheme.spacingM),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Description
                    if (description.isNotEmpty) ...[
                      const Text(
                        'Description',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(description, style: const TextStyle(fontSize: 14)),
                      const SizedBox(height: AppTheme.spacingM),
                    ],

                    // Submitted by
                    if (submittedByName.isNotEmpty) ...[
                      Row(
                        children: [
                          const Icon(Icons.person_outline, size: 14, color: AppTheme.textSecondary),
                          const SizedBox(width: 4),
                          Text(
                            'Submitted by: $submittedByName',
                            style: AppTheme.caption,
                          ),
                        ],
                      ),
                      const SizedBox(height: AppTheme.spacingS),
                    ],

                    // Rejection reason
                    if (status == 'rejected' && rejectionReason.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.all(AppTheme.spacingS),
                        decoration: BoxDecoration(
                          color: AppTheme.errorRed.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(AppTheme.radiusS),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline, size: 16, color: AppTheme.errorRed),
                            const SizedBox(width: AppTheme.spacingS),
                            Expanded(
                              child: Text(
                                'Rejected: $rejectionReason',
                                style: const TextStyle(fontSize: 13, color: AppTheme.errorRed),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppTheme.spacingM),
                    ],

                    // Notes
                    if (notes.isNotEmpty) ...[
                      Row(
                        children: [
                          const Icon(Icons.note_outlined, size: 14, color: AppTheme.textSecondary),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text('Notes: $notes', style: AppTheme.caption),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppTheme.spacingM),
                    ],

                    // Payment history
                    if (linkedPayments.isNotEmpty) ...[
                      const Text(
                        'Payment History',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(height: AppTheme.spacingS),
                      ...linkedPayments.map((p) => _PaymentHistoryItem(payment: p)),
                      const SizedBox(height: AppTheme.spacingS),
                    ],

                    // Action buttons
                    Row(
                      children: [
                        if (status == 'draft' && onSubmit != null)
                          Expanded(
                            child: ActionButton(
                              label: 'Submit',
                              icon: Icons.send_rounded,
                              backgroundColor: AppTheme.infoBlue,
                              onPressed: onSubmit!,
                            ),
                          ),
                        if (status == 'submitted') ...[
                          if (onApprove != null)
                            Expanded(
                              child: ActionButton(
                                label: 'Approve',
                                icon: Icons.check_circle_outline,
                                backgroundColor: AppTheme.successGreen,
                                onPressed: onApprove!,
                              ),
                            ),
                          const SizedBox(width: AppTheme.spacingS),
                          if (onReject != null)
                            Expanded(
                              child: ActionButton(
                                label: 'Reject',
                                icon: Icons.cancel_outlined,
                                backgroundColor: AppTheme.errorRed,
                                onPressed: onReject!,
                              ),
                            ),
                        ],
                        if ((status == 'approved' || status == 'paid') && onAddPayment != null) ...[
                          if (status == 'submitted') const SizedBox(width: AppTheme.spacingS),
                          Expanded(
                            child: ActionButton(
                              label: 'Add Payment',
                              icon: Icons.payment_rounded,
                              backgroundColor: AppTheme.primaryIndigo,
                              onPressed: onAddPayment!,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PaymentHistoryItem extends StatelessWidget {
  final Map<String, dynamic> payment;
  const _PaymentHistoryItem({required this.payment});

  static final _currencyFormat =
      NumberFormat.currency(locale: 'en_IN', symbol: '\u20B9', decimalDigits: 0);
  static final _dateFormat = DateFormat('dd MMM');

  @override
  Widget build(BuildContext context) {
    final amount = (payment['amount'] as num?)?.toDouble() ?? 0;
    final method = payment['payment_method']?.toString() ?? '';
    final dateStr = payment['payment_date']?.toString();
    final ref = payment['reference_number']?.toString() ?? '';

    String dateLabel = '';
    if (dateStr != null) {
      try {
        dateLabel = _dateFormat.format(DateTime.parse(dateStr));
      } catch (_) {}
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          const Icon(Icons.check, size: 14, color: AppTheme.successGreen),
          const SizedBox(width: AppTheme.spacingS),
          Text(
            _currencyFormat.format(amount),
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
          if (method.isNotEmpty) ...[
            const SizedBox(width: AppTheme.spacingS),
            CategoryBadge(
              text: method.replaceAll('_', ' ').toUpperCase(),
              color: AppTheme.primaryIndigo,
            ),
          ],
          if (ref.isNotEmpty) ...[
            const SizedBox(width: AppTheme.spacingS),
            Expanded(
              child: Text(
                'Ref: $ref',
                style: AppTheme.caption,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ] else
            const Spacer(),
          if (dateLabel.isNotEmpty)
            Text(dateLabel, style: AppTheme.caption),
        ],
      ),
    );
  }
}
