import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:houzzdat_app/core/theme/app_theme.dart';
import 'package:houzzdat_app/core/widgets/shared_widgets.dart';
import 'package:houzzdat_app/features/dashboard/widgets/feed_filters_widget.dart';
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

  // Filter State
  String? _selectedProjectId;
  String? _selectedUserId;
  DateTime? _selectedDate;

  // Reply State
  bool _isReplying = false;
  String? _replyToId;

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
    return notes.where((n) {
      if (_selectedProjectId != null && n['project_id'] != _selectedProjectId) {
        return false;
      }
      if (_selectedUserId != null && n['user_id'] != _selectedUserId) {
        return false;
      }
      if (_selectedDate != null) {
        final noteDate = DateTime.parse(n['created_at']);
        if (noteDate.year != _selectedDate!.year ||
            noteDate.month != _selectedDate!.month ||
            noteDate.day != _selectedDate!.day) {
          return false;
        }
      }
      return true;
    }).toList();
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

  void _onFiltersChanged({
    String? projectId,
    String? userId,
    DateTime? date,
  }) {
    setState(() {
      _selectedProjectId = projectId;
      _selectedUserId = userId;
      _selectedDate = date;
    });
  }

  void _clearFilters() {
    setState(() {
      _selectedProjectId = null;
      _selectedUserId = null;
      _selectedDate = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.accountId == null || widget.accountId!.isEmpty) {
      return const LoadingWidget();
    }

    return Column(
      children: [
        FeedFiltersWidget(
          accountId: widget.accountId!,
          selectedProjectId: _selectedProjectId,
          selectedUserId: _selectedUserId,
          selectedDate: _selectedDate,
          onFiltersChanged: _onFiltersChanged,
          onClearFilters: _clearFilters,
        ),
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
                return EmptyStateWidget(
                  icon: Icons.voice_over_off,
                  title: "No voice notes found",
                  subtitle: "Voice notes from your team will appear here",
                );
              }

              // Apply client-side filtering
              final filteredNotes = _applyFilters(snap.data!);

              if (filteredNotes.isEmpty) {
                return EmptyStateWidget(
                  icon: Icons.filter_list_off,
                  title: "No notes match your filters",
                  subtitle: "Try adjusting your filter settings",
                  action: ActionButton(
                    label: "Clear Filters",
                    icon: Icons.clear,
                    onPressed: _clearFilters,
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(AppTheme.spacingS),
                itemCount: filteredNotes.length,
                itemBuilder: (context, i) {
                  final note = filteredNotes[i];
                  final isReplying = _replyToId == note['id'];

                  return VoiceNoteCard(
                    note: note,
                    isReplying: isReplying,
                    onReply: () => _handleReply(note),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}