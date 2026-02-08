import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:houzzdat_app/core/theme/app_theme.dart';
import 'package:houzzdat_app/core/widgets/shared_widgets.dart';
import 'package:houzzdat_app/core/services/audio_recorder_service.dart';
import 'dart:typed_data';

class UsersManagementTab extends StatefulWidget {
  final String accountId;
  
  const UsersManagementTab({super.key, required this.accountId});

  @override
  State<UsersManagementTab> createState() => _UsersManagementTabState();
}

class _UsersManagementTabState extends State<UsersManagementTab> {
  final _supabase = Supabase.instance.client;
  final _recorderService = AudioRecorderService();
  
  String? _recordingForUserId;

  Stream<List<Map<String, dynamic>>> _getUsersStream() {
    return _supabase
        .from('users')
        .stream(primaryKey: ['id'])
        .eq('account_id', widget.accountId)
        .order('role')
        .order('email');
  }

  Future<void> _handleSendVoiceNote(Map<String, dynamic> user) async {
    final userId = user['id'];
    final projectId = user['current_project_id'];
    
    if (projectId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${user['full_name'] ?? user['email']} is not assigned to a project'),
          backgroundColor: AppTheme.warningOrange,
        ),
      );
      return;
    }

    // Start recording
    if (_recordingForUserId == null) {
      await _recorderService.startRecording();
      setState(() => _recordingForUserId = userId);
    } else if (_recordingForUserId == userId) {
      // Stop recording for this user
      setState(() => _recordingForUserId = null);
      
      final bytes = await _recorderService.stopRecording();
      
      if (bytes != null) {
        await _recorderService.uploadAudio(
          bytes: bytes,
          projectId: projectId,
          userId: _supabase.auth.currentUser!.id,
          accountId: widget.accountId,
          recipientId: userId, // Direct instruction to specific user
        );
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ Voice note sent to ${user['full_name'] ?? user['email']}'),
              backgroundColor: AppTheme.successGreen,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(AppTheme.spacingM),
          color: Colors.white,
          child: Row(
            children: [
              Text(
                'TEAM ROSTER',
                style: AppTheme.headingMedium.copyWith(
                  color: AppTheme.primaryIndigo,
                ),
              ),
            ],
          ),
        ),
        
        // Users List
        Expanded(
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: _getUsersStream(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const LoadingWidget(message: 'Loading team members...');
              }

              if (snapshot.hasError) {
                return ErrorStateWidget(
                  message: snapshot.error.toString(),
                  onRetry: () => setState(() {}),
                );
              }

              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const EmptyStateWidget(
                  icon: Icons.people_rounded,
                  title: 'No team members',
                  subtitle: 'Invite team members to get started',
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(AppTheme.spacingM),
                itemCount: snapshot.data!.length,
                itemBuilder: (context, index) {
                  final user = snapshot.data![index];
                  final isRecording = _recordingForUserId == user['id'];
                  
                  return _UserCard(
                    user: user,
                    isRecording: isRecording,
                    onSendVoiceNote: () => _handleSendVoiceNote(user),
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

class _UserCard extends StatefulWidget {
  final Map<String, dynamic> user;
  final bool isRecording;
  final VoidCallback onSendVoiceNote;

  const _UserCard({
    required this.user,
    required this.isRecording,
    required this.onSendVoiceNote,
  });

  @override
  State<_UserCard> createState() => _UserCardState();
}

class _UserCardState extends State<_UserCard> {
  String? _projectName;

  @override
  void initState() {
    super.initState();
    if (widget.user['current_project_id'] != null) {
      _fetchProjectName();
    }
  }

  Future<void> _fetchProjectName() async {
    try {
      final project = await Supabase.instance.client
          .from('projects')
          .select('name')
          .eq('id', widget.user['current_project_id'])
          .single();
      
      if (mounted) {
        setState(() => _projectName = project['name']);
      }
    } catch (e) {
      debugPrint('Error fetching project: $e');
    }
  }

  Color _getRoleColor(String? role) {
    switch (role?.toLowerCase()) {
      case 'manager':
      case 'admin':
        return AppTheme.infoBlue;
      case 'worker':
        return AppTheme.primaryIndigo;
      default:
        return AppTheme.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final role = widget.user['role'] ?? 'worker';
    final email = widget.user['email'] ?? 'User';
    final fullName = widget.user['full_name']?.toString();
    final displayName = fullName ?? email;
    final roleColor = _getRoleColor(role);

    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spacingM),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusXL),
        border: Border.all(
          color: Colors.black.withValues(alpha:0.05),
        ),
      ),
      child: Column(
        children: [
          // User Info
          Padding(
            padding: const EdgeInsets.all(AppTheme.spacingM),
            child: Row(
              children: [
                // Avatar
                CircleAvatar(
                  radius: 24,
                  backgroundColor: roleColor,
                  child: Text(
                    displayName[0].toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                
                const SizedBox(width: AppTheme.spacingM),
                
                // User Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
                        style: AppTheme.bodyLarge.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (fullName != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          email,
                          style: AppTheme.bodySmall.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          CategoryBadge(
                            text: role.toUpperCase(),
                            color: roleColor,
                          ),
                          if (_projectName != null) ...[
                            const SizedBox(width: AppTheme.spacingS),
                            CategoryBadge(
                              text: _projectName!,
                              color: AppTheme.successGreen,
                              icon: Icons.location_on_rounded,
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Send Voice Note Button
          Container(
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: Colors.grey.shade200,
                  width: 1,
                ),
              ),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: widget.onSendVoiceNote,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(AppTheme.radiusXL),
                  bottomRight: Radius.circular(AppTheme.radiusXL),
                ),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    vertical: AppTheme.spacingM,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        widget.isRecording ? Icons.stop_rounded : Icons.mic_rounded,
                        color: widget.isRecording 
                            ? AppTheme.errorRed 
                            : AppTheme.primaryIndigo,
                        size: 20,
                      ),
                      const SizedBox(width: AppTheme.spacingS),
                      Text(
                        widget.isRecording 
                            ? 'STOP & SEND' 
                            : 'SEND VOICE NOTE',
                        style: AppTheme.bodyMedium.copyWith(
                          fontWeight: FontWeight.bold,
                          color: widget.isRecording 
                              ? AppTheme.errorRed 
                              : AppTheme.primaryIndigo,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}