import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:houzzdat_app/core/theme/app_theme.dart';
import 'package:houzzdat_app/core/widgets/shared_widgets.dart';
import 'package:houzzdat_app/features/reports/widgets/report_editor_widget.dart';
import 'package:houzzdat_app/features/reports/widgets/send_report_dialog.dart';
import 'package:houzzdat_app/features/reports/services/pdf_generator_service.dart';

/// Screen for viewing/editing a single report with Manager and Owner tabs.
class ReportDetailScreen extends StatefulWidget {
  final String reportId;
  final String accountId;
  final String? initialManagerContent;
  final String? initialOwnerContent;

  const ReportDetailScreen({
    super.key,
    required this.reportId,
    required this.accountId,
    this.initialManagerContent,
    this.initialOwnerContent,
  });

  @override
  State<ReportDetailScreen> createState() => _ReportDetailScreenState();
}

class _ReportDetailScreenState extends State<ReportDetailScreen>
    with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  late TabController _tabController;

  Map<String, dynamic>? _report;
  bool _isLoading = true;
  String _managerContent = '';
  String _ownerContent = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _managerContent = widget.initialManagerContent ?? '';
    _ownerContent = widget.initialOwnerContent ?? '';
    _loadReport();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadReport() async {
    try {
      final data = await _supabase
          .from('reports')
          .select('*, users!reports_created_by_fkey(full_name)')
          .eq('id', widget.reportId)
          .single();

      if (mounted) {
        setState(() {
          _report = Map<String, dynamic>.from(data);
          _managerContent =
              _report!['manager_report_content']?.toString() ?? _managerContent;
          _ownerContent =
              _report!['owner_report_content']?.toString() ?? _ownerContent;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading report: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String get _title {
    if (_report == null) return 'Report';
    final startDate = _report!['start_date']?.toString() ?? '';
    final endDate = _report!['end_date']?.toString() ?? '';
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

  String get _mgrStatus => _report?['manager_report_status']?.toString() ?? 'draft';
  String get _ownerStatus => _report?['owner_report_status']?.toString() ?? 'draft';

  bool get _isManagerEditable => _mgrStatus == 'draft';
  bool get _isOwnerEditable => _ownerStatus != 'sent';

  Future<void> _handleSaveAsFinal() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Save as Final'),
        content: const Text(
          'This will finalize both reports. The manager report will be locked from further editing. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryIndigo),
            child: const Text('Finalize', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _supabase.from('reports').update({
        'manager_report_status': 'final',
        'owner_report_status':
            _ownerStatus == 'sent' ? 'sent' : 'final',
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', widget.reportId);
      await _loadReport();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Reports finalized'),
            backgroundColor: AppTheme.successGreen,
          ),
        );
      }
    }
  }

  Future<void> _handleRevertToDraft() async {
    await _supabase.from('reports').update({
      'manager_report_status': 'draft',
      'owner_report_status':
          _ownerStatus == 'sent' ? 'sent' : 'draft',
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', widget.reportId);
    await _loadReport();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Reverted to draft'),
          backgroundColor: AppTheme.infoBlue,
        ),
      );
    }
  }

  Future<void> _handleSendToOwner() async {
    if (_report == null) return;

    // Fetch owner emails for the projects
    final projectIds = (_report!['project_ids'] as List?)
            ?.map((e) => e.toString())
            .toList() ??
        [];

    List<Map<String, dynamic>> owners = [];
    try {
      if (projectIds.isNotEmpty) {
        final ownerData = await _supabase
            .from('project_owners')
            .select('owner_id, users!project_owners_owner_id_fkey(full_name, email)')
            .inFilter('project_id', projectIds);
        owners = List<Map<String, dynamic>>.from(ownerData);
      }
      // If no specific projects, fetch all owners for the account
      if (owners.isEmpty) {
        final ownerData = await _supabase
            .from('project_owners')
            .select(
                'owner_id, users!project_owners_owner_id_fkey(full_name, email), projects!inner(account_id)')
            .eq('projects.account_id', widget.accountId);
        owners = List<Map<String, dynamic>>.from(ownerData);
      }
    } catch (e) {
      debugPrint('Error fetching owners: $e');
    }

    // Deduplicate by owner_id
    final seenIds = <String>{};
    final uniqueOwners = <Map<String, dynamic>>[];
    for (final o in owners) {
      final id = o['owner_id']?.toString() ?? '';
      if (id.isNotEmpty && seenIds.add(id)) {
        uniqueOwners.add(o);
      }
    }

    if (!mounted) return;

    final result = await SendReportDialog.show(
      context,
      report: _report!,
      owners: uniqueOwners,
      ownerContent: _ownerContent,
    );

    if (result != null && result['confirmed'] == true) {
      // Generate PDF
      try {
        final startDate = _report!['start_date']?.toString() ?? '';
        final endDate = _report!['end_date']?.toString() ?? '';
        final dateRange = startDate == endDate ? startDate : '$startDate to $endDate';

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Generating PDF and sending...'),
            backgroundColor: AppTheme.infoBlue,
            duration: Duration(seconds: 5),
          ),
        );

        final pdfBytes = await PdfGeneratorService.generateOwnerReportPdf(
          reportContent: _ownerContent,
          companyName: 'Project Report',
          dateRange: dateRange,
          projectNames: [],
        );

        // Send via edge function
        final response = await _supabase.functions.invoke(
          'send-report-email',
          body: {
            'report_id': widget.reportId,
            'account_id': widget.accountId,
            'to_email': result['email'],
            'subject': result['subject'],
            'message': result['message'],
            'pdf_base64': _bytesToBase64(pdfBytes),
          },
        );

        final data = response.data;
        if (data['success'] == true) {
          await _loadReport();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Report sent to owner'),
                backgroundColor: AppTheme.successGreen,
              ),
            );
          }
        } else {
          throw Exception(data['error'] ?? 'Send failed');
        }
      } catch (e) {
        debugPrint('Error sending report: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not send report. Please check your connection and try again.'),
              backgroundColor: AppTheme.errorRed,
            ),
          );
        }
      }
    }
  }

  String _bytesToBase64(List<int> bytes) {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
    final buffer = StringBuffer();
    for (var i = 0; i < bytes.length; i += 3) {
      final b0 = bytes[i];
      final b1 = i + 1 < bytes.length ? bytes[i + 1] : 0;
      final b2 = i + 2 < bytes.length ? bytes[i + 2] : 0;
      buffer.write(chars[(b0 >> 2) & 0x3F]);
      buffer.write(chars[((b0 << 4) | (b1 >> 4)) & 0x3F]);
      buffer.write(i + 1 < bytes.length ? chars[((b1 << 2) | (b2 >> 6)) & 0x3F] : '=');
      buffer.write(i + 2 < bytes.length ? chars[b2 & 0x3F] : '=');
    }
    return buffer.toString();
  }

  Future<void> _handleRegenerate() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Regenerate Reports'),
        content: const Text(
          'This will replace the current report content with a new AI-generated version. This cannot be undone. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.warningOrange),
            child: const Text('Regenerate', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true || _report == null) return;

    setState(() => _isLoading = true);

    try {
      final response = await _supabase.functions.invoke(
        'generate-report',
        body: {
          'account_id': widget.accountId,
          'start_date': _report!['start_date'],
          'end_date': _report!['end_date'],
          'project_ids': _report!['project_ids'] ?? [],
        },
      );

      final data = response.data;
      if (data['success'] == true) {
        // Delete old report and use new one
        final newReportId = data['report_id']?.toString();
        if (newReportId != null) {
          // Delete the old report
          await _supabase.from('reports').delete().eq('id', widget.reportId);

          if (mounted) {
            // Navigate to the new report
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (context) => ReportDetailScreen(
                  reportId: newReportId,
                  accountId: widget.accountId,
                  initialManagerContent: data['manager_report'],
                  initialOwnerContent: data['owner_report'],
                ),
              ),
            );
          }
        }
      } else {
        throw Exception(data['error'] ?? 'Generation failed');
      }
    } catch (e) {
      debugPrint('Error regenerating: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not regenerate report. Please try again later.'), backgroundColor: AppTheme.errorRed),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _managerContent.isEmpty) {
      return Scaffold(
        backgroundColor: AppTheme.backgroundGrey,
        appBar: AppBar(
          title: const Text('Report'),
          backgroundColor: AppTheme.primaryIndigo,
          foregroundColor: Colors.white,
        ),
        body: const LoadingWidget(message: 'Loading report...'),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.backgroundGrey,
      appBar: AppBar(
        title: Text(_title, style: const TextStyle(fontSize: 14)),
        backgroundColor: AppTheme.primaryIndigo,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (_mgrStatus == 'draft')
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _handleRegenerate,
              tooltip: 'Regenerate',
            ),
        ],
      ),
      body: Column(
        children: [
          // Sub-tab bar
          Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              labelColor: AppTheme.primaryIndigo,
              unselectedLabelColor: AppTheme.textSecondary,
              indicatorColor: AppTheme.primaryIndigo,
              indicatorWeight: 3,
              labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              unselectedLabelStyle:
                  const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
              tabs: const [
                Tab(text: 'MANAGER REPORT'),
                Tab(text: 'OWNER REPORT'),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1, color: Color(0xFFE0E0E0)),

          // Tab content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                ReportEditorWidget(
                  reportId: widget.reportId,
                  initialContent: _managerContent,
                  reportType: 'manager',
                  isEditable: _isManagerEditable,
                  onContentChanged: (text) {
                    _managerContent = text;
                  },
                ),
                ReportEditorWidget(
                  reportId: widget.reportId,
                  initialContent: _ownerContent,
                  reportType: 'owner',
                  isEditable: _isOwnerEditable,
                  onContentChanged: (text) {
                    _ownerContent = text;
                  },
                ),
              ],
            ),
          ),

          // Bottom action bar
          _buildBottomBar(),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingM,
        vertical: AppTheme.spacingS,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Colors.grey.shade200),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: _buildActionButtons(),
      ),
    );
  }

  Widget _buildActionButtons() {
    // If owner report is already sent
    if (_ownerStatus == 'sent') {
      return Row(
        children: [
          const Icon(Icons.check_circle, color: AppTheme.successGreen, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Owner report sent${_report?['sent_at'] != null ? ' on ${_formatDate(_report!['sent_at'])}' : ''}',
              style: const TextStyle(
                color: AppTheme.successGreen,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
          // Resend button
          TextButton.icon(
            onPressed: _handleSendToOwner,
            icon: const Icon(Icons.send, size: 16),
            label: const Text('Resend'),
            style: TextButton.styleFrom(foregroundColor: AppTheme.primaryIndigo),
          ),
        ],
      );
    }

    // If reports are finalized
    if (_mgrStatus == 'final') {
      return Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _handleRevertToDraft,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.textSecondary,
                side: const BorderSide(color: AppTheme.textSecondary),
              ),
              child: const Text('Revert to Draft'),
            ),
          ),
          const SizedBox(width: AppTheme.spacingS),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _handleSendToOwner,
              icon: const Icon(Icons.send, size: 18),
              label: const Text('Send to Owner'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.successGreen,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      );
    }

    // Draft state
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Draft saved'),
                  backgroundColor: AppTheme.successGreen,
                  duration: Duration(seconds: 1),
                ),
              );
            },
            icon: const Icon(Icons.save_outlined, size: 18),
            label: const Text('Save Draft'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.primaryIndigo,
              side: const BorderSide(color: AppTheme.primaryIndigo),
            ),
          ),
        ),
        const SizedBox(width: AppTheme.spacingS),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _handleSaveAsFinal,
            icon: const Icon(Icons.check_circle_outline, size: 18),
            label: const Text('Finalize'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryIndigo,
              foregroundColor: Colors.white,
            ),
          ),
        ),
      ],
    );
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '';
    try {
      return DateFormat('d MMM, h:mm a').format(DateTime.parse(dateStr));
    } catch (_) {
      return dateStr;
    }
  }
}
