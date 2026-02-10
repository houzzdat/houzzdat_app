import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:houzzdat_app/core/theme/app_theme.dart';
import 'package:houzzdat_app/core/widgets/shared_widgets.dart';
import 'package:houzzdat_app/core/services/audio_recorder_service.dart';
import 'package:houzzdat_app/features/voice_notes/widgets/voice_note_card.dart';

class OwnerMessagesTab extends StatefulWidget {
  final String ownerId;
  final String accountId;

  const OwnerMessagesTab({
    super.key,
    required this.ownerId,
    required this.accountId,
  });

  @override
  State<OwnerMessagesTab> createState() => _OwnerMessagesTabState();
}

class _OwnerMessagesTabState extends State<OwnerMessagesTab> {
  final _supabase = Supabase.instance.client;
  final _audioService = AudioRecorderService();
  bool _isRecording = false;
  String? _selectedProjectId;
  String? _selectedManagerId;
  List<Map<String, dynamic>> _ownerProjects = [];

  @override
  void initState() {
    super.initState();
    _loadOwnerProjects();
  }

  Future<void> _loadOwnerProjects() async {
    try {
      final result = await _supabase
          .from('project_owners')
          .select('project_id, projects(id, name, account_id)')
          .eq('owner_id', widget.ownerId);

      final projects = <Map<String, dynamic>>[];
      for (final row in result) {
        if (row['projects'] != null) {
          projects.add(row['projects'] as Map<String, dynamic>);
        }
      }

      if (mounted) {
        setState(() {
          _ownerProjects = projects;
          if (projects.isNotEmpty) {
            _selectedProjectId = projects.first['id'];
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading owner projects: $e');
    }
  }

  Future<void> _handleRecording() async {
    if (_isRecording) {
      // Stop recording
      setState(() => _isRecording = false);
      final bytes = await _audioService.stopRecording();
      if (bytes == null) return;

      // Determine recipient (manager of the selected project)
      String? managerId = _selectedManagerId;
      if (managerId == null && _selectedProjectId != null) {
        try {
          final project = _ownerProjects.firstWhere(
            (p) => p['id'] == _selectedProjectId,
            orElse: () => <String, dynamic>{},
          );
          if (project.isNotEmpty) {
            final account = await _supabase
                .from('accounts')
                .select('admin_id')
                .eq('id', project['account_id'])
                .maybeSingle();
            managerId = account?['admin_id'];
          }
        } catch (e) {
          debugPrint('Error finding manager: $e');
        }
      }

      try {
        await _audioService.uploadAudio(
          bytes: bytes,
          projectId: _selectedProjectId ?? '',
          userId: widget.ownerId,
          accountId: widget.accountId,
          recipientId: managerId,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Voice note sent to manager'),
              backgroundColor: AppTheme.successGreen,
            ),
          );
        }
      } catch (e) {
        debugPrint('Error uploading voice note: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not send voice note. Please check your connection and try again.'),
              backgroundColor: AppTheme.errorRed,
            ),
          );
        }
      }
    } else {
      // Start recording
      final hasPermission = await _audioService.checkPermission();
      if (!hasPermission) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Microphone permission required'),
              backgroundColor: AppTheme.errorRed,
            ),
          );
        }
        return;
      }
      await _audioService.startRecording();
      setState(() => _isRecording = true);
    }
  }

  Stream<List<Map<String, dynamic>>> _buildMessageStream() {
    // Get project IDs for this owner
    final projectIds = _ownerProjects.map((p) => p['id'] as String).toList();
    if (projectIds.isEmpty) return const Stream.empty();

    // Stream voice notes that involve this owner
    return _supabase
        .from('voice_notes')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .map((notes) {
      return notes.where((note) {
        final isRecipient = note['recipient_id'] == widget.ownerId;
        final isSender = note['user_id'] == widget.ownerId;
        final isInOwnerProject = projectIds.contains(note['project_id']);
        return (isRecipient || isSender) && isInOwnerProject;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Project selector
        if (_ownerProjects.length > 1)
          Padding(
            padding: const EdgeInsets.all(AppTheme.spacingM),
            child: DropdownButtonFormField<String>(
              value: _selectedProjectId,
              decoration: const InputDecoration(
                labelText: 'Project',
                prefixIcon: Icon(Icons.business),
              ),
              items: _ownerProjects.map((p) {
                return DropdownMenuItem(
                  value: p['id'] as String,
                  child: Text(p['name'] ?? 'Project'),
                );
              }).toList(),
              onChanged: (value) => setState(() => _selectedProjectId = value),
            ),
          ),

        // Messages list
        Expanded(
          child: _ownerProjects.isEmpty
              ? const EmptyStateWidget(
                  icon: Icons.message_outlined,
                  title: 'No Messages',
                  subtitle: 'No projects linked yet. Messages will appear here.',
                )
              : StreamBuilder<List<Map<String, dynamic>>>(
                  stream: _buildMessageStream(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const LoadingWidget(message: 'Loading messages...');
                    }

                    final notes = snapshot.data ?? [];

                    if (notes.isEmpty) {
                      return const EmptyStateWidget(
                        icon: Icons.message_outlined,
                        title: 'No Messages Yet',
                        subtitle: 'Record a voice note to start a conversation with your manager.',
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.only(bottom: 100),
                      itemCount: notes.length,
                      itemBuilder: (context, index) {
                        return VoiceNoteCard(
                          note: notes[index],
                          isReplying: false,
                          onReply: () {},
                        );
                      },
                    );
                  },
                ),
        ),

        // Recording bar
        Container(
          padding: const EdgeInsets.all(AppTheme.spacingM),
          decoration: BoxDecoration(
            color: AppTheme.cardWhite,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha:0.1),
                blurRadius: 4,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: SafeArea(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_isRecording)
                  Expanded(
                    child: Text(
                      'Recording... Tap mic to stop and send',
                      style: AppTheme.bodyMedium.copyWith(color: AppTheme.errorRed),
                      textAlign: TextAlign.center,
                    ),
                  ),
                GestureDetector(
                  onTap: _handleRecording,
                  child: CircleAvatar(
                    radius: 28,
                    backgroundColor: _isRecording ? AppTheme.errorRed : AppTheme.primaryIndigo,
                    child: Icon(
                      _isRecording ? Icons.stop : Icons.mic,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
