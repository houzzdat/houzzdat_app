import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:houzzdat_app/models/models.dart';

/// CI-06: Filter state management provider.
///
/// Replaces the filter-related setState() calls scattered across
/// actions_tab.dart and feed_tab.dart. Persists filter state
/// across tab switches (solves TL-06).

/// Immutable filter state.
class FilterState {
  final String category;
  final String sortBy;
  final String searchQuery;
  final String? projectId;
  final DateTimeRange? dateRange;
  final double minConfidence;

  const FilterState({
    this.category = 'all',
    this.sortBy = 'newest',
    this.searchQuery = '',
    this.projectId,
    this.dateRange,
    this.minConfidence = 0.0,
  });

  bool get hasActiveFilters =>
      category != 'all' ||
      searchQuery.isNotEmpty ||
      projectId != null ||
      dateRange != null ||
      minConfidence > 0.0;

  FilterState copyWith({
    String? category,
    String? sortBy,
    String? searchQuery,
    String? projectId,
    DateTimeRange? dateRange,
    double? minConfidence,
    bool clearProjectId = false,
    bool clearDateRange = false,
  }) {
    return FilterState(
      category: category ?? this.category,
      sortBy: sortBy ?? this.sortBy,
      searchQuery: searchQuery ?? this.searchQuery,
      projectId: clearProjectId ? null : (projectId ?? this.projectId),
      dateRange: clearDateRange ? null : (dateRange ?? this.dateRange),
      minConfidence: minConfidence ?? this.minConfidence,
    );
  }

  /// Apply filters to a list of action items.
  List<ActionItem> apply(List<ActionItem> items) {
    var result = items.where((action) {
      // Category filter
      final bool categoryMatch;
      if (category == 'needs_review') {
        categoryMatch = action.needsReview;
      } else {
        categoryMatch = category == 'all' || action.category == category;
      }

      // Search filter
      bool searchMatch = true;
      if (searchQuery.isNotEmpty) {
        final query = searchQuery.toLowerCase();
        final summary = (action.summary ?? '').toLowerCase();
        searchMatch = summary.contains(query);
      }

      // Project filter
      bool projectMatch = true;
      if (projectId != null) {
        projectMatch = action.projectId == projectId;
      }

      // Date range filter
      bool dateMatch = true;
      if (dateRange != null && action.createdAt != null) {
        dateMatch = action.createdAt!.isAfter(dateRange!.start) &&
            action.createdAt!.isBefore(dateRange!.end.add(const Duration(days: 1)));
      }

      // Confidence filter
      bool confMatch = true;
      if (minConfidence > 0.0) {
        confMatch = (action.confidenceScore ?? 1.0) >= minConfidence;
      }

      return categoryMatch && searchMatch && projectMatch && dateMatch && confMatch;
    }).toList();

    // Sort
    switch (sortBy) {
      case 'oldest':
        result.sort((a, b) => (a.createdAt ?? DateTime(2000)).compareTo(b.createdAt ?? DateTime(2000)));
        break;
      case 'priority':
        const priorityOrder = {'critical': 0, 'high': 1, 'medium': 2, 'low': 3};
        result.sort((a, b) {
          final pa = priorityOrder[a.priority] ?? 4;
          final pb = priorityOrder[b.priority] ?? 4;
          return pa.compareTo(pb);
        });
        break;
      case 'newest':
      default:
        result.sort((a, b) => (b.createdAt ?? DateTime(2000)).compareTo(a.createdAt ?? DateTime(2000)));
        break;
    }

    return result;
  }

  FilterState reset() => const FilterState();
}

/// Filter state notifier.
class FilterNotifier extends StateNotifier<FilterState> {
  FilterNotifier() : super(const FilterState());

  void setCategory(String category) => state = state.copyWith(category: category);
  void setSortBy(String sortBy) => state = state.copyWith(sortBy: sortBy);
  void setSearchQuery(String query) => state = state.copyWith(searchQuery: query);
  void setProjectId(String? projectId) => state = state.copyWith(
    projectId: projectId,
    clearProjectId: projectId == null,
  );
  void setDateRange(DateTimeRange? range) => state = state.copyWith(
    dateRange: range,
    clearDateRange: range == null,
  );
  void setMinConfidence(double confidence) => state = state.copyWith(minConfidence: confidence);
  void reset() => state = state.reset();
}

/// Family provider keyed by context (e.g. accountId or tab name).
final filterProvider =
    StateNotifierProvider.family<FilterNotifier, FilterState, String>(
  (ref, key) => FilterNotifier(),
);
