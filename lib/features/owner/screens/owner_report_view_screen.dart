import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:houzzdat_app/core/theme/app_theme.dart';
import 'package:houzzdat_app/features/reports/services/pdf_generator_service.dart';

/// Read-only screen for owners to view a sent report.
class OwnerReportViewScreen extends StatelessWidget {
  final Map<String, dynamic> report;

  const OwnerReportViewScreen({
    super.key,
    required this.report,
  });

  String get _title {
    final startDate = report['start_date']?.toString() ?? '';
    final endDate = report['end_date']?.toString() ?? '';
    try {
      final start = DateTime.parse(startDate);
      final end = DateTime.parse(endDate);
      final fmt = DateFormat('d MMM yyyy');
      if (startDate == endDate) return 'Report \u2014 ${fmt.format(start)}';
      return 'Report \u2014 ${fmt.format(start)} to ${fmt.format(end)}';
    } catch (_) {
      return 'Report';
    }
  }

  String get _dateRange {
    final startDate = report['start_date']?.toString() ?? '';
    final endDate = report['end_date']?.toString() ?? '';
    if (startDate == endDate) return startDate;
    return '$startDate to $endDate';
  }

  @override
  Widget build(BuildContext context) {
    final content = report['owner_report_content']?.toString() ?? '';
    final createdBy = report['users']?['full_name']?.toString() ?? 'Manager';
    final sentAt = report['sent_at']?.toString();
    final projectNames = report['_project_names']?.toString() ?? 'All Sites';

    String sentLabel = '';
    if (sentAt != null) {
      try {
        sentLabel = DateFormat('d MMM yyyy, h:mm a').format(DateTime.parse(sentAt));
      } catch (_) {
        sentLabel = sentAt;
      }
    }

    return Scaffold(
      backgroundColor: AppTheme.backgroundGrey,
      appBar: AppBar(
        title: Text(_title, style: const TextStyle(fontSize: 14)),
        backgroundColor: AppTheme.primaryIndigo,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_outlined),
            onPressed: () => _handleDownloadPdf(context, content),
            tooltip: 'Download PDF',
          ),
        ],
      ),
      body: Column(
        children: [
          // Report metadata header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppTheme.spacingM),
            color: Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.person_outline,
                        size: 16, color: AppTheme.textSecondary),
                    const SizedBox(width: 6),
                    Text(
                      'From $createdBy',
                      style: AppTheme.bodySmall.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.business,
                        size: 16, color: AppTheme.textSecondary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        projectNames,
                        style: AppTheme.caption,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                if (sentLabel.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.schedule,
                          size: 16, color: AppTheme.textSecondary),
                      const SizedBox(width: 6),
                      Text(
                        'Sent $sentLabel',
                        style: AppTheme.caption.copyWith(
                          color: AppTheme.successGreen,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1, color: Color(0xFFE0E0E0)),

          // Report content (read-only markdown)
          Expanded(
            child: content.isEmpty
                ? const Center(
                    child: Text(
                      'No report content',
                      style:
                          TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                    ),
                  )
                : Markdown(
                    data: content,
                    padding: const EdgeInsets.all(AppTheme.spacingM),
                    styleSheet: MarkdownStyleSheet(
                      h1: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.primaryIndigo,
                      ),
                      h2: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primaryIndigo,
                      ),
                      h3: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                      p: const TextStyle(
                        fontSize: 14,
                        height: 1.5,
                        color: AppTheme.textPrimary,
                      ),
                      listBullet: const TextStyle(
                        fontSize: 14,
                        color: AppTheme.textPrimary,
                      ),
                      strong: const TextStyle(fontWeight: FontWeight.w700),
                      blockquoteDecoration: BoxDecoration(
                        border: Border(
                          left: BorderSide(
                            color:
                                AppTheme.primaryIndigo.withValues(alpha: 0.4),
                            width: 3,
                          ),
                        ),
                      ),
                      horizontalRuleDecoration: BoxDecoration(
                        border: Border(
                          top: BorderSide(color: Colors.grey.shade300, width: 1),
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleDownloadPdf(BuildContext context, String content) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Generating PDF...'),
          backgroundColor: AppTheme.infoBlue,
          duration: Duration(seconds: 2),
        ),
      );

      final pdfBytes = await PdfGeneratorService.generateOwnerReportPdf(
        reportContent: content,
        companyName: 'Project Report',
        dateRange: _dateRange,
        projectNames: [],
      );

      await Printing.layoutPdf(
        onLayout: (_) async => pdfBytes,
        name: 'Project_Report_${_dateRange.replaceAll(' ', '_')}.pdf',
      );
    } catch (e) {
      debugPrint('Error generating PDF: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not generate PDF. Please try again.'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    }
  }
}
