import 'package:flutter/material.dart';
import 'package:houzzdat_app/core/theme/app_theme.dart';
import 'package:houzzdat_app/features/insights/services/review_queue_service.dart';
import 'package:houzzdat_app/features/insights/widgets/review_card.dart';

/// Content for the REVIEW tab inside the Insights screen.
/// Shows AI-created records that need manager confirmation, with domain filters.
class ReviewTabContent extends StatefulWidget {
  final String accountId;
  final VoidCallback? onCountChanged;

  const ReviewTabContent({
    super.key,
    required this.accountId,
    this.onCountChanged,
  });

  @override
  State<ReviewTabContent> createState() => _ReviewTabContentState();
}

class _ReviewTabContentState extends State<ReviewTabContent> {
  final _service = ReviewQueueService();

  List<ReviewItem>? _items;
  bool _loading = true;
  String _activeFilter = 'all'; // 'all', 'material', 'payment', 'progress'

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  Future<void> _loadItems() async {
    setState(() => _loading = true);
    try {
      final domain = _activeFilter == 'all' ? null : _activeFilter;
      final items = await _service.getItemsForReview(
        widget.accountId,
        domain: domain,
      );
      if (mounted) {
        setState(() {
          _items = items;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading review items: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _handleConfirm(ReviewItem item) async {
    try {
      await _service.confirmRecord(item.table, item.id);
      _removeItem(item);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Record confirmed'),
            backgroundColor: AppTheme.successGreen,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error confirming record: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to confirm record'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    }
  }

  Future<void> _handleDismiss(ReviewItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Dismiss Record'),
        content: Text(
          'This will delete "${item.title}" and log it as an AI correction. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.errorRed),
            child: const Text('Dismiss'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _service.dismissRecord(
        item.table,
        item.id,
        voiceNoteId: item.voiceNoteId ?? '',
      );
      _removeItem(item);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Record dismissed'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error dismissing record: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to dismiss record'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    }
  }

  Future<void> _handleMerge(ReviewItem item) async {
    if (item.possibleDuplicateOf == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Merge Duplicate'),
        content: const Text(
          'This will keep the original record and remove this duplicate. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.infoBlue),
            child: const Text('Merge'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _service.mergeRecords(
        item.table,
        item.possibleDuplicateOf!,
        item.id,
        voiceNoteId: item.voiceNoteId ?? '',
      );
      _removeItem(item);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Records merged'),
            backgroundColor: AppTheme.infoBlue,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error merging records: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to merge records'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    }
  }

  void _removeItem(ReviewItem item) {
    setState(() {
      _items?.removeWhere((i) => i.id == item.id);
    });
    widget.onCountChanged?.call();
  }

  void _setFilter(String filter) {
    if (_activeFilter == filter) return;
    setState(() => _activeFilter = filter);
    _loadItems();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Filter chips
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spacingM,
            vertical: AppTheme.spacingS,
          ),
          child: Row(
            children: [
              _buildFilterChip('All', 'all'),
              const SizedBox(width: 8),
              _buildFilterChip('Materials', 'material'),
              const SizedBox(width: 8),
              _buildFilterChip('Payments', 'payment'),
            ],
          ),
        ),

        // Content
        Expanded(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(
                    color: AppTheme.primaryIndigo,
                  ),
                )
              : _items == null || _items!.isEmpty
                  ? _buildEmptyState()
                  : RefreshIndicator(
                      onRefresh: _loadItems,
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(
                          AppTheme.spacingM,
                          0,
                          AppTheme.spacingM,
                          AppTheme.spacingXL,
                        ),
                        itemCount: _items!.length,
                        itemBuilder: (context, index) {
                          final item = _items![index];
                          return ReviewCard(
                            item: item,
                            onConfirm: () => _handleConfirm(item),
                            onDismiss: () => _handleDismiss(item),
                            onMerge: item.isPossibleDuplicate
                                ? () => _handleMerge(item)
                                : null,
                          );
                        },
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String label, String filter) {
    final isActive = _activeFilter == filter;
    return GestureDetector(
      onTap: () => _setFilter(filter),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isActive ? AppTheme.primaryIndigo : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive
                ? AppTheme.primaryIndigo
                : AppTheme.textSecondary.withOpacity(0.3),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isActive ? Colors.white : AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 64,
            color: AppTheme.successGreen.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'All caught up!',
            style: AppTheme.headingMedium.copyWith(
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'No records need review right now.',
            style: AppTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
