import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:houzzdat_app/core/theme/app_theme.dart';
import 'package:houzzdat_app/core/widgets/shared_widgets.dart';
import 'package:houzzdat_app/features/voice_notes/widgets/voice_note_card.dart';
import 'package:houzzdat_app/core/services/audio_recorder_service.dart';
import 'dart:typed_data';

class FeedTab extends StatefulWidget {
  final String? accountId;
  const FeedTab({super.key, required this.accountId});

  @override
  State<FeedTab> createState() => _FeedTabState();
}

class _FeedTabState extends State<FeedTab> {
  final _supabase = Supabase.instance.client;
  final _recorderService = AudioRecorderService();
  final _searchController = TextEditingController();

  // Filter State
  String? _selectedProjectId;
  String? _selectedUserId;
  String _searchQuery = '';
  String _sortBy = 'newest';

  // Reply State
  bool _isReplying = false;
  String? _replyToId;

  // Acknowledged IDs (local tracking for instant UI feedback)
  final Set<String> _acknowledgedIds = {};

  // Cached lookup data
  Map<String, String> _projectNames = {};
  Map<String, String> _userEmails = {};

  @override
  void initState() {
    super.initState();
    _loadLookups();
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
    if (!_isReplying) {
      await _recorderService.startRecording();
      setState(() {
        _isReplying = true;
        _replyToId = note['id'];
      });
    } else {
      setState(() => _isReplying = false);
      Uint8List? bytes = await _recorderService.stopRecording();
      if (bytes != null) {
        await _recorderService.uploadAudio(
          bytes: bytes,
          projectId: note['project_id'],
          userId: _supabase.auth.currentUser!.id,
          accountId: widget.accountId!,
          parentId: note['id'],
          recipientId: note['user_id'],
        );
        setState(() {
          _replyToId = null;
        });
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
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) {
        String category = 'action_required';
        String priority = 'Med';
        return StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            title: const Text('Create Action Item'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Category:', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                DropdownButtonFormField<String>(
                  value: category,
                  items: const [
                    DropdownMenuItem(value: 'action_required', child: Text('Action Required')),
                    DropdownMenuItem(value: 'approval', child: Text('Approval')),
                  ],
                  onChanged: (v) => setDialogState(() => category = v ?? category),
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
                const SizedBox(height: 12),
                const Text('Priority:', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                DropdownButtonFormField<String>(
                  value: priority,
                  items: const [
                    DropdownMenuItem(value: 'High', child: Text('High')),
                    DropdownMenuItem(value: 'Med', child: Text('Medium')),
                    DropdownMenuItem(value: 'Low', child: Text('Low')),
                  ],
                  onChanged: (v) => setDialogState(() => priority = v ?? priority),
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, {
                  'category': category,
                  'priority': priority,
                }),
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryIndigo),
                child: const Text('Create', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
      },
    );

    if (result == null) return;

    try {
      final insertResult = await _supabase.from('action_items').insert({
        'voice_note_id': note['id'],
        'project_id': note['project_id'],
        'account_id': widget.accountId,
        'user_id': note['user_id'],
        'category': result['category'],
        'priority': result['priority'],
        'status': 'pending',
        'summary': note['transcript'] ?? note['transcript_final'] ?? 'Action from voice note',
        'ai_analysis': note['ai_analysis'],
      }).select('id').single();

      // Record correction: AI classified as "update" but manager promoted it
      await _supabase.from('ai_corrections').insert({
        'voice_note_id': note['id'],
        'action_item_id': insertResult['id'],
        'project_id': note['project_id'],
        'account_id': widget.accountId,
        'correction_type': 'promoted_to_action',
        'original_value': 'update',
        'corrected_value': result['category'],
        'corrected_by': _supabase.auth.currentUser?.id,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Action item created from update'),
            backgroundColor: AppTheme.successGreen,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error creating action: $e');
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
          color: Colors.white,
          child: TextField(
            controller: _searchController,
            onChanged: (value) => setState(() => _searchQuery = value),
            decoration: InputDecoration(
              hintText: 'Search voice notes...',
              prefixIcon: const Icon(Icons.search, color: AppTheme.textSecondary),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 20),
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
          color: Colors.white,
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
                return const LoadingWidget(message: 'Loading voice notes...');
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
                  itemCount: filteredNotes.length,
                  itemBuilder: (context, i) {
                    final note = filteredNotes[i];
                    final isReplying = _replyToId == note['id'];

                    return Column(
                      children: [
                        VoiceNoteCard(
                          note: note,
                          isReplying: isReplying,
                          onReply: () => _handleReply(note),
                          senderName: _userEmails[note['user_id']?.toString()],
                          projectName: _projectNames[note['project_id']?.toString()],
                          onAcknowledge: () => _handleAcknowledge(note),
                          onAddNote: () => _handleAddNoteToVoiceNote(note),
                          onCreateAction: () => _handleCreateActionFromNote(note),
                          isAcknowledged: _acknowledgedIds.contains(note['id']?.toString()) ||
                              note['acknowledged_by'] != null,
                        ),
                        if (isReplying)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            child: Row(
                              children: [
                                const Icon(Icons.reply, size: 20),
                                const SizedBox(width: 8),
                                const Expanded(
                                  child: Text(
                                    'Recording reply...',
                                    style: TextStyle(fontStyle: FontStyle.italic),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.stop, color: Colors.red),
                                  onPressed: () => _handleReply(note),
                                ),
                              ],
                            ),
                          ),
                      ],
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
