import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:houzzdat_app/core/theme/app_theme.dart';

class FeedFiltersWidget extends StatelessWidget {
  final String accountId;
  final String? selectedProjectId;
  final String? selectedUserId;
  final DateTime? selectedDate;
  final Function({String? projectId, String? userId, DateTime? date}) onFiltersChanged;
  final VoidCallback onClearFilters;

  const FeedFiltersWidget({
    super.key,
    required this.accountId,
    required this.selectedProjectId,
    required this.selectedUserId,
    required this.selectedDate,
    required this.onFiltersChanged,
    required this.onClearFilters,
  });

  @override
  Widget build(BuildContext context) {
    final supabase = Supabase.instance.client;
    final hasActiveFilters = selectedProjectId != null || 
                            selectedUserId != null || 
                            selectedDate != null;

    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingM),
      color: AppTheme.cardWhite,
      child: Column(
        children: [
          // Dropdowns Row
          Row(
            children: [
              // Project Filter
              Expanded(
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: supabase
                      .from('projects')
                      .select()
                      .eq('account_id', accountId),
                  builder: (context, snap) {
                    if (!snap.hasData) {
                      return const SizedBox(
                        height: 48,
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }

                    return DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: "Filter by Site",
                        prefixIcon: Icon(Icons.business, size: 20),
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: AppTheme.spacingM,
                          vertical: AppTheme.spacingS,
                        ),
                      ),
                      value: selectedProjectId,
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text("All Sites"),
                        ),
                        ...snap.data!.map((p) => DropdownMenuItem(
                              value: p['id'].toString(),
                              child: Text(
                                p['name'],
                                overflow: TextOverflow.ellipsis,
                              ),
                            )),
                      ],
                      onChanged: (val) => onFiltersChanged(
                        projectId: val,
                        userId: selectedUserId,
                        date: selectedDate,
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: AppTheme.spacingM),
              // User Filter
              Expanded(
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: supabase
                      .from('users')
                      .select()
                      .eq('account_id', accountId),
                  builder: (context, snap) {
                    if (!snap.hasData) {
                      return const SizedBox(
                        height: 48,
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }

                    return DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: "Filter by User",
                        prefixIcon: Icon(Icons.person, size: 20),
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: AppTheme.spacingM,
                          vertical: AppTheme.spacingS,
                        ),
                      ),
                      value: selectedUserId,
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text("All Users"),
                        ),
                        ...snap.data!.map((u) => DropdownMenuItem(
                              value: u['id'].toString(),
                              child: Text(
                                u['email'] ?? 'User',
                                overflow: TextOverflow.ellipsis,
                              ),
                            )),
                      ],
                      onChanged: (val) => onFiltersChanged(
                        projectId: selectedProjectId,
                        userId: val,
                        date: selectedDate,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingM),
          // Date and Clear Filters Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Date Filter Chip
              ActionChip(
                avatar: const Icon(Icons.calendar_today, size: 16),
                label: Text(
                  selectedDate == null
                      ? "All Dates"
                      : DateFormat('yMMMd').format(selectedDate!),
                ),
                onPressed: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: selectedDate ?? DateTime.now(),
                    firstDate: DateTime(2024),
                    lastDate: DateTime.now(),
                  );
                  if (date != null) {
                    onFiltersChanged(
                      projectId: selectedProjectId,
                      userId: selectedUserId,
                      date: date,
                    );
                  }
                },
              ),
              // Clear Filters Button
              if (hasActiveFilters)
                TextButton.icon(
                  icon: const Icon(Icons.clear, size: 18),
                  label: const Text("Clear Filters"),
                  onPressed: onClearFilters,
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.errorRed,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}