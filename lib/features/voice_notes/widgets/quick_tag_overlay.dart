import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:houzzdat_app/core/theme/app_theme.dart';

/// A lightweight overlay shown after voice note upload.
/// Allows the user to optionally tag the message intent to boost AI accuracy.
/// Auto-dismisses after [autoDismissSeconds] if no selection is made.
class QuickTagOverlay extends StatefulWidget {
  final String voiceNoteId;
  final VoidCallback? onDismissed;
  final int autoDismissSeconds;

  const QuickTagOverlay({
    super.key,
    required this.voiceNoteId,
    this.onDismissed,
    this.autoDismissSeconds = 5,
  });

  /// Shows the quick-tag overlay as a bottom sheet.
  /// Only shows if [quickTagEnabled] is true.
  static void show(
    BuildContext context, {
    required String voiceNoteId,
    required bool quickTagEnabled,
    VoidCallback? onDismissed,
  }) {
    if (!quickTagEnabled) {
      onDismissed?.call();
      return;
    }

    showModalBottomSheet(
      context: context,
      isDismissible: true,
      backgroundColor: Colors.transparent,
      builder: (context) => QuickTagOverlay(
        voiceNoteId: voiceNoteId,
        onDismissed: onDismissed,
      ),
    );
  }

  @override
  State<QuickTagOverlay> createState() => _QuickTagOverlayState();
}

class _QuickTagOverlayState extends State<QuickTagOverlay>
    with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  Timer? _autoDismissTimer;
  bool _saving = false;
  late AnimationController _progressController;

  static const _tags = [
    _TagOption(
      intent: 'material_received',
      label: 'Material Received',
      icon: Icons.inventory_2_outlined,
      color: AppTheme.infoBlue,
    ),
    _TagOption(
      intent: 'payment_made',
      label: 'Payment Made',
      icon: Icons.payments_outlined,
      color: AppTheme.successGreen,
    ),
    _TagOption(
      intent: 'stage_complete',
      label: 'Stage Complete',
      icon: Icons.check_circle_outline,
      color: AppTheme.warningOrange,
    ),
    _TagOption(
      intent: 'general_update',
      label: 'Just an Update',
      icon: Icons.chat_bubble_outline,
      color: AppTheme.textSecondary,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(
      vsync: this,
      duration: Duration(seconds: widget.autoDismissSeconds),
    )..forward();

    _autoDismissTimer = Timer(
      Duration(seconds: widget.autoDismissSeconds),
      _dismiss,
    );
  }

  @override
  void dispose() {
    _autoDismissTimer?.cancel();
    _progressController.dispose();
    super.dispose();
  }

  void _dismiss() {
    if (mounted) {
      Navigator.of(context).pop();
      widget.onDismissed?.call();
    }
  }

  Future<void> _selectTag(String intent) async {
    _autoDismissTimer?.cancel();
    _progressController.stop();

    setState(() => _saving = true);

    try {
      await _supabase
          .from('voice_notes')
          .update({'user_declared_intent': intent})
          .eq('id', widget.voiceNoteId);

      debugPrint('Quick-tag set: $intent for voice note ${widget.voiceNoteId}');
    } catch (e) {
      debugPrint('Error setting quick-tag: $e');
    }

    if (mounted) {
      Navigator.of(context).pop();
      widget.onDismissed?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(AppTheme.spacingM),
      decoration: BoxDecoration(
        color: AppTheme.cardWhite,
        borderRadius: BorderRadius.circular(AppTheme.radiusXL),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Progress bar for auto-dismiss countdown
          ClipRRect(
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppTheme.radiusXL),
            ),
            child: AnimatedBuilder(
              animation: _progressController,
              builder: (context, child) {
                return LinearProgressIndicator(
                  value: 1.0 - _progressController.value,
                  minHeight: 3,
                  backgroundColor: Colors.transparent,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    AppTheme.primaryIndigo.withOpacity(0.3),
                  ),
                );
              },
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppTheme.spacingM, AppTheme.spacingS,
              AppTheme.spacingM, AppTheme.spacingM,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Row(
                  children: [
                    Text(
                      'What was this about?',
                      style: AppTheme.bodyMedium.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: _dismiss,
                      child: Text('Skip', style: AppTheme.bodySmall),
                    ),
                  ],
                ),

                const SizedBox(height: AppTheme.spacingS),

                // Tag chips
                if (_saving)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: AppTheme.spacingM),
                    child: SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppTheme.primaryIndigo,
                      ),
                    ),
                  )
                else
                  Wrap(
                    spacing: AppTheme.spacingS,
                    runSpacing: AppTheme.spacingS,
                    children: _tags
                        .map((tag) => _buildTagChip(tag))
                        .toList(),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTagChip(_TagOption tag) {
    return InkWell(
      onTap: () => _selectTag(tag.intent),
      borderRadius: BorderRadius.circular(AppTheme.radiusL),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacingM,
          vertical: AppTheme.spacingS,
        ),
        decoration: BoxDecoration(
          color: tag.color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(AppTheme.radiusL),
          border: Border.all(color: tag.color.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(tag.icon, size: 18, color: tag.color),
            const SizedBox(width: 6),
            Text(
              tag.label,
              style: AppTheme.bodySmall.copyWith(
                color: tag.color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TagOption {
  final String intent;
  final String label;
  final IconData icon;
  final Color color;

  const _TagOption({
    required this.intent,
    required this.label,
    required this.icon,
    required this.color,
  });
}
