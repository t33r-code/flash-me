import 'package:flutter/material.dart';
import 'package:flash_me/utils/languages.dart';

// Sentinel returned when the user picks "Not set" — lets us distinguish
// an explicit clear from a sheet dismissal (which returns null).
const _kClear = '__clear__';

// Tappable field that opens a searchable bottom sheet for selecting a language.
// value is an ISO 639-1 code (e.g. 'es') or null for "not set".
class LanguagePicker extends StatelessWidget {
  final String? value;
  final ValueChanged<String?> onChanged;
  final String label;
  final bool enabled;

  const LanguagePicker({
    super.key,
    required this.value,
    required this.onChanged,
    required this.label,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final displayName = languageName(value);
    return InkWell(
      onTap: enabled ? () => _showSearch(context) : null,
      borderRadius: BorderRadius.circular(4),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          suffixIcon: const Icon(Icons.arrow_drop_down),
          enabled: enabled,
        ),
        child: Text(
          displayName ?? 'Not set',
          style: displayName == null
              ? TextStyle(color: Theme.of(context).hintColor)
              : null,
        ),
      ),
    );
  }

  Future<void> _showSearch(BuildContext context) async {
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _LanguageSearchSheet(currentValue: value),
    );
    if (result == null) return; // dismissed without selecting
    onChanged(result == _kClear ? null : result);
  }
}

// Bottom sheet with a search field and a scrollable, filtered language list.
class _LanguageSearchSheet extends StatefulWidget {
  final String? currentValue;
  const _LanguageSearchSheet({required this.currentValue});

  @override
  State<_LanguageSearchSheet> createState() => _LanguageSearchSheetState();
}

class _LanguageSearchSheetState extends State<_LanguageSearchSheet> {
  final _searchController = TextEditingController();
  List<LanguageOption> _filtered = kLanguages;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filter(String query) {
    final q = query.toLowerCase().trim();
    setState(() {
      _filtered = q.isEmpty
          ? kLanguages
          : kLanguages
              .where((l) =>
                  l.name.toLowerCase().contains(q) ||
                  l.code.toLowerCase().contains(q))
              .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (ctx, scrollController) => Column(
        children: [
          // Drag handle + search field
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              children: [
                // Visual drag handle
                Container(
                  width: 32,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _searchController,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: 'Search languages…',
                    prefixIcon: const Icon(Icons.search),
                    // Show clear button only when there is text.
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              _filter('');
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(
                        vertical: 0, horizontal: 12),
                  ),
                  onChanged: _filter,
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // "Not set" always visible above the filtered list.
          ListTile(
            leading: const Icon(Icons.block_outlined),
            title: const Text('Not set'),
            selected: widget.currentValue == null,
            onTap: () => Navigator.of(ctx).pop(_kClear),
          ),
          const Divider(height: 1),
          // Filtered language list.
          Expanded(
            child: ListView.builder(
              controller: scrollController,
              itemCount: _filtered.length,
              itemBuilder: (_, i) {
                final lang = _filtered[i];
                return ListTile(
                  title: Text(lang.name),
                  // Show the ISO code as a subtle hint on the trailing side.
                  trailing: Text(
                    lang.code,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                  ),
                  selected: lang.code == widget.currentValue,
                  onTap: () => Navigator.of(ctx).pop(lang.code),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
