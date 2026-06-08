import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flash_me/models/tag.dart';
import 'package:flash_me/providers/auth_provider.dart';
import 'package:flash_me/providers/tag_provider.dart';
import 'package:flash_me/utils/helpers.dart';

// ---------------------------------------------------------------------------
// TagInputField — shared tag editor with global autocomplete.
//
// Displays the current [tags] as deletable chips, plus a text field that
// queries the global tags collection (debounced) and suggests matches.
// New tags are normalised before being added, so [tags] always contains
// canonical tag forms (matching the tags/{normalizedName} document IDs).
//
// The parent owns the tag list: every add/remove calls [onChanged] with the
// new list. The parent is still responsible for persisting tags and running
// the upsert/decrement lifecycle hooks on save (see Phase 4d-3).
// ---------------------------------------------------------------------------
class TagInputField extends ConsumerStatefulWidget {
  final List<String> tags;
  final ValueChanged<List<String>> onChanged;
  final bool enabled;

  const TagInputField({
    super.key,
    required this.tags,
    required this.onChanged,
    this.enabled = true,
  });

  @override
  ConsumerState<TagInputField> createState() => _TagInputFieldState();
}

class _TagInputFieldState extends ConsumerState<TagInputField> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  Timer? _debounce;
  // The query actually sent to Firestore — updated 300ms after the last
  // keystroke so we don't open a new listener on every character.
  String _query = '';

  @override
  void initState() {
    super.initState();
    // Rebuild on focus changes so suggestions hide when the field blurs.
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _focusNode.removeListener(_onFocusChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChanged() => setState(() {});

  void _onTextChanged(String value) {
    // A comma commits everything before it; the remainder stays in the field.
    if (value.contains(',')) {
      final parts = value.split(',');
      for (final p in parts.sublist(0, parts.length - 1)) {
        _commit(p);
      }
      final remainder = parts.last;
      _controller.value = TextEditingValue(
        text: remainder,
        selection: TextSelection.collapsed(offset: remainder.length),
      );
      _scheduleQuery(remainder);
      return;
    }
    _scheduleQuery(value);
  }

  void _scheduleQuery(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => _query = value.trim());
    });
  }

  // Add a raw tag string (normalised) to the list, de-duplicating by
  // normalised form. No-op for empty/whitespace-only input or duplicates.
  void _commit(String raw) {
    final normalized = AppHelpers.normalizeTag(raw);
    if (normalized.isEmpty) return;
    final existing = widget.tags.map(AppHelpers.normalizeTag).toSet();
    if (existing.contains(normalized)) return;
    widget.onChanged([...widget.tags, normalized]);
  }

  void _commitFromInput() {
    _commit(_controller.text);
    _controller.clear();
    setState(() => _query = '');
  }

  void _remove(String tag) {
    widget.onChanged(widget.tags.where((t) => t != tag).toList());
  }

  void _selectSuggestion(Tag tag) {
    _commit(tag.normalizedName); // already normalised
    _controller.clear();
    setState(() => _query = '');
    _focusNode.requestFocus(); // keep editing for rapid multi-add
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final showSuggestions = widget.enabled &&
        _focusNode.hasFocus &&
        _query.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.tags.isNotEmpty) ...[
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: widget.tags
                .map((tag) => Chip(
                      label: Text(tag),
                      onDeleted: widget.enabled ? () => _remove(tag) : null,
                    ))
                .toList(),
          ),
          const SizedBox(height: 8),
        ],
        TextField(
          controller: _controller,
          focusNode: _focusNode,
          enabled: widget.enabled,
          decoration: InputDecoration(
            hintText: 'Type to search or create tags',
            prefixIcon: const Icon(Icons.label_outline),
            border:
                OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            suffixIcon: IconButton(
              icon: const Icon(Icons.add),
              onPressed: widget.enabled ? _commitFromInput : null,
            ),
          ),
          textInputAction: TextInputAction.done,
          onChanged: _onTextChanged,
          onSubmitted: widget.enabled ? (_) => _commitFromInput() : null,
        ),
        if (showSuggestions) _buildSuggestions(theme),
      ],
    );
  }

  Widget _buildSuggestions(ThemeData theme) {
    final myUid = ref.watch(authStateProvider).asData?.value;
    final asyncTags = ref.watch(tagSearchProvider(_query));

    return asyncTags.maybeWhen(
      orElse: () => const SizedBox.shrink(),
      data: (tags) {
        final existing = widget.tags.map(AppHelpers.normalizeTag).toSet();
        // Threshold: show popular tags (usageCount >= 2) to everyone, but
        // always show the user their own tags even if only they use them.
        final suggestions = tags
            .where((t) => !existing.contains(t.normalizedName))
            .where((t) => t.usageCount >= 2 || t.createdBy == myUid)
            .toList();
        if (suggestions.isEmpty) return const SizedBox.shrink();

        return Container(
          margin: const EdgeInsets.only(top: 4),
          decoration: BoxDecoration(
            border: Border.all(color: theme.dividerColor),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: suggestions
                .map((t) => ListTile(
                      dense: true,
                      leading: const Icon(Icons.label_outline, size: 18),
                      title: Text(t.displayName),
                      trailing: Text('${t.usageCount}',
                          style: theme.textTheme.bodySmall),
                      onTap: () => _selectSuggestion(t),
                    ))
                .toList(),
          ),
        );
      },
    );
  }
}
