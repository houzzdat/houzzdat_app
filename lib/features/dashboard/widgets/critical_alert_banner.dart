import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:houzzdat_app/core/theme/app_theme.dart';
import 'package:houzzdat_app/features/dashboard/widgets/instruct_voice_dialog.dart';

/// Persistent red gradient banner for critical/safety items.
/// Shows max 3 items stacked with "+N more" overflow.
/// Returns SizedBox.shrink() when no critical items exist.
class CriticalAlertBanner extends StatefulWidget {
  final String accountId;
  final VoidCallback? onViewActions;

  const CriticalAlertBanner({
    super.key,
    required this.accountId,
    this.onViewActions,
  });

  @override
  State<CriticalAlertBanner> createState() => _CriticalAlertBannerState();
}

class _CriticalAlertBannerState extends State<CriticalAlertBanner> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _criticalItems = [];

  @override
  void initState() {
    super.initState();
    _loadCriticalItems();
    _subscribeToChanges();
  }

  void _subscribeToChanges() {
    _supabase
        .channel('critical_alert_changes')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'action_items',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'account_id',
            value: widget.accountId,
          ),
          callback: (payload) => _loadCriticalItems(),
        )
        .subscribe();
  }

  Future<void> _loadCriticalItems() async {
    try {
      final data = await _supabase
          .from('action_items')
          .select('id, summary, priority, user_id, project_id, account_id, voice_note_id, category, status')
          .eq('account_id', widget.accountId)
          .eq('is_critical_flag', true)
          .eq('status', 'pending')
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _criticalItems = (data as List)
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        });
      }
    } catch (e) {
      debugPrint('Error loading critical items: $e');
    }
  }

  void _handleInstructNow(Map<String, dynamic> item) {
    Navigator.push(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => InstructVoiceDialog(actionItem: item),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_criticalItems.isEmpty) return const SizedBox.shrink();

    final displayItems = _criticalItems.take(3).toList();
    final overflowCount = _criticalItems.length - 3;

    return Column(
      children: [
        ...displayItems.map((item) => _buildBannerItem(item)),
        if (overflowCount > 0)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFB71C1C), Color(0xFF880E0E)],
              ),
            ),
            child: Text(
              '+$overflowCount more critical alert${overflowCount > 1 ? 's' : ''}',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ),
      ],
    );
  }

  Widget _buildBannerItem(Map<String, dynamic> item) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 72),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFD32F2F), Color(0xFFB71C1C)],
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_rounded, color: Colors.white, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'CRITICAL ALERT',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item['summary'] ?? 'Critical safety issue detected',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // VIEW button
          OutlinedButton(
            onPressed: widget.onViewActions,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Colors.white70),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('VIEW', style: TextStyle(fontSize: 11)),
          ),
          const SizedBox(width: 6),
          // INSTRUCT NOW button
          ElevatedButton(
            onPressed: () => _handleInstructNow(item),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: AppTheme.errorRed,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('INSTRUCT', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _supabase.removeChannel(_supabase.channel('critical_alert_changes'));
    super.dispose();
  }
}
