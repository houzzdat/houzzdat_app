import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:houzzdat_app/models/models.dart';
import 'package:houzzdat_app/repositories/repositories.dart';
import 'package:houzzdat_app/providers/repository_providers.dart';

/// CI-06: Actions state management provider.
///
/// Replaces the 24+ setState() calls in actions_tab.dart and the manual
/// list manipulation in action_card_widget.dart with a reactive state notifier.
///
/// Usage:
/// ```dart
/// final actions = ref.watch(actionsProvider(accountId));
/// ```

/// State for the actions list with pagination support.
class ActionsState {
  final List<ActionItem> items;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final String? error;

  const ActionsState({
    this.items = const [],
    this.isLoading = true,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.error,
  });

  ActionsState copyWith({
    List<ActionItem>? items,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    String? error,
  }) {
    return ActionsState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      error: error,
    );
  }
}

/// Notifier that manages actions state for a given account.
class ActionsNotifier extends StateNotifier<ActionsState> {
  final ActionItemsRepository _repo;
  final String _accountId;
  static const _pageSize = 30;

  ActionsNotifier(this._repo, this._accountId) : super(const ActionsState()) {
    loadActions();
  }

  /// Load the initial page of actions.
  Future<void> loadActions() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final items = await _repo.getByAccount(_accountId, limit: _pageSize);
      state = state.copyWith(
        items: items,
        isLoading: false,
        hasMore: items.length >= _pageSize,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Load the next page of actions.
  Future<void> loadMore() async {
    if (state.isLoadingMore || !state.hasMore) return;
    state = state.copyWith(isLoadingMore: true);
    try {
      final newItems = await _repo.getByAccount(
        _accountId,
        offset: state.items.length,
        limit: _pageSize,
      );
      state = state.copyWith(
        items: [...state.items, ...newItems],
        isLoadingMore: false,
        hasMore: newItems.length >= _pageSize,
      );
    } catch (e) {
      state = state.copyWith(isLoadingMore: false);
    }
  }

  /// Apply a delta update from real-time subscription.
  void handleInsert(Map<String, dynamic> newRecord) {
    final item = ActionItem.fromJson(newRecord);
    state = state.copyWith(items: [item, ...state.items]);
  }

  void handleUpdate(Map<String, dynamic> newRecord) {
    final updated = ActionItem.fromJson(newRecord);
    final index = state.items.indexWhere((a) => a.id == updated.id);
    if (index >= 0) {
      final newList = [...state.items];
      newList[index] = updated;
      state = state.copyWith(items: newList);
    } else if (newRecord['account_id']?.toString() == _accountId) {
      state = state.copyWith(items: [updated, ...state.items]);
    }
  }

  void handleDelete(Map<String, dynamic> oldRecord) {
    final deletedId = oldRecord['id']?.toString();
    if (deletedId != null) {
      state = state.copyWith(
        items: state.items.where((a) => a.id != deletedId).toList(),
      );
    }
  }

  /// Update a single item's status locally (optimistic update).
  void updateItemStatus(String itemId, String newStatus) {
    final index = state.items.indexWhere((a) => a.id == itemId);
    if (index >= 0) {
      final newList = [...state.items];
      newList[index] = newList[index].copyWith(status: newStatus);
      state = state.copyWith(items: newList);
    }
  }

  /// Remove items from the list (after bulk operations).
  void removeItems(Set<String> ids) {
    state = state.copyWith(
      items: state.items.where((a) => !ids.contains(a.id)).toList(),
    );
  }
}

/// Family provider keyed by accountId.
final actionsProvider =
    StateNotifierProvider.family<ActionsNotifier, ActionsState, String>(
  (ref, accountId) {
    final repo = ref.read(actionItemsRepositoryProvider);
    return ActionsNotifier(repo, accountId);
  },
);
