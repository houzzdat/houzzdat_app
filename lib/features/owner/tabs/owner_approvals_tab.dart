import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:houzzdat_app/core/theme/app_theme.dart';
import 'package:houzzdat_app/core/widgets/shared_widgets.dart';
import 'package:houzzdat_app/features/owner/widgets/owner_approval_card.dart';

class OwnerApprovalsTab extends StatefulWidget {
  final String ownerId;
  final String accountId;
  final VoidCallback? onApprovalChanged;

  const OwnerApprovalsTab({
    super.key,
    required this.ownerId,
    required this.accountId,
    this.onApprovalChanged,
  });

  @override
  State<OwnerApprovalsTab> createState() => _OwnerApprovalsTabState();
}

class _OwnerApprovalsTabState extends State<OwnerApprovalsTab> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _approvals = [];
  bool _isLoading = true;
  String _filterStatus = 'all';

  @override
  void initState() {
    super.initState();
    _loadApprovals();
  }

  Future<void> _loadApprovals() async {
    setState(() => _isLoading = true);

    try {
      var query = _supabase
          .from('owner_approvals')
          .select('*, projects(name)')
          .eq('owner_id', widget.ownerId)
          .order('created_at', ascending: false);

      final result = await query;

      // Enrich with requester name
      final enriched = <Map<String, dynamic>>[];
      for (final approval in result) {
        final map = Map<String, dynamic>.from(approval);
        map['project_name'] = map['projects']?['name'] ?? '';

        // Get requester name
        if (map['requested_by'] != null) {
          try {
            final user = await _supabase
                .from('users')
                .select('full_name, email')
                .eq('id', map['requested_by'])
                .maybeSingle();
            map['requested_by_name'] = user?['full_name'] ?? user?['email'] ?? 'Unknown';
          } catch (_) {
            map['requested_by_name'] = 'Unknown';
          }
        }
        enriched.add(map);
      }

      if (mounted) {
        setState(() {
          _approvals = enriched;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading approvals: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> get _filteredApprovals {
    if (_filterStatus == 'all') return _approvals;
    return _approvals.where((a) => a['status'] == _filterStatus).toList();
  }

  Future<void> _handleApprove(Map<String, dynamic> approval) async {
    final response = await _showResponseDialog('Approve this request?', 'Optional note for approval');
    if (response == null) return;

    try {
      await _supabase.from('owner_approvals').update({
        'status': 'approved',
        'owner_response': response.isNotEmpty ? response : null,
        'responded_at': DateTime.now().toIso8601String(),
      }).eq('id', approval['id']);

      // Update linked action_item interaction_history if exists
      if (approval['action_item_id'] != null) {
        await _recordActionItemInteraction(
          approval['action_item_id'],
          'owner_approved',
          'Owner approved: ${approval['title']}${response.isNotEmpty ? " - $response" : ""}',
        );
      }

      _loadApprovals();
      widget.onApprovalChanged?.call();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Request approved'),
            backgroundColor: AppTheme.successGreen,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error approving: $e');
    }
  }

  Future<void> _handleDeny(Map<String, dynamic> approval) async {
    final reason = await _showResponseDialog('Deny this request?', 'Reason for denial');
    if (reason == null) return;

    try {
      await _supabase.from('owner_approvals').update({
        'status': 'denied',
        'owner_response': reason.isNotEmpty ? reason : 'Denied by owner',
        'responded_at': DateTime.now().toIso8601String(),
      }).eq('id', approval['id']);

      if (approval['action_item_id'] != null) {
        await _recordActionItemInteraction(
          approval['action_item_id'],
          'owner_denied',
          'Owner denied: ${approval['title']}${reason.isNotEmpty ? " - $reason" : ""}',
        );
      }

      _loadApprovals();
      widget.onApprovalChanged?.call();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Request denied'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error denying: $e');
    }
  }

  Future<void> _handleAddNote(Map<String, dynamic> approval) async {
    final note = await _showResponseDialog('Add a note', 'Your note');
    if (note == null || note.isEmpty) return;

    try {
      final existingResponse = approval['owner_response'] ?? '';
      final updatedResponse = existingResponse.isNotEmpty
          ? '$existingResponse\n---\n$note'
          : note;

      await _supabase.from('owner_approvals').update({
        'owner_response': updatedResponse,
      }).eq('id', approval['id']);

      _loadApprovals();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Note added'),
            backgroundColor: AppTheme.infoBlue,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error adding note: $e');
    }
  }

  Future<void> _recordActionItemInteraction(
    String actionItemId,
    String action,
    String details,
  ) async {
    try {
      final result = await _supabase
          .from('action_items')
          .select('interaction_history')
          .eq('id', actionItemId)
          .maybeSingle();

      if (result == null) return;

      final history = List<Map<String, dynamic>>.from(
        (result['interaction_history'] as List?) ?? [],
      );

      history.add({
        'timestamp': DateTime.now().toIso8601String(),
        'user_id': widget.ownerId,
        'action': action,
        'details': details,
      });

      await _supabase.from('action_items').update({
        'interaction_history': history,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', actionItemId);
    } catch (e) {
      debugPrint('Error recording interaction: $e');
    }
  }

  Future<String?> _showResponseDialog(String title, String hint) async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(hintText: hint),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryIndigo),
            child: const Text('Confirm', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const LoadingWidget(message: 'Loading approvals...');
    }

    return Column(
      children: [
        // Filter chips
        Padding(
          padding: const EdgeInsets.all(AppTheme.spacingM),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _FilterChip(label: 'All', value: 'all', selected: _filterStatus, onSelected: (v) => setState(() => _filterStatus = v)),
                const SizedBox(width: AppTheme.spacingS),
                _FilterChip(label: 'Pending', value: 'pending', selected: _filterStatus, onSelected: (v) => setState(() => _filterStatus = v)),
                const SizedBox(width: AppTheme.spacingS),
                _FilterChip(label: 'Approved', value: 'approved', selected: _filterStatus, onSelected: (v) => setState(() => _filterStatus = v)),
                const SizedBox(width: AppTheme.spacingS),
                _FilterChip(label: 'Denied', value: 'denied', selected: _filterStatus, onSelected: (v) => setState(() => _filterStatus = v)),
              ],
            ),
          ),
        ),
        Expanded(
          child: _filteredApprovals.isEmpty
              ? const EmptyStateWidget(
                  icon: Icons.approval_outlined,
                  title: 'No Approvals',
                  subtitle: 'No approval requests to show.',
                )
              : RefreshIndicator(
                  onRefresh: _loadApprovals,
                  child: ListView.builder(
                    padding: const EdgeInsets.only(bottom: AppTheme.spacingXL),
                    itemCount: _filteredApprovals.length,
                    itemBuilder: (context, index) {
                      final approval = _filteredApprovals[index];
                      return OwnerApprovalCard(
                        approval: approval,
                        onApprove: () => _handleApprove(approval),
                        onDeny: () => _handleDeny(approval),
                        onAddNote: () => _handleAddNote(approval),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final String value;
  final String selected;
  final ValueChanged<String> onSelected;

  const _FilterChip({
    required this.label,
    required this.value,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = value == selected;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onSelected(value),
      selectedColor: AppTheme.primaryIndigo.withValues(alpha:0.2),
      checkmarkColor: AppTheme.primaryIndigo,
      labelStyle: TextStyle(
        color: isSelected ? AppTheme.primaryIndigo : AppTheme.textSecondary,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }
}
