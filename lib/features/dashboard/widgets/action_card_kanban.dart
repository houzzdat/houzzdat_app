import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:houzzdat_app/core/theme/app_theme.dart';
import 'package:houzzdat_app/core/widgets/shared_widgets.dart';
import 'package:timeago/timeago.dart' as timeago;

class ActionCardKanban extends StatefulWidget {
  final Map<String, dynamic> item;
  final VoidCallback onApprove;
  final VoidCallback onViewDetails;

  const ActionCardKanban({
    super.key,
    required this.item,
    required this.onApprove,
    required this.onViewDetails,
  });

  @override
  State<ActionCardKanban> createState() => _ActionCardKanbanState();
}

class _ActionCardKanbanState extends State<ActionCardKanban> {
  final _supabase = Supabase.instance.client;
  Map<String, dynamic>? _voiceNote;
  Map<String, dynamic>? _user;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCardData();
  }

  Future<void> _loadCardData() async {
    try {
      // Fetch voice note
      if (widget.item['voice_note_id'] != null) {
        _voiceNote = await _supabase
            .from('voice_notes')
            .select('status, user_id, audio_url')
            .eq('id', widget.item['voice_note_id'])
            .single();
        
        // Fetch user details
        if (_voiceNote != null && _voiceNote!['user_id'] != null) {
          _user = await _supabase
              .from('users')
              .select('email')
              .eq('id', _voiceNote!['user_id'])
              .single();
        }
      }
    } catch (e) {
      debugPrint('Error loading card data: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Color _getPriorityColor() {
    final priority = widget.item['priority']?.toString().toLowerCase() ?? 'med';
    switch (priority) {
      case 'high':
        return AppTheme.errorRed;
      case 'low':
        return AppTheme.successGreen;
      default:
        return AppTheme.warningOrange;
    }
  }

  String _getRelativeTime() {
    try {
      final createdAt = DateTime.parse(widget.item['created_at']);
      return timeago.format(createdAt, locale: 'en_short');
    } catch (e) {
      return 'Just now';
    }
  }

  bool _isProcessing() {
    return _voiceNote?['status'] == 'processing';
  }

  @override
  Widget build(BuildContext context) {
    final isProcessing = _isProcessing();
    final priority = widget.item['priority']?.toString() ?? 'Med';
    final summary = widget.item['summary'] ?? 'Action Item';
    final status = widget.item['status'] ?? 'pending';

    return Opacity(
      opacity: isProcessing ? 0.7 : 1.0,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppTheme.spacingM),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppTheme.radiusXL),
          border: Border.all(
            color: Colors.black.withOpacity(0.05),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Processing Banner
            if (isProcessing)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  vertical: AppTheme.spacingS,
                  horizontal: AppTheme.spacingM,
                ),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(AppTheme.radiusXL),
                    topRight: Radius.circular(AppTheme.radiusXL),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _PulsingDot(),
                    const SizedBox(width: AppTheme.spacingS),
                    Text(
                      'AI PROCESSING...',
                      style: AppTheme.caption.copyWith(
                        color: AppTheme.infoBlue,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

            // Card Content
            Padding(
              padding: const EdgeInsets.all(AppTheme.spacingM),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header: Priority & Timestamp
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      CategoryBadge(
                        text: priority.toUpperCase(),
                        color: _getPriorityColor(),
                      ),
                      Text(
                        _getRelativeTime(),
                        style: AppTheme.caption.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: AppTheme.spacingM),
                  
                  // Body: Title & User Info
                  Text(
                    summary,
                    style: AppTheme.bodyLarge.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  
                  if (!_isLoading && _user != null) ...[
                    const SizedBox(height: AppTheme.spacingM),
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: AppTheme.primaryIndigo,
                          child: Text(
                            (_user!['email'] ?? 'U')[0].toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppTheme.spacingS),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _user!['email'] ?? 'Unknown',
                                style: AppTheme.bodySmall.copyWith(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              if (_voiceNote?['audio_url'] != null)
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.mic_rounded,
                                      size: 12,
                                      color: AppTheme.textSecondary,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Voice note',
                                      style: AppTheme.caption.copyWith(
                                        color: AppTheme.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            // Footer Buttons
            Container(
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: Colors.grey.shade200,
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: widget.onViewDetails,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          vertical: AppTheme.spacingM,
                        ),
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.only(
                            bottomLeft: Radius.circular(AppTheme.radiusXL),
                          ),
                        ),
                      ),
                      child: Text(
                        'DETAILS',
                        style: AppTheme.bodySmall.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryIndigo,
                        ),
                      ),
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 48,
                    color: Colors.grey.shade200,
                  ),
                  Expanded(
                    child: TextButton(
                      onPressed: isProcessing || status != 'pending' 
                          ? null 
                          : widget.onApprove,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          vertical: AppTheme.spacingM,
                        ),
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.only(
                            bottomRight: Radius.circular(AppTheme.radiusXL),
                          ),
                        ),
                      ),
                      child: Text(
                        status == 'approved' || status == 'in_progress' 
                            ? 'LOG' 
                            : 'APPROVE',
                        style: AppTheme.bodySmall.copyWith(
                          fontWeight: FontWeight.bold,
                          color: isProcessing || status != 'pending'
                              ? AppTheme.textSecondary
                              : AppTheme.successGreen,
                        ),
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

class _PulsingDot extends StatefulWidget {
  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _controller,
      child: Container(
        width: 8,
        height: 8,
        decoration: const BoxDecoration(
          color: AppTheme.infoBlue,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}