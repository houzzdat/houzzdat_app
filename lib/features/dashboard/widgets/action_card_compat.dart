import 'package:flutter/material.dart';
import 'package:houzzdat_app/features/dashboard/widgets/action_card_widget.dart';

/// Backward-compatible wrapper
class ActionCardCompat extends StatelessWidget {
  final Map<String, dynamic> item;
  final VoidCallback onApprove;
  final VoidCallback? onInstruct;
  final dynamic onForward;
  final Function(String priority)? onUpdatePriority;
  final VoidCallback? onCompleteAndLog;
  final VoidCallback? onViewDetails;
  final VoidCallback? onRefresh;

  const ActionCardCompat({
    super.key,
    required this.item,
    required this.onApprove,
    this.onInstruct,
    this.onForward,
    this.onUpdatePriority,
    this.onCompleteAndLog,
    this.onViewDetails,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return ActionCardWidget(
      item: item,
      onRefresh: onRefresh ?? () {},
    );
  }
}