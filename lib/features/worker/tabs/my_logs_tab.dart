import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:houzzdat_app/core/services/audio_recorder_service.dart';
import 'package:houzzdat_app/core/theme/app_theme.dart';
import 'package:houzzdat_app/core/widgets/shared_widgets.dart';
import 'package:houzzdat_app/features/worker/widgets/log_card.dart';

/// My Logs tab — displays only the current worker's voice notes
/// with enriched data (recipient names, action items, manager responses).
class MyLogsTab extends StatefulWidget {
  final String accountId;
  final String userId;
  final String? projectId;

  const MyLogsTab({
    super.key,
    required this.accountId,
    required this.userId,
    this.projectId,
  });

  @override
  State<MyLogsTab> createState() => _MyLogsTabState();
}

class _MyLogsTabState extends State<MyLogsTab> {
  final _supabase = Supabase.instance.client;
  final _recorderService = AudioRecorderService();
  bool _isRecording = false;
  bool _isUploading = false;
  bool _isLoading = true;
  String? _errorMessage;
  List<Map<String, dynamic>> _enrichedNotes = [];

  // Timer to refresh relative timestamps & delete button visibility
  Timer? _refreshTimer;

  // Realtime subscription for progressive voice note updates
  RealtimeChannel? _voiceNotesChannel;

  @override
  void initState() {
    super.initState();
    _loadNotes();
    _subscribeToRealtimeUpdates();
    // Refresh every 30 seconds for timestamp updates and delete countdown
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) {
        if (mounted) setState(() {});
      },
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _voiceNotesChannel?.unsubscribe();
    super.dispose();
  }

  /// Subscribe to Realtime changes on voice_notes for this worker.
  /// When the Edge Function writes progressive status updates
  /// (processing → transcribed → translated → completed),
  /// this fires and we patch the in-memory data instantly.
  void _subscribeToRealtimeUpdates() {
    _voiceNotesChannel = _supabase
        .channel('my-logs-${widget.userId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'voice_notes',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: widget.userId,
          ),
          callback: (payload) {
            final updatedNote = payload.newRecord;
            final noteId = updatedNote['id']?.toString();
            if (noteId == null || !mounted) return;

            // Patch the matching note in-memory — no full reload needed
            setState(() {
              final idx = _enrichedNotes.indexWhere(
                (n) => n['id']?.toString() == noteId,
              );
              if (idx != -1) {
                // Merge the updated fields into the enriched note,
                // preserving enrichment (recipient_name, action_item, etc.)
                _enrichedNotes[idx] = {
                  ..._enrichedNotes[idx],
                  ...updatedNote,
                };
              } else {
                // New note we don't have yet — full reload to get enrichment
                _loadNotes();
              }
            });
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'voice_notes',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: widget.userId,
          ),
          callback: (payload) {
            // New voice note inserted — reload to get full enrichment
            if (mounted) _loadNotes();
          },
        )
        .subscribe();
  }

  // ─── Recording Logic (unchanged) ────────────────────────────

  Future<void> _handleRecording() async {
    final hasPermission = await _recorderService.checkPermission();
    if (!hasPermission) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Microphone permission required')),
        );
      }
      return;
    }

    if (!_isRecording) {
      // Check project assignment before starting recording
      if (widget.projectId == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No project assigned. Please contact your manager.'),
              backgroundColor: AppTheme.warningOrange,
            ),
          );
        }
        return;
      }
      await _recorderService.startRecording();
      setState(() => _isRecording = true);
    } else {
      setState(() {
        _isRecording = false;
        _isUploading = true;
      });

      try {
        final audioBytes = await _recorderService.stopRecording();
        if (audioBytes != null && widget.projectId != null) {
          await _recorderService.uploadAudio(
            bytes: audioBytes,
            projectId: widget.projectId!,
            userId: widget.userId,
            accountId: widget.accountId,
          );

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Voice note submitted'),
                backgroundColor: AppTheme.successGreen,
              ),
            );
            // Refresh to show new note
            _loadNotes();
          }
        }
      } catch (e) {
        debugPrint('MyLogsTab: Recording error: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not send voice note. Please check your connection and try again.'), backgroundColor: AppTheme.errorRed),
          );
        }
      } finally {
        if (mounted) setState(() => _isUploading = false);
      }
    }
  }

  // ─── Data Loading & Enrichment ──────────────────────────────

  Future<void> _loadNotes() async {
    if (!mounted) return;
    setState(() {
      _isLoading = _enrichedNotes.isEmpty;
      _errorMessage = null;
    });

    try {
      // 1. Fetch voice notes for this worker (top-level only)
      //    Filter by both user_id AND account_id for multi-company correctness
      final notes = await _supabase
          .from('voice_notes')
          .select()
          .eq('user_id', widget.userId)
          .eq('account_id', widget.accountId)
          .isFilter('parent_id', null)
          .order('created_at', ascending: false);

      final notesList = List<Map<String, dynamic>>.from(notes);

      if (notesList.isEmpty) {
        if (mounted) {
          setState(() {
            _enrichedNotes = [];
            _isLoading = false;
          });
        }
        return;
      }

      // 2. Collect IDs for batch queries
      final noteIds = notesList
          .map((n) => n['id']?.toString())
          .where((id) => id != null)
          .cast<String>()
          .toList();

      final recipientIds = notesList
          .map((n) => n['recipient_id']?.toString())
          .where((id) => id != null && id.isNotEmpty)
          .cast<String>()
          .toSet()
          .toList();

      // 3. Batch fetch action items linked to these voice notes
      Map<String, Map<String, dynamic>> actionItemsByVoiceNote = {};
      if (noteIds.isNotEmpty) {
        try {
          final actionItems = await _supabase
              .from('action_items')
              .select(
                  'id, voice_note_id, status, summary, assigned_to, interaction_history, created_at')
              .inFilter('voice_note_id', noteIds);

          for (final ai in actionItems) {
            final vnId = ai['voice_note_id']?.toString();
            if (vnId != null) {
              actionItemsByVoiceNote[vnId] = Map<String, dynamic>.from(ai);
            }
          }
        } catch (e) {
          debugPrint('MyLogsTab: Error fetching action items: $e');
        }
      }

      // 4. Collect all user IDs we need to resolve names for
      final userIdsToResolve = <String>{};
      userIdsToResolve.addAll(recipientIds);

      // Add assigned_to from action items
      for (final ai in actionItemsByVoiceNote.values) {
        final assignedTo = ai['assigned_to']?.toString();
        if (assignedTo != null && assignedTo.isNotEmpty) {
          userIdsToResolve.add(assignedTo);
        }
        // Add user IDs from interaction history
        final history = ai['interaction_history'];
        if (history is List) {
          for (final entry in history) {
            final uid = entry['user_id']?.toString();
            if (uid != null && uid.isNotEmpty) {
              userIdsToResolve.add(uid);
            }
          }
        }
      }

      // 5. Batch fetch user names
      Map<String, String> userNames = {};
      if (userIdsToResolve.isNotEmpty) {
        try {
          final users = await _supabase
              .from('users')
              .select('id, email, full_name')
              .inFilter('id', userIdsToResolve.toList());

          for (final u in users) {
            final id = u['id']?.toString();
            if (id != null) {
              userNames[id] = u['full_name']?.toString() ??
                  u['email']?.toString() ??
                  'Unknown';
            }
          }
        } catch (e) {
          debugPrint('MyLogsTab: Error fetching user names: $e');
        }
      }

      // 6. Enrich each note
      final enriched = notesList.map((note) {
        final noteId = note['id']?.toString() ?? '';
        final recipientId = note['recipient_id']?.toString();
        final actionItem = actionItemsByVoiceNote[noteId];

        // Resolve recipient name
        String? recipientName;
        if (recipientId != null && userNames.containsKey(recipientId)) {
          recipientName = userNames[recipientId];
        } else if (actionItem != null) {
          // Fallback: use action item's assigned_to
          final assignedTo = actionItem['assigned_to']?.toString();
          if (assignedTo != null && userNames.containsKey(assignedTo)) {
            recipientName = userNames[assignedTo];
          }
        }

        // Enrich interaction history with names
        List<Map<String, dynamic>>? managerResponses;
        if (actionItem != null && actionItem['interaction_history'] is List) {
          managerResponses = (actionItem['interaction_history'] as List)
              .map((entry) {
            final uid = entry['user_id']?.toString();
            return {
              ...Map<String, dynamic>.from(entry),
              'user_name': uid != null ? (userNames[uid] ?? 'Manager') : 'Manager',
            };
          }).toList();
        }

        return {
          ...note,
          'recipient_name': recipientName,
          'action_item': actionItem,
          'manager_responses': managerResponses,
        };
      }).toList();

      if (mounted) {
        setState(() {
          _enrichedNotes = enriched;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('MyLogsTab: Error loading notes: $e');
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  // ─── Build ──────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Record hero section (unchanged)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 24),
          color: Colors.white,
          child: Column(
            children: [
              Text(
                _isUploading
                    ? 'Uploading note...'
                    : _isRecording
                        ? 'Recording... Tap to stop'
                        : 'Tap to Record Site Note',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF424242),
                ),
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: _isUploading ? null : _handleRecording,
                child: CircleAvatar(
                  radius: 44,
                  backgroundColor:
                      _isRecording ? Colors.red : const Color(0xFFFFCA28),
                  child: _isUploading
                      ? const SizedBox(
                          width: 28,
                          height: 28,
                          child: CircularProgressIndicator(
                            color: Colors.black,
                            strokeWidth: 3,
                          ),
                        )
                      : Icon(
                          _isRecording ? LucideIcons.square : LucideIcons.mic,
                          size: 32,
                          color: Colors.black,
                        ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 4),

        // Notes list
        Expanded(
          child: _buildNotesList(),
        ),
      ],
    );
  }

  Widget _buildNotesList() {
    if (_isLoading) {
      return const LoadingWidget(message: 'Loading your notes...');
    }

    if (_errorMessage != null) {
      return ErrorStateWidget(
        message: _errorMessage!,
        onRetry: _loadNotes,
      );
    }

    if (_enrichedNotes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(LucideIcons.micOff, size: 56, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text('No voice notes yet',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 15)),
            const SizedBox(height: 4),
            Text('Tap the mic above to create your first note',
                style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadNotes,
      color: AppTheme.primaryIndigo,
      child: ListView.builder(
        padding: const EdgeInsets.only(top: 8, bottom: 24),
        itemCount: _enrichedNotes.length,
        itemBuilder: (context, i) {
          return LogCard(
            note: _enrichedNotes[i],
            accountId: widget.accountId,
            userId: widget.userId,
            projectId: widget.projectId,
            onDeleted: _loadNotes,
          );
        },
      ),
    );
  }
}
