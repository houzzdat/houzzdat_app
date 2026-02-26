import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:houzzdat_app/core/theme/app_theme.dart';
import 'package:houzzdat_app/core/widgets/shared_widgets.dart';
import 'package:houzzdat_app/features/documents/services/document_service.dart';
import 'package:houzzdat_app/features/documents/widgets/document_approval_dialog.dart';
import 'package:houzzdat_app/models/models.dart';

class DocumentDetailScreen extends StatefulWidget {
  final Document document;
  final String userRole;

  const DocumentDetailScreen({
    super.key,
    required this.document,
    required this.userRole,
  });

  @override
  State<DocumentDetailScreen> createState() => _DocumentDetailScreenState();
}

class _DocumentDetailScreenState extends State<DocumentDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _service = DocumentService();
  final _commentController = TextEditingController();

  List<Document> _versionHistory = [];
  List<DocumentComment> _comments = [];
  bool _loadingHistory = true;
  bool _loadingComments = true;
  bool _postingComment = false;

  late Document _document;

  @override
  void initState() {
    super.initState();
    _document = widget.document;
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
    _service.logView(widget.document.id);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    _loadVersionHistory();
    _loadComments();
  }

  Future<void> _loadVersionHistory() async {
    setState(() => _loadingHistory = true);
    final history = await _service.getVersionHistory(widget.document.id);
    if (mounted) setState(() { _versionHistory = history; _loadingHistory = false; });
  }

  Future<void> _loadComments() async {
    setState(() => _loadingComments = true);
    final comments = await _service.getComments(widget.document.id);
    if (mounted) setState(() { _comments = comments; _loadingComments = false; });
  }

  Future<void> _openFile() async {
    await _service.logDownload(_document.id);
    final uri = Uri.parse(_document.fileUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open file')),
      );
    }
  }

  Future<void> _handleApproval() async {
    final result = await DocumentApprovalDialog.show(context, _document);
    if (result == true) {
      // Reload document state
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Decision recorded successfully')),
        );
        Navigator.pop(context, true); // Return true = document was updated
      }
    }
  }

  Future<void> _postComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    setState(() => _postingComment = true);
    try {
      final comment = await _service.addComment(_document.id, text);
      _commentController.clear();
      if (mounted) setState(() => _comments.add(comment));
    } finally {
      if (mounted) setState(() => _postingComment = false);
    }
  }

  bool get _canApprove =>
      widget.userRole == 'owner' &&
      _document.requiresOwnerApproval &&
      _document.approvalStatus == DocumentApprovalStatus.pendingApproval;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundGrey,
      appBar: AppBar(
        backgroundColor: AppTheme.primaryIndigo,
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _document.name,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              _document.category.label,
              style: const TextStyle(fontSize: 11, color: Colors.white70),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.download),
            tooltip: 'Open/Download',
            onPressed: _openFile,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.accentAmber,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: const [
            Tab(text: 'DETAILS'),
            Tab(text: 'COMMENTS'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildDetailsTab(),
          _buildCommentsTab(),
        ],
      ),
    );
  }

  Widget _buildDetailsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Status banner
        _buildStatusBanner(),
        const SizedBox(height: 16),

        // Document info card
        _buildInfoCard(),
        const SizedBox(height: 16),

        // Version history
        _buildVersionHistoryCard(),
        const SizedBox(height: 16),

        // Approve / reject buttons (owner only, pending docs)
        if (_canApprove) _buildApprovalActions(),
      ],
    );
  }

  Widget _buildStatusBanner() {
    Color bgColor;
    Color textColor;
    IconData icon;

    switch (_document.approvalStatus) {
      case DocumentApprovalStatus.approved:
        bgColor = AppTheme.successGreen.withValues(alpha: 0.1);
        textColor = AppTheme.successGreen;
        icon = LucideIcons.checkCircle;
        break;
      case DocumentApprovalStatus.pendingApproval:
        bgColor = AppTheme.warningOrange.withValues(alpha: 0.1);
        textColor = AppTheme.warningOrange;
        icon = LucideIcons.clock;
        break;
      case DocumentApprovalStatus.rejected:
        bgColor = AppTheme.errorRed.withValues(alpha: 0.1);
        textColor = AppTheme.errorRed;
        icon = LucideIcons.xCircle;
        break;
      case DocumentApprovalStatus.changesRequested:
        bgColor = const Color(0xFF6A1B9A).withValues(alpha: 0.1);
        textColor = const Color(0xFF6A1B9A);
        icon = LucideIcons.edit;
        break;
      default:
        bgColor = Colors.grey.withValues(alpha: 0.1);
        textColor = AppTheme.textSecondary;
        icon = LucideIcons.file;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, color: textColor, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _document.approvalStatus.label,
                  style: TextStyle(fontWeight: FontWeight.bold, color: textColor, fontSize: 13),
                ),
                if (_document.rejectionReason != null)
                  Text(
                    _document.rejectionReason!,
                    style: TextStyle(fontSize: 12, color: textColor.withValues(alpha: 0.8)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Document Info', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 12),
            _infoRow('Category', _document.category.label),
            if (_document.subcategory != null)
              _infoRow('Subcategory', _document.subcategory!),
            _infoRow('Version', 'v${_document.versionNumber}'),
            _infoRow('File Size', _document.fileSizeDisplay),
            _infoRow('Uploaded', timeago.format(_document.createdAt)),
            if (_document.expiresAt != null)
              _infoRow(
                'Expires',
                '${_document.expiresAt!.day}/${_document.expiresAt!.month}/${_document.expiresAt!.year}',
                valueColor: _document.isExpiringSoon ? AppTheme.warningOrange : null,
              ),
            if (_document.versionNotes != null && _document.versionNotes!.isNotEmpty)
              _infoRow('Version Notes', _document.versionNotes!),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label, style: const TextStyle(
              fontSize: 12, color: AppTheme.textSecondary, fontWeight: FontWeight.w500,
            )),
          ),
          Expanded(
            child: Text(value, style: TextStyle(
              fontSize: 12,
              color: valueColor,
              fontWeight: valueColor != null ? FontWeight.w600 : null,
            )),
          ),
        ],
      ),
    );
  }

  Widget _buildVersionHistoryCard() {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Version History', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 12),
            if (_loadingHistory)
              const Center(child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(),
              ))
            else if (_versionHistory.isEmpty)
              const Text('No version history', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13))
            else
              ...(_versionHistory.reversed.map((doc) => _buildVersionRow(doc)).toList()),
          ],
        ),
      ),
    );
  }

  Widget _buildVersionRow(Document doc) {
    final isCurrent = doc.id == _document.id;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: isCurrent ? AppTheme.primaryIndigo : Colors.grey[200],
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                'v${doc.versionNumber}',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: isCurrent ? Colors.white : AppTheme.textSecondary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  doc.versionNotes ?? 'Initial version',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isCurrent ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
                Text(
                  timeago.format(doc.createdAt),
                  style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
          if (isCurrent)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.primaryIndigo.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text('Current', style: TextStyle(fontSize: 10, color: AppTheme.primaryIndigo)),
            ),
        ],
      ),
    );
  }

  Widget _buildApprovalActions() {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      color: AppTheme.warningOrange.withValues(alpha: 0.05),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(LucideIcons.alertTriangle, color: AppTheme.warningOrange, size: 16),
                SizedBox(width: 8),
                Text('Awaiting Your Approval', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'This document requires your review and approval before the project can proceed.',
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _handleApproval,
                icon: const Icon(LucideIcons.clipboardCheck),
                label: const Text('Review & Decide', style: TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryIndigo,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCommentsTab() {
    return Column(
      children: [
        Expanded(
          child: _loadingComments
              ? const Center(child: CircularProgressIndicator())
              : _comments.isEmpty
                  ? const EmptyStateWidget(
                      icon: LucideIcons.messageSquare,
                      title: 'No comments yet',
                      subtitle: 'Be the first to add a comment',
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _comments.length,
                      itemBuilder: (_, i) => _buildCommentCard(_comments[i]),
                    ),
        ),

        // Comment input
        Container(
          padding: EdgeInsets.only(
            left: 16, right: 16, top: 12,
            bottom: 12 + MediaQuery.of(context).viewInsets.bottom,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 8)],
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _commentController,
                  decoration: InputDecoration(
                    hintText: 'Add a comment...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    isDense: true,
                  ),
                  maxLines: 3,
                  minLines: 1,
                ),
              ),
              const SizedBox(width: 8),
              Material(
                color: AppTheme.primaryIndigo,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: _postingComment ? null : _postComment,
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: _postingComment
                        ? const SizedBox(width: 20, height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(LucideIcons.send, color: Colors.white, size: 18),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCommentCard(DocumentComment comment) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(LucideIcons.user, size: 14, color: AppTheme.textSecondary),
                const SizedBox(width: 4),
                Text(
                  comment.userId?.substring(0, 8) ?? 'Unknown',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                Text(
                  timeago.format(comment.createdAt),
                  style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(comment.comment, style: const TextStyle(fontSize: 13)),
          ],
        ),
      ),
    );
  }
}
