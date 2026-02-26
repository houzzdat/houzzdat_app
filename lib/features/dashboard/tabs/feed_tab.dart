import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:houzzdat_app/core/theme/app_theme.dart';
import 'package:houzzdat_app/core/widgets/shared_widgets.dart';
import 'package:houzzdat_app/features/voice_notes/widgets/voice_note_card.dart';
import 'package:houzzdat_app/core/services/audio_recorder_service.dart';
import 'package:houzzdat_app/features/dashboard/widgets/reply_voice_dialog.dart';
import 'dart:typed_data';

class FeedTab extends StatefulWidget {
  final String? accountId;
  const FeedTab({super.key, required this.accountId});

  @override
  State<FeedTab> createState() => _FeedTabState();
}

class _FeedTabState extends State<FeedTab> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true; // UX-audit #3: preserve tab state
  final _supabase = Supabase.instance.client;
  final _recorderService = AudioRecorderService();
  final _searchController = TextEditingController();

  // Filter State
  String? _selectedProjectId;
  String? _selectedUserId;
  String _searchQuery = '';
  String _sortBy = 'newest';

  // Acknowledged IDs (local tracking for instant UI feedback)
  final Set<String> _acknowledgedIds = {};

  // Cached lookup data
  Map<String, String> _projectNames = {};
  Map<String, String> _userEmails = {};

  // Daily report IDs to exclude from feed
  List<String> _dailyReportIds = [];

  @override
  void initState() {
    super.initState();
    _loadLookups();
    _refreshDailyReportIds();
  }

  Future<void> _loadLookups() async {
    if (widget.accountId == null || widget.accountId!.isEmpty) return;
    try {
      final projects = await _supabase
          .from('projects')
          .select('id, name')
          .eq('account_id', widget.accountId!);
      final users = await _supabase
          .from('users')
          .select('id, email, full_name')
          .eq('account_id', widget.accountId!);

      if (mounted) {
        setState(() {
          _projectNames = {for (var p in projects) p['id'].toString(): p['name']?.toString() ?? 'Site'};
          _userEmails = {for (var u in users) u['id'].toString(): u['full_name']?.toString() ?? u['email']?.toString() ?? 'User'};
        });
      }
    } catch (e) {
      debugPrint('Error loading lookups: $e');
      if (mounted) setState(() {});
    }
  }

  Future<void> _refreshDailyReportIds() async {
    if (widget.accountId == null) return;
    try {
      final attendance = await _supabase
          .from('attendance')
          .select('report_voice_note_id')
          .eq('account_id', widget.accountId!)
          .not('report_voice_note_id', 'is', null);

      final ids = attendance
          .map((a) => a['report_voice_note_id']?.toString())
          .where((id) => id != null)
          .cast<String>()
          .toList();

      if (mounted) setState(() => _dailyReportIds = ids);
    } catch (e) {
      debugPrint('Error loading daily report IDs: $e');
    }
  }

  Stream<List<Map<String, dynamic>>> _getVoiceNotesStream() {
    if (widget.accountId == null || widget.accountId!.isEmpty) {
      return Stream.value([]);
    }

    return _supabase
        .from('voice_notes')
        .stream(primaryKey: ['id'])
        .eq('account_id', widget.accountId!)
        .order('created_at', ascending: false);
  }

  List<Map<String, dynamic>> _applyFilters(List<Map<String, dynamic>> notes) {
    var result = notes.where((n) {
      if (_selectedProjectId != null && n['project_id'] != _selectedProjectId) {
        return false;
      }
      if (_selectedUserId != null && n['user_id'] != _selectedUserId) {
        return false;
      }

      // Search filter
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final transcript = (n['transcript_final'] ?? n['transcription'] ?? '').toString().toLowerCase();
        final userEmail = (_userEmails[n['user_id']?.toString()] ?? '').toLowerCase();
        final projectName = (_projectNames[n['project_id']?.toString()] ?? '').toLowerCase();
        if (!transcript.contains(query) && !userEmail.contains(query) && !projectName.contains(query)) {
          return false;
        }
      }

      // Exclude daily reports from feed
      final noteId = n['id']?.toString();
      if (noteId != null && _dailyReportIds.contains(noteId)) {
        return false;
      }

      return true;
    }).toList();

    // Apply sorting
    switch (_sortBy) {
      case 'newest':
        result.sort((a, b) {
          final aTime = a['created_at']?.toString() ?? '';
          final bTime = b['created_at']?.toString() ?? '';
          return bTime.compareTo(aTime);
        });
        break;
      case 'oldest':
        result.sort((a, b) {
          final aTime = a['created_at']?.toString() ?? '';
          final bTime = b['created_at']?.toString() ?? '';
          return aTime.compareTo(bTime);
        });
        break;
    }

    return result;
  }

  void _handleReply(Map<String, dynamic> note) async {
    final senderName = _userEmails[note['user_id']?.toString()] ?? 'Unknown';
    final projectName = _projectNames[note['project_id']?.toString()];
    final transcript = note['transcript_final']?.toString() ??
        note['transcription']?.toString();

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => ReplyVoiceDialog(
        senderName: senderName,
        transcriptPreview: transcript,
        projectName: projectName,
      ),
    );

    if (result == null || !mounted) return;

    // Handle voice reply
    if (result.containsKey('audioBytes')) {
      final bytes = result['audioBytes'] as Uint8List;
      await _recorderService.uploadAudio(
        bytes: bytes,
        projectId: note['project_id'],
        userId: _supabase.auth.currentUser!.id,
        accountId: widget.accountId!,
        parentId: note['id'],
        recipientId: note['user_id'],
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Voice reply sent'),
            backgroundColor: AppTheme.successGreen,
          ),
        );
      }
    }
    // Handle text reply (store as a project event)
    else if (result.containsKey('textReply')) {
      try {
        await _supabase.from('voice_note_project_events').insert({
          'voice_note_id': note['id'],
          'project_id': note['project_id'],
          'account_id': widget.accountId,
          'user_id': _supabase.auth.currentUser?.id,
          'event_type': 'text_reply',
          'content': result['textReply'],
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Text reply sent'),
              backgroundColor: AppTheme.successGreen,
            ),
          );
        }
      } catch (e) {
        debugPrint('Error sending text reply: $e');
      }
    }
  }

  Future<void> _handleAcknowledge(Map<String, dynamic> note) async {
    final noteId = note['id']?.toString();
    if (noteId == null) return;

    try {
      await _supabase.from('voice_notes').update({
        'acknowledged_by': _supabase.auth.currentUser?.id,
        'acknowledged_at': DateTime.now().toIso8601String(),
      }).eq('id', noteId);

      setState(() => _acknowledgedIds.add(noteId));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Update acknowledged'),
            backgroundColor: AppTheme.successGreen,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error acknowledging note: $e');
    }
  }

  Future<void> _handleAddNoteToVoiceNote(Map<String, dynamic> note) async {
    final controller = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Note'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: 'Enter your note about this update...',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryIndigo),
            child: const Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (text != null && text.isNotEmpty) {
      try {
        await _supabase.from('voice_note_project_events').insert({
          'voice_note_id': note['id'],
          'project_id': note['project_id'],
          'account_id': widget.accountId,
          'user_id': _supabase.auth.currentUser?.id,
          'event_type': 'manager_note',
          'content': text,
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Note added to update'),
              backgroundColor: AppTheme.successGreen,
            ),
          );
        }
      } catch (e) {
        debugPrint('Error adding note: $e');
      }
    }
  }

  Future<void> _handleCreateActionFromNote(Map<String, dynamic> note) async {
    final result = await showModalBottomSheet<Map<String, String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _CreateActionSheet(note: note),
    );

    if (result == null) return;

    final isCritical = result['priority'] == 'High' && result['category'] == 'action_required';

    try {
      final insertResult = await _supabase.from('action_items').insert({
        'voice_note_id': note['id'],
        'project_id': note['project_id'],
        'account_id': widget.accountId,
        'user_id': note['user_id'],
        'category': result['category'],
        'priority': result['priority'],
        'status': 'pending',
        'is_critical_flag': isCritical,
        'summary': result['summary']?.isNotEmpty == true
            ? result['summary']
            : note['transcript_en_current'] ??
              note['transcript_final'] ??
              note['transcript'] ??
              'Action from voice note',
        'ai_analysis': note['ai_analysis'],
      }).select('id').single();

      // Record correction: AI classified as "update" but manager promoted it
      await _supabase.from('ai_corrections').insert({
        'voice_note_id': note['id'],
        'action_item_id': insertResult['id'],
        'project_id': note['project_id'],
        'account_id': widget.accountId,
        'correction_type': 'promoted_to_action',
        'original_value': note['category'] ?? 'update',
        'corrected_value': result['category'],
        'corrected_by': _supabase.auth.currentUser?.id,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Text('${_categoryLabel(result['category']!)} created — ${result['priority']} priority'),
              ],
            ),
            backgroundColor: _categoryColor(result['category']!),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error creating action: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to create action item'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    }
  }

  String _categoryLabel(String category) {
    switch (category) {
      case 'action_required': return 'Action Required';
      case 'approval':        return 'Approval Request';
      case 'update':          return 'Update';
      default:                return 'Action';
    }
  }

  Color _categoryColor(String category) {
    switch (category) {
      case 'action_required': return AppTheme.errorRed;
      case 'approval':        return AppTheme.warningOrange;
      default:                return AppTheme.successGreen;
    }
  }

  Widget _buildFilterChip(
    String label,
    String? currentValue,
    List<(String?, String)> options,
    Function(String?) onChanged,
  ) {
    final displayValue = options.firstWhere(
      (o) => o.$1 == currentValue,
      orElse: () => options.first,
    ).$2;

    return PopupMenuButton<String?>(
      onSelected: onChanged,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacingM,
          vertical: AppTheme.spacingS,
        ),
        decoration: BoxDecoration(
          border: Border.all(color: AppTheme.primaryIndigo),
          borderRadius: BorderRadius.circular(AppTheme.radiusL),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                '$label: $displayValue',
                style: const TextStyle(
                  color: AppTheme.primaryIndigo,
                  fontWeight: FontWeight.w500,
                  fontSize: 12,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Icon(
              Icons.arrow_drop_down,
              color: AppTheme.primaryIndigo,
              size: 18,
            ),
          ],
        ),
      ),
      itemBuilder: (context) => options
          .map(
            (option) => PopupMenuItem<String?>(
              value: option.$1,
              child: Text(option.$2),
            ),
          )
          .toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // UX-audit #3: required by AutomaticKeepAliveClientMixin
    if (widget.accountId == null || widget.accountId!.isEmpty) {
      return const LoadingWidget();
    }

    return Column(
      children: [
        // Search Bar (matching Actions tab)
        Container(
          padding: const EdgeInsets.fromLTRB(
            AppTheme.spacingM, AppTheme.spacingM, AppTheme.spacingM, 0,
          ),
          color: Theme.of(context).cardColor,
          child: TextField(
            controller: _searchController,
            onChanged: (value) => setState(() => _searchQuery = value),
            decoration: InputDecoration(
              hintText: 'Search voice notes...',
              prefixIcon: const Icon(Icons.search, color: AppTheme.textSecondary),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 20),
                      tooltip: 'Clear search', // UX-audit #21
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
              filled: true,
              fillColor: AppTheme.backgroundGrey,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusL),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spacingM,
                vertical: AppTheme.spacingS,
              ),
            ),
          ),
        ),

        // Filter & Sort Bar (matching Actions tab)
        Container(
          padding: const EdgeInsets.all(AppTheme.spacingM),
          color: Theme.of(context).cardColor,
          child: Row(
            children: [
              Expanded(
                child: _buildFilterChip(
                  'Site',
                  _selectedProjectId,
                  [
                    (null, 'All'),
                    ..._projectNames.entries.map((e) => (e.key, e.value)),
                  ],
                  (value) => setState(() => _selectedProjectId = value),
                ),
              ),
              const SizedBox(width: AppTheme.spacingS),
              Expanded(
                child: _buildFilterChip(
                  'User',
                  _selectedUserId,
                  [
                    (null, 'All'),
                    ..._userEmails.entries.map((e) => (e.key, e.value)),
                  ],
                  (value) => setState(() => _selectedUserId = value),
                ),
              ),
              const SizedBox(width: AppTheme.spacingS),
              // Sort button
              PopupMenuButton<String>(
                onSelected: (value) => setState(() => _sortBy = value),
                tooltip: 'Sort',
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spacingS,
                    vertical: AppTheme.spacingS,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppTheme.primaryIndigo),
                    borderRadius: BorderRadius.circular(AppTheme.radiusL),
                  ),
                  child: const Icon(
                    Icons.sort,
                    color: AppTheme.primaryIndigo,
                    size: 20,
                  ),
                ),
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'newest',
                    child: Row(
                      children: [
                        Icon(Icons.arrow_downward, size: 18,
                          color: _sortBy == 'newest' ? AppTheme.primaryIndigo : AppTheme.textSecondary),
                        const SizedBox(width: AppTheme.spacingS),
                        Text('Newest First',
                          style: TextStyle(
                            fontWeight: _sortBy == 'newest' ? FontWeight.bold : FontWeight.normal,
                            color: _sortBy == 'newest' ? AppTheme.primaryIndigo : AppTheme.textPrimary,
                          )),
                        if (_sortBy == 'newest') ...[
                          const Spacer(),
                          const Icon(Icons.check, size: 18, color: AppTheme.primaryIndigo),
                        ],
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'oldest',
                    child: Row(
                      children: [
                        Icon(Icons.arrow_upward, size: 18,
                          color: _sortBy == 'oldest' ? AppTheme.primaryIndigo : AppTheme.textSecondary),
                        const SizedBox(width: AppTheme.spacingS),
                        Text('Oldest First',
                          style: TextStyle(
                            fontWeight: _sortBy == 'oldest' ? FontWeight.bold : FontWeight.normal,
                            color: _sortBy == 'oldest' ? AppTheme.primaryIndigo : AppTheme.textPrimary,
                          )),
                        if (_sortBy == 'oldest') ...[
                          const Spacer(),
                          const Icon(Icons.check, size: 18, color: AppTheme.primaryIndigo),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Results count when searching
        if (_searchQuery.isNotEmpty)
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: _getVoiceNotesStream(),
            builder: (context, snap) {
              final count = snap.hasData ? _applyFilters(snap.data!).length : 0;
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spacingM,
                  vertical: AppTheme.spacingS,
                ),
                color: AppTheme.infoBlue.withValues(alpha: 0.05),
                child: Row(
                  children: [
                    const Icon(Icons.search, size: 16, color: AppTheme.infoBlue),
                    const SizedBox(width: AppTheme.spacingS),
                    Text(
                      '$count result${count == 1 ? '' : 's'} for "$_searchQuery"',
                      style: const TextStyle(
                        color: AppTheme.infoBlue,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

        // Voice Notes List
        Expanded(
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: _getVoiceNotesStream(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const ShimmerLoadingList(itemCount: 5, itemHeight: 140); // UX-audit #4: shimmer instead of spinner
              }

              if (snap.hasError) {
                return ErrorStateWidget(
                  message: snap.error.toString(),
                  onRetry: () => setState(() {}),
                );
              }

              if (!snap.hasData || snap.data!.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.voice_over_off,
                        size: 64,
                        color: AppTheme.textSecondary.withValues(alpha: 0.3),
                      ),
                      const SizedBox(height: AppTheme.spacingM),
                      Text(
                        'No voice notes found',
                        style: TextStyle(
                          color: AppTheme.textSecondary.withValues(alpha: 0.5),
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: AppTheme.spacingS),
                      Text(
                        'Voice notes from your team will appear here',
                        style: TextStyle(
                          color: AppTheme.textSecondary.withValues(alpha: 0.5),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                );
              }

              final filteredNotes = _applyFilters(snap.data!);

              if (filteredNotes.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _searchQuery.isNotEmpty ? Icons.search_off : Icons.filter_list_off,
                        size: 64,
                        color: AppTheme.textSecondary.withValues(alpha: 0.3),
                      ),
                      const SizedBox(height: AppTheme.spacingM),
                      Text(
                        _searchQuery.isNotEmpty
                            ? 'No matching voice notes'
                            : 'No notes match your filters',
                        style: TextStyle(
                          color: AppTheme.textSecondary.withValues(alpha: 0.5),
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: AppTheme.spacingS),
                      Text(
                        _searchQuery.isNotEmpty
                            ? 'Try a different search term'
                            : 'Try changing your filters',
                        style: TextStyle(
                          color: AppTheme.textSecondary.withValues(alpha: 0.5),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                );
              }

              return RefreshIndicator(
                onRefresh: () async => setState(() {}),
                child: ListView.builder(
                  padding: const EdgeInsets.only(
                    top: AppTheme.spacingS,
                    bottom: AppTheme.spacingXL,
                  ),
                  cacheExtent: 500, // UX-audit #6: improved scroll perf
                  itemCount: filteredNotes.length,
                  itemBuilder: (context, i) {
                    final note = filteredNotes[i];

                    return VoiceNoteCard(
                      note: note,
                      isReplying: false,
                      onReply: () => _handleReply(note),
                      senderName: _userEmails[note['user_id']?.toString()],
                      projectName: _projectNames[note['project_id']?.toString()],
                      onAcknowledge: () => _handleAcknowledge(note),
                      onAddNote: () => _handleAddNoteToVoiceNote(note),
                      onCreateAction: () => _handleCreateActionFromNote(note),
                      isAcknowledged: _acknowledgedIds.contains(note['id']?.toString()) ||
                          note['acknowledged_by'] != null,
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}

// ============================================================
// CREATE ACTION BOTTOM SHEET
// ============================================================
class _CreateActionSheet extends StatefulWidget {
  final Map<String, dynamic> note;
  const _CreateActionSheet({required this.note});

  @override
  State<_CreateActionSheet> createState() => _CreateActionSheetState();
}

class _CreateActionSheetState extends State<_CreateActionSheet> {
  String _category = 'action_required';
  String _priority = 'Med';
  late TextEditingController _summaryController;

  // ── Category config ──────────────────────────────────────────
  static const _categories = [
    (
      value: 'action_required',
      label: 'Action Required',
      sublabel: 'Work that must be done on site',
      icon: Icons.engineering_rounded,
      color: AppTheme.errorRed,
    ),
    (
      value: 'approval',
      label: 'Approval Request',
      sublabel: 'Needs manager sign-off or owner consent',
      icon: Icons.fact_check_rounded,
      color: AppTheme.warningOrange,
    ),
    (
      value: 'update',
      label: 'Update / Info',
      sublabel: 'Progress note, no action needed',
      icon: Icons.info_rounded,
      color: AppTheme.successGreen,
    ),
  ];

  // ── Priority config ──────────────────────────────────────────
  static const _priorities = [
    (
      value: 'High',
      label: 'High',
      sublabel: 'Urgent — must be done today',
      icon: Icons.arrow_upward_rounded,
      color: AppTheme.errorRed,
    ),
    (
      value: 'Med',
      label: 'Medium',
      sublabel: 'Important — address within 2–3 days',
      icon: Icons.remove_rounded,
      color: AppTheme.warningOrange,
    ),
    (
      value: 'Low',
      label: 'Low',
      sublabel: 'Can wait — complete when possible',
      icon: Icons.arrow_downward_rounded,
      color: AppTheme.successGreen,
    ),
  ];

  Color get _currentCategoryColor =>
      _categories.firstWhere((c) => c.value == _category).color;

  @override
  void initState() {
    super.initState();
    // Pre-fill summary from the best available transcript field
    final note = widget.note;
    final pre = note['transcript_en_current'] ??
        note['transcript_final'] ??
        note['transcript'] ??
        note['ai_suggested_summary'] ??
        '';
    _summaryController = TextEditingController(text: pre);
  }

  @override
  void dispose() {
    _summaryController.dispose();
    super.dispose();
  }

  void _submit() {
    Navigator.of(context).pop({
      'category': _category,
      'priority': _priority,
      'summary': _summaryController.text.trim(),
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomPad = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(0, 0, 0, bottomPad),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Handle + header ─────────────────────────────────
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 4),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.dividerColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _currentCategoryColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.add_task_rounded,
                        color: _currentCategoryColor, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Create Action Item',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'from voice note',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ── Category selector ────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'TYPE',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textSecondary,
                  letterSpacing: 1.0,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: _categories.map((cat) {
                  final selected = _category == cat.value;
                  return GestureDetector(
                    onTap: () => setState(() => _category = cat.value),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: selected
                            ? cat.color.withValues(alpha: 0.10)
                            : theme.cardColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: selected
                              ? cat.color
                              : theme.dividerColor,
                          width: selected ? 1.8 : 1.0,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: cat.color.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(cat.icon,
                                color: cat.color, size: 18),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  cat.label,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                    color: selected
                                        ? cat.color
                                        : null,
                                  ),
                                ),
                                Text(
                                  cat.sublabel,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (selected)
                            Icon(Icons.check_circle_rounded,
                                color: cat.color, size: 20)
                          else
                            Icon(Icons.circle_outlined,
                                color: theme.dividerColor, size: 20),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 16),

            // ── Priority selector ────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'PRIORITY',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textSecondary,
                  letterSpacing: 1.0,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: _priorities.map((pri) {
                  final selected = _priority == pri.value;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _priority = pri.value),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: selected
                              ? pri.color.withValues(alpha: 0.12)
                              : theme.cardColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: selected ? pri.color : theme.dividerColor,
                            width: selected ? 1.8 : 1.0,
                          ),
                        ),
                        child: Column(
                          children: [
                            Icon(pri.icon,
                                color: selected
                                    ? pri.color
                                    : AppTheme.textSecondary,
                                size: 22),
                            const SizedBox(height: 4),
                            Text(
                              pri.label,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: selected ? pri.color : null,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              pri.sublabel,
                              style: const TextStyle(
                                fontSize: 10,
                                color: AppTheme.textSecondary,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 16),

            // ── Summary / instruction field ──────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'SUMMARY / INSTRUCTIONS',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textSecondary,
                  letterSpacing: 1.0,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _summaryController,
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: 'Describe what needs to be done…',
                  filled: true,
                  fillColor: theme.cardColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: theme.dividerColor),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: theme.dividerColor),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                        color: _currentCategoryColor, width: 1.8),
                  ),
                  contentPadding: const EdgeInsets.all(14),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // ── Action buttons ───────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: _submit,
                      icon: const Icon(Icons.add_task_rounded,
                          color: Colors.white, size: 18),
                      label: const Text(
                        'Create Action',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _currentCategoryColor,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
