import 'package:flutter/material.dart';
import 'package:houzzdat_app/core/theme/app_theme.dart';
import 'package:houzzdat_app/features/dashboard/widgets/action_card_widget.dart';

/// Updated ActionCardKanban that unifies layout by using ActionCardWidget.
/// Corrects parameter names and makes them optional to solve compilation errors
/// in parent tab files while maintaining new manager lifecycle features.
class ActionCardKanban extends StatelessWidget {
  final Map<String, dynamic> item;
  final VoidCallback onApprove;
  final VoidCallback? onInstruct; 
  final dynamic onForward;
  final Function(String priority)? onUpdatePriority;
  final VoidCallback? onCompleteAndLog;
  final VoidCallback? onViewDetails; 

  const ActionCardKanban({
    super.key,
    required this.item,
    required this.onApprove,
    this.onInstruct,
    this.onForward,
    this.onUpdatePriority,
    this.onCompleteAndLog,
    this.onViewDetails,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 320, // Standard Kanban column width
      margin: const EdgeInsets.only(bottom: AppTheme.spacingM),
      child: ActionCardWidget(
        item: item,
        onApprove: onApprove,
        onInstruct: onInstruct ?? () {},
        onForward: onForward ?? () {},
        onUpdatePriority: onUpdatePriority,
        onCompleteAndLog: onCompleteAndLog,
      ),
    );
  }
}