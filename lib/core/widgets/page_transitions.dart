import 'package:flutter/material.dart';

/// UX-audit #23: Custom page route with fade+slide transition.
/// Replaces default MaterialPageRoute instant-slide for smoother navigation.
///
/// Usage:
///   Navigator.push(context, FadeSlideRoute(page: DetailScreen()));
class FadeSlideRoute<T> extends PageRouteBuilder<T> {
  final Widget page;

  FadeSlideRoute({required this.page})
      : super(
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionDuration: const Duration(milliseconds: 300),
          reverseTransitionDuration: const Duration(milliseconds: 250),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final curved = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
              reverseCurve: Curves.easeInCubic,
            );
            return FadeTransition(
              opacity: curved,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0.05, 0),
                  end: Offset.zero,
                ).animate(curved),
                child: child,
              ),
            );
          },
        );
}

/// Searchable dropdown widget for project/site selectors.
/// UX-audit #14: Replaces DropdownButton with searchable overlay for 10+ items.
class SearchableDropdown<T> extends StatefulWidget {
  final List<SearchableDropdownItem<T>> items;
  final T? value;
  final String label;
  final String? hint;
  final ValueChanged<T?> onChanged;
  final String? Function(T?)? validator;

  const SearchableDropdown({
    super.key,
    required this.items,
    required this.onChanged,
    required this.label,
    this.value,
    this.hint,
    this.validator,
  });

  @override
  State<SearchableDropdown<T>> createState() => _SearchableDropdownState<T>();
}

class SearchableDropdownItem<T> {
  final T value;
  final String label;

  const SearchableDropdownItem({required this.value, required this.label});
}

class _SearchableDropdownState<T> extends State<SearchableDropdown<T>> {
  String? _errorText;

  String? _selectedLabel() {
    if (widget.value == null) return null;
    try {
      return widget.items
          .firstWhere((i) => i.value == widget.value)
          .label;
    } catch (_) {
      return null;
    }
  }

  Future<void> _showSearch() async {
    final result = await showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _SearchableDropdownSheet<T>(
        items: widget.items,
        selectedValue: widget.value,
        title: widget.label,
      ),
    );

    if (result != null || widget.value != null) {
      widget.onChanged(result);
      if (widget.validator != null) {
        setState(() => _errorText = widget.validator!(result));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final label = _selectedLabel();

    return FormField<T>(
      initialValue: widget.value,
      validator: (_) {
        final err = widget.validator?.call(widget.value);
        setState(() => _errorText = err);
        return err;
      },
      builder: (field) {
        return InkWell(
          onTap: _showSearch,
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: widget.label,
              errorText: _errorText ?? field.errorText,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              suffixIcon: const Icon(Icons.search, size: 20),
            ),
            child: Text(
              label ?? widget.hint ?? 'Select...',
              style: TextStyle(
                color: label != null ? Colors.black87 : Colors.grey,
                fontSize: 16,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SearchableDropdownSheet<T> extends StatefulWidget {
  final List<SearchableDropdownItem<T>> items;
  final T? selectedValue;
  final String title;

  const _SearchableDropdownSheet({
    required this.items,
    required this.title,
    this.selectedValue,
  });

  @override
  State<_SearchableDropdownSheet<T>> createState() =>
      _SearchableDropdownSheetState<T>();
}

class _SearchableDropdownSheetState<T>
    extends State<_SearchableDropdownSheet<T>> {
  final _searchController = TextEditingController();
  List<SearchableDropdownItem<T>> _filtered = [];

  @override
  void initState() {
    super.initState();
    _filtered = widget.items;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearch(String query) {
    setState(() {
      if (query.isEmpty) {
        _filtered = widget.items;
      } else {
        _filtered = widget.items
            .where((i) => i.label.toLowerCase().contains(query.toLowerCase()))
            .toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Column(
        children: [
          // Handle
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              widget.title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 12),

          // Search field
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchController,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Search...',
                prefixIcon: const Icon(Icons.search, size: 20),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 8,
                ),
              ),
              onChanged: _onSearch,
            ),
          ),
          const SizedBox(height: 8),

          // Results list
          Expanded(
            child: _filtered.isEmpty
                ? const Center(
                    child: Text('No results', style: TextStyle(color: Colors.grey)),
                  )
                : ListView.builder(
                    itemCount: _filtered.length,
                    itemBuilder: (context, i) {
                      final item = _filtered[i];
                      final isSelected = item.value == widget.selectedValue;

                      return ListTile(
                        title: Text(item.label),
                        trailing: isSelected
                            ? const Icon(Icons.check, color: Color(0xFF1A237E))
                            : null,
                        selected: isSelected,
                        onTap: () => Navigator.pop(context, item.value),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
