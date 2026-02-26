import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';

/// UX-audit PP-02: PDF export service for owner financial reports.
/// Generates a professional construction-grade financial statement
/// with summary, payment ledger, fund request ledger, and project breakdown.
class FinanceExportService {
  static final _currencyFormat =
      NumberFormat.currency(locale: 'en_IN', symbol: '\u20B9', decimalDigits: 0);
  static final _dateFormat = DateFormat('dd MMM yyyy');
  static final _dateTimeFormat = DateFormat('dd MMM yyyy, hh:mm a');

  /// Generate and display a financial report PDF.
  /// Automatically opens the platform share/print dialog.
  static Future<void> generateAndShare({
    required BuildContext context,
    required List<Map<String, dynamic>> payments,
    required List<Map<String, dynamic>> fundRequests,
    required String accountName,
    DateTimeRange? dateRange,
  }) async {
    try {
      final doc = _buildDocument(
        payments: payments,
        fundRequests: fundRequests,
        accountName: accountName,
        dateRange: dateRange,
      );

      await Printing.layoutPdf(
        onLayout: (format) async => doc.save(),
        name: 'SiteVoice_Finance_Report_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf',
      );
    } catch (e) {
      debugPrint('Error generating PDF: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to generate report. Please try again.'),
            backgroundColor: Color(0xFFD32F2F),
          ),
        );
      }
    }
  }

  /// Build the PDF document with all sections.
  static pw.Document _buildDocument({
    required List<Map<String, dynamic>> payments,
    required List<Map<String, dynamic>> fundRequests,
    required String accountName,
    DateTimeRange? dateRange,
  }) {
    final doc = pw.Document(
      theme: pw.ThemeData.withFont(
        base: pw.Font.helvetica(),
        bold: pw.Font.helveticaBold(),
      ),
    );

    // Filter by date range if specified
    final filteredPayments = dateRange != null
        ? payments.where((p) {
            final dateStr = p['received_date']?.toString();
            if (dateStr == null) return false;
            try {
              final dt = DateTime.parse(dateStr);
              return !dt.isBefore(dateRange.start) &&
                  !dt.isAfter(dateRange.end.add(const Duration(days: 1)));
            } catch (_) {
              return true;
            }
          }).toList()
        : payments;

    final filteredRequests = dateRange != null
        ? fundRequests.where((r) {
            final dateStr = r['created_at']?.toString();
            if (dateStr == null) return false;
            try {
              final dt = DateTime.parse(dateStr);
              return !dt.isBefore(dateRange.start) &&
                  !dt.isAfter(dateRange.end.add(const Duration(days: 1)));
            } catch (_) {
              return true;
            }
          }).toList()
        : fundRequests;

    // Compute totals
    final totalReceived = filteredPayments.fold<double>(
        0, (sum, p) => sum + ((p['amount'] as num?)?.toDouble() ?? 0));
    final totalRequested = filteredRequests.fold<double>(
        0, (sum, r) => sum + ((r['amount'] as num?)?.toDouble() ?? 0));
    final totalApproved = filteredRequests
        .where((r) => r['status'] == 'approved')
        .fold<double>(
            0, (sum, r) => sum + ((r['amount'] as num?)?.toDouble() ?? 0));
    final totalPending = filteredRequests
        .where((r) => r['status'] == 'pending')
        .fold<double>(
            0, (sum, r) => sum + ((r['amount'] as num?)?.toDouble() ?? 0));
    final netPosition = totalReceived - totalApproved;

    // Fund request status counts
    final pendingCount =
        filteredRequests.where((r) => r['status'] == 'pending').length;
    final approvedCount =
        filteredRequests.where((r) => r['status'] == 'approved').length;
    final deniedCount =
        filteredRequests.where((r) => r['status'] == 'denied').length;

    // Date range label
    final periodLabel = dateRange != null
        ? '${_dateFormat.format(dateRange.start)} – ${_dateFormat.format(dateRange.end)}'
        : 'All Time';

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        header: (context) => _buildHeader(accountName, periodLabel, context),
        footer: (context) => _buildFooter(context),
        build: (context) => [
          // Executive Summary
          _buildSectionTitle('EXECUTIVE SUMMARY'),
          pw.SizedBox(height: 8),
          _buildSummaryTable(
            totalReceived: totalReceived,
            totalRequested: totalRequested,
            totalApproved: totalApproved,
            totalPending: totalPending,
            netPosition: netPosition,
            pendingCount: pendingCount,
            approvedCount: approvedCount,
            deniedCount: deniedCount,
          ),
          pw.SizedBox(height: 20),

          // Payments Ledger
          _buildSectionTitle(
              'PAYMENTS RECEIVED (${filteredPayments.length})'),
          pw.SizedBox(height: 8),
          if (filteredPayments.isEmpty)
            _buildEmptyMessage('No payments recorded in this period.')
          else
            _buildPaymentsTable(filteredPayments),
          pw.SizedBox(height: 20),

          // Fund Requests Ledger
          _buildSectionTitle(
              'FUND REQUESTS (${filteredRequests.length})'),
          pw.SizedBox(height: 8),
          if (filteredRequests.isEmpty)
            _buildEmptyMessage('No fund requests in this period.')
          else
            _buildFundRequestsTable(filteredRequests),
          pw.SizedBox(height: 20),

          // Project Breakdown
          _buildSectionTitle('BREAKDOWN BY PROJECT'),
          pw.SizedBox(height: 8),
          _buildProjectBreakdown(filteredPayments, filteredRequests),
        ],
      ),
    );

    return doc;
  }

  // ─── Header / Footer ──────────────────────────────────────

  static pw.Widget _buildHeader(
      String accountName, String periodLabel, pw.Context context) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'FINANCIAL STATEMENT',
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColor.fromHex('#1A237E'),
                  ),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  accountName,
                  style: pw.TextStyle(
                    fontSize: 12,
                    color: PdfColor.fromHex('#616161'),
                  ),
                ),
              ],
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(
                  'SiteVoice',
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColor.fromHex('#1A237E'),
                  ),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  'Period: $periodLabel',
                  style: const pw.TextStyle(fontSize: 9),
                ),
                pw.Text(
                  'Generated: ${_dateTimeFormat.format(DateTime.now())}',
                  style: pw.TextStyle(
                    fontSize: 8,
                    color: PdfColor.fromHex('#9E9E9E'),
                  ),
                ),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 8),
        pw.Divider(thickness: 2, color: PdfColor.fromHex('#1A237E')),
        pw.SizedBox(height: 12),
      ],
    );
  }

  static pw.Widget _buildFooter(pw.Context context) {
    return pw.Column(
      children: [
        pw.Divider(color: PdfColor.fromHex('#E0E0E0')),
        pw.SizedBox(height: 4),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'Generated by SiteVoice Construction ERP',
              style: pw.TextStyle(
                fontSize: 7,
                color: PdfColor.fromHex('#9E9E9E'),
              ),
            ),
            pw.Text(
              'Page ${context.pageNumber} of ${context.pagesCount}',
              style: pw.TextStyle(
                fontSize: 7,
                color: PdfColor.fromHex('#9E9E9E'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ─── Section Title ─────────────────────────────────────────

  static pw.Widget _buildSectionTitle(String title) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromHex('#F5F5F5'),
        border: pw.Border(
          left: pw.BorderSide(
            color: PdfColor.fromHex('#1A237E'),
            width: 3,
          ),
        ),
      ),
      child: pw.Text(
        title,
        style: pw.TextStyle(
          fontSize: 11,
          fontWeight: pw.FontWeight.bold,
          color: PdfColor.fromHex('#1A237E'),
        ),
      ),
    );
  }

  // ─── Executive Summary ─────────────────────────────────────

  static pw.Widget _buildSummaryTable({
    required double totalReceived,
    required double totalRequested,
    required double totalApproved,
    required double totalPending,
    required double netPosition,
    required int pendingCount,
    required int approvedCount,
    required int deniedCount,
  }) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColor.fromHex('#E0E0E0')),
      columnWidths: {
        0: const pw.FlexColumnWidth(2),
        1: const pw.FlexColumnWidth(2),
        2: const pw.FlexColumnWidth(2),
        3: const pw.FlexColumnWidth(2),
      },
      children: [
        // Row 1: Financial totals
        pw.TableRow(
          decoration: pw.BoxDecoration(color: PdfColor.fromHex('#FAFAFA')),
          children: [
            _summaryCell('Total Received', _currencyFormat.format(totalReceived),
                PdfColor.fromHex('#2E7D32')),
            _summaryCell('Total Requested', _currencyFormat.format(totalRequested),
                PdfColor.fromHex('#1565C0')),
            _summaryCell('Total Approved', _currencyFormat.format(totalApproved),
                PdfColor.fromHex('#2E7D32')),
            _summaryCell(
              'Net Cash Position',
              _currencyFormat.format(netPosition),
              netPosition >= 0
                  ? PdfColor.fromHex('#2E7D32')
                  : PdfColor.fromHex('#D32F2F'),
            ),
          ],
        ),
        // Row 2: Counts
        pw.TableRow(
          children: [
            _summaryCell('Pending Requests', '$pendingCount',
                PdfColor.fromHex('#E65100')),
            _summaryCell('Approved', '$approvedCount',
                PdfColor.fromHex('#2E7D32')),
            _summaryCell(
                'Denied', '$deniedCount', PdfColor.fromHex('#D32F2F')),
            _summaryCell('Pending Amount', _currencyFormat.format(totalPending),
                PdfColor.fromHex('#E65100')),
          ],
        ),
      ],
    );
  }

  static pw.Widget _summaryCell(String label, String value, PdfColor color) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(label,
              style: pw.TextStyle(
                  fontSize: 8, color: PdfColor.fromHex('#757575'))),
          pw.SizedBox(height: 2),
          pw.Text(value,
              style: pw.TextStyle(
                  fontSize: 12, fontWeight: pw.FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  // ─── Payments Table ────────────────────────────────────────

  static pw.Widget _buildPaymentsTable(List<Map<String, dynamic>> payments) {
    return pw.TableHelper.fromTextArray(
      headerStyle: pw.TextStyle(
        fontSize: 8,
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.white,
      ),
      headerDecoration: pw.BoxDecoration(
        color: PdfColor.fromHex('#1A237E'),
      ),
      cellStyle: const pw.TextStyle(fontSize: 8),
      cellAlignment: pw.Alignment.centerLeft,
      headerAlignments: {
        0: pw.Alignment.centerLeft,
        1: pw.Alignment.centerLeft,
        2: pw.Alignment.centerRight,
        3: pw.Alignment.center,
        4: pw.Alignment.center,
        5: pw.Alignment.center,
      },
      cellAlignments: {
        2: pw.Alignment.centerRight,
        3: pw.Alignment.center,
        4: pw.Alignment.center,
        5: pw.Alignment.center,
      },
      headers: ['Date', 'Owner', 'Amount', 'Method', 'Project', 'Status'],
      data: payments.map((p) {
        String dateLabel = '';
        try {
          final d = p['received_date']?.toString();
          if (d != null) dateLabel = _dateFormat.format(DateTime.parse(d));
        } catch (_) {}

        return [
          dateLabel,
          p['users']?['full_name']?.toString() ?? '-',
          _currencyFormat.format((p['amount'] as num?)?.toDouble() ?? 0),
          (p['payment_method'] ?? '').toString().replaceAll('_', ' '),
          p['projects']?['name']?.toString() ?? '-',
          p['confirmed_by'] != null ? 'Confirmed' : 'Unconfirmed',
        ];
      }).toList(),
      oddRowDecoration: pw.BoxDecoration(color: PdfColor.fromHex('#FAFAFA')),
    );
  }

  // ─── Fund Requests Table ───────────────────────────────────

  static pw.Widget _buildFundRequestsTable(
      List<Map<String, dynamic>> requests) {
    return pw.TableHelper.fromTextArray(
      headerStyle: pw.TextStyle(
        fontSize: 8,
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.white,
      ),
      headerDecoration: pw.BoxDecoration(
        color: PdfColor.fromHex('#1565C0'),
      ),
      cellStyle: const pw.TextStyle(fontSize: 8),
      cellAlignment: pw.Alignment.centerLeft,
      headerAlignments: {
        0: pw.Alignment.centerLeft,
        1: pw.Alignment.centerLeft,
        2: pw.Alignment.centerRight,
        3: pw.Alignment.center,
        4: pw.Alignment.center,
        5: pw.Alignment.center,
      },
      cellAlignments: {
        2: pw.Alignment.centerRight,
        3: pw.Alignment.center,
        4: pw.Alignment.center,
        5: pw.Alignment.center,
      },
      headers: ['Date', 'Title', 'Amount', 'Urgency', 'Project', 'Status'],
      data: requests.map((r) {
        String dateLabel = '';
        try {
          final d = r['created_at']?.toString();
          if (d != null) dateLabel = _dateFormat.format(DateTime.parse(d));
        } catch (_) {}

        return [
          dateLabel,
          r['title']?.toString() ?? '-',
          _currencyFormat.format((r['amount'] as num?)?.toDouble() ?? 0),
          (r['urgency'] ?? 'normal').toString(),
          r['projects']?['name']?.toString() ?? '-',
          (r['status'] ?? 'pending').toString(),
        ];
      }).toList(),
      oddRowDecoration: pw.BoxDecoration(color: PdfColor.fromHex('#FAFAFA')),
    );
  }

  // ─── Project Breakdown ─────────────────────────────────────

  static pw.Widget _buildProjectBreakdown(
    List<Map<String, dynamic>> payments,
    List<Map<String, dynamic>> requests,
  ) {
    // Group by project
    final projectMap = <String, Map<String, double>>{};

    for (final p in payments) {
      final projectName = p['projects']?['name']?.toString() ?? 'Unallocated';
      projectMap.putIfAbsent(projectName, () => {'received': 0, 'requested': 0, 'approved': 0});
      projectMap[projectName]!['received'] =
          (projectMap[projectName]!['received'] ?? 0) +
              ((p['amount'] as num?)?.toDouble() ?? 0);
    }

    for (final r in requests) {
      final projectName = r['projects']?['name']?.toString() ?? 'Unallocated';
      projectMap.putIfAbsent(projectName, () => {'received': 0, 'requested': 0, 'approved': 0});
      projectMap[projectName]!['requested'] =
          (projectMap[projectName]!['requested'] ?? 0) +
              ((r['amount'] as num?)?.toDouble() ?? 0);
      if (r['status'] == 'approved') {
        projectMap[projectName]!['approved'] =
            (projectMap[projectName]!['approved'] ?? 0) +
                ((r['amount'] as num?)?.toDouble() ?? 0);
      }
    }

    if (projectMap.isEmpty) {
      return _buildEmptyMessage('No project-level data available.');
    }

    final sortedProjects = projectMap.entries.toList()
      ..sort((a, b) =>
          (b.value['received'] ?? 0).compareTo(a.value['received'] ?? 0));

    return pw.TableHelper.fromTextArray(
      headerStyle: pw.TextStyle(
        fontSize: 8,
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.white,
      ),
      headerDecoration: pw.BoxDecoration(
        color: PdfColor.fromHex('#37474F'),
      ),
      cellStyle: const pw.TextStyle(fontSize: 8),
      cellAlignment: pw.Alignment.centerLeft,
      headerAlignments: {
        1: pw.Alignment.centerRight,
        2: pw.Alignment.centerRight,
        3: pw.Alignment.centerRight,
        4: pw.Alignment.centerRight,
      },
      cellAlignments: {
        1: pw.Alignment.centerRight,
        2: pw.Alignment.centerRight,
        3: pw.Alignment.centerRight,
        4: pw.Alignment.centerRight,
      },
      headers: ['Project', 'Received', 'Requested', 'Approved', 'Net'],
      data: sortedProjects.map((entry) {
        final received = entry.value['received'] ?? 0;
        final approved = entry.value['approved'] ?? 0;
        final net = received - approved;
        return [
          entry.key,
          _currencyFormat.format(received),
          _currencyFormat.format(entry.value['requested'] ?? 0),
          _currencyFormat.format(approved),
          _currencyFormat.format(net),
        ];
      }).toList(),
      oddRowDecoration: pw.BoxDecoration(color: PdfColor.fromHex('#FAFAFA')),
    );
  }

  // ─── Helpers ───────────────────────────────────────────────

  static pw.Widget _buildEmptyMessage(String message) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromHex('#FAFAFA'),
        border: pw.TableBorder.all(color: PdfColor.fromHex('#E0E0E0')),
      ),
      child: pw.Text(
        message,
        textAlign: pw.TextAlign.center,
        style: pw.TextStyle(
          fontSize: 10,
          color: PdfColor.fromHex('#9E9E9E'),
          fontStyle: pw.FontStyle.italic,
        ),
      ),
    );
  }
}
