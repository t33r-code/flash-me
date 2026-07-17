import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flash_me/models/flash_card.dart';
import 'package:flash_me/models/workbook_card.dart';
import 'package:flash_me/providers/auth_provider.dart';
import 'package:flash_me/providers/card_provider.dart';
import 'package:flash_me/providers/tag_provider.dart';
import 'package:flash_me/providers/workbook_card_provider.dart';
import 'package:flash_me/utils/bulk_tags.dart';
import 'package:flash_me/utils/extensions.dart';
import 'package:flash_me/utils/helpers.dart';
import 'package:flash_me/widgets/language_picker.dart';
import 'package:flash_me/widgets/tag_input_field.dart';

// ---------------------------------------------------------------------------
// Bulk edits applied across a multi-selection (#238) — shared by the card
// library and the set-detail list so both write cards the same way, including
// the global tag registry's upsert/decrement lifecycle.
// ---------------------------------------------------------------------------

// The selected cards, split by type, resolved from the live provider lists.
({List<FlashCard> flash, List<WorkbookCard> workbook}) _selectedCards(
  WidgetRef ref,
  Map<String, String> idToType,
) {
  final flash = ref.read(userCardsProvider).asData?.value ?? <FlashCard>[];
  final workbook =
      ref.read(userWorkbookCardsProvider).asData?.value ?? <WorkbookCard>[];
  return (
    flash: flash.where((c) => idToType.containsKey(c.id)).toList(),
    workbook: workbook.where((c) => idToType.containsKey(c.id)).toList(),
  );
}

// Shows the tri-state tag dialog for the selection and applies the resulting
// delta to every selected card. Returns true if anything was written.
Future<bool> bulkEditTags(
  BuildContext context,
  WidgetRef ref, {
  required Map<String, String> idToType,
}) async {
  final cards = _selectedCards(ref, idToType);
  final allTagLists = [
    ...cards.flash.map((c) => c.tags),
    ...cards.workbook.map((c) => c.tags),
  ];
  if (allTagLists.isEmpty) return false;

  final delta = await showDialog<({Set<String> add, Set<String> remove})>(
    context: context,
    builder: (_) => _BulkTagDialog(
      presence: tagPresence(allTagLists),
      cardCount: allTagLists.length,
    ),
  );
  if (delta == null || !context.mounted) return false;
  if (delta.add.isEmpty && delta.remove.isEmpty) return false;

  final uid = ref.read(authStateProvider).asData?.value ?? '';
  final cardRepo = ref.read(cardRepositoryProvider);
  final workbookRepo = ref.read(workbookCardRepositoryProvider);
  final tagRepo = ref.read(tagRepositoryProvider);

  // Per card: compute its new tag list, skip if unchanged, then mirror the
  // single-card editor's lifecycle so the global tag counts stay accurate.
  Future<void> writeTags(
    List<String> current,
    Future<void> Function(List<String> newTags) save,
  ) async {
    final newTags = applyTagDelta(current, delta.add, delta.remove);
    final (toUpsert, toDecrement) = AppHelpers.diffTags(current, newTags);
    if (toUpsert.isEmpty && toDecrement.isEmpty) return; // no-op for this card
    await save(newTags);
    // Fire-and-forget, as in the editor: a count failure must not fail the save.
    for (final tag in toUpsert) {
      tagRepo.upsertTag(tag, uid);
    }
    for (final norm in toDecrement) {
      tagRepo.decrementTag(norm);
    }
  }

  for (final card in cards.flash) {
    await writeTags(
      card.tags,
      (newTags) => cardRepo.updateCard(card.copyWith(tags: newTags)),
    );
  }
  for (final card in cards.workbook) {
    await writeTags(
      card.tags,
      (newTags) => workbookRepo.updateCard(card.copyWith(tags: newTags)),
    );
  }
  return true;
}

// Shows the language dialog and applies the chosen pair across the selection.
// Returns true if anything was written. A picker left empty leaves that
// language untouched on every card (copyWith can't null a field), so this can
// set a pair but never clear one.
Future<bool> bulkEditLanguage(
  BuildContext context,
  WidgetRef ref, {
  required Map<String, String> idToType,
}) async {
  final choice = await showDialog<({String? target, String? native})>(
    context: context,
    builder: (_) => const _BulkLanguageDialog(),
  );
  if (choice == null || !context.mounted) return false;
  if (choice.target == null && choice.native == null) return false;

  final cards = _selectedCards(ref, idToType);
  final cardRepo = ref.read(cardRepositoryProvider);
  final workbookRepo = ref.read(workbookCardRepositoryProvider);

  for (final card in cards.flash) {
    await cardRepo.updateCard(
      card.copyWith(
        targetLanguage: choice.target,
        nativeLanguage: choice.native,
      ),
    );
  }
  for (final card in cards.workbook) {
    await workbookRepo.updateCard(
      card.copyWith(
        targetLanguage: choice.target,
        nativeLanguage: choice.native,
      ),
    );
  }
  return true;
}

// ---------------------------------------------------------------------------
// Tri-state tag dialog: ticked = on every selected card, dash = on only some
// (leave as-is), unticked = remove from all.
// ---------------------------------------------------------------------------
class _BulkTagDialog extends StatefulWidget {
  final Map<String, TagPresence> presence;
  final int cardCount;
  const _BulkTagDialog({required this.presence, required this.cardCount});

  @override
  State<_BulkTagDialog> createState() => _BulkTagDialogState();
}

class _BulkTagDialogState extends State<_BulkTagDialog> {
  // tag -> true (put on all) / false (remove from all) / null (leave mixed).
  late final Map<String, bool?> _state = {
    for (final entry in widget.presence.entries)
      entry.key: entry.value == TagPresence.all ? true : null,
  };
  // Display order: existing tags sorted, then any newly typed ones.
  late final List<String> _order = widget.presence.keys.toList()..sort();

  // A tag that started out mixed can be left alone, so it cycles through three
  // states; one already on every card only has on/off.
  void _cycle(String tag) {
    final startedMixed = widget.presence[tag] == TagPresence.some;
    final current = _state[tag];
    setState(() {
      if (startedMixed) {
        _state[tag] = current == null ? true : (current == true ? false : null);
      } else {
        _state[tag] = current == true ? false : true;
      }
    });
  }

  // TagInputField reports its whole list; we keep its own list empty and lift
  // anything typed into our tri-state list (pre-ticked to add).
  void _onNewTags(List<String> typed) {
    setState(() {
      for (final tag in typed) {
        final norm = AppHelpers.normalizeTag(tag);
        if (norm.isEmpty) continue;
        if (!_order.contains(norm)) _order.add(norm);
        _state[norm] = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.titleTagCards(widget.cardCount)),
      content: SizedBox(
        width: 380,
        height: 420,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.messageBulkTagHint,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _order.isEmpty
                  ? Center(
                      child: Text(
                        l10n.messageNoTagsOnSelection,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    )
                  : ListView.builder(
                      itemCount: _order.length,
                      itemBuilder: (ctx, i) {
                        final tag = _order[i];
                        return CheckboxListTile(
                          tristate: true,
                          value: _state[tag],
                          title: Text(tag),
                          controlAffinity: ListTileControlAffinity.leading,
                          onChanged: (_) => _cycle(tag),
                        );
                      },
                    ),
            ),
            const Divider(),
            // Always-empty list: this field is only an entry point for new tags.
            TagInputField(tags: const [], onChanged: _onNewTags),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.labelCancel),
        ),
        FilledButton(
          onPressed: () {
            final add = <String>{};
            final remove = <String>{};
            for (final entry in _state.entries) {
              if (entry.value == true) add.add(entry.key);
              if (entry.value == false) remove.add(entry.key);
            }
            Navigator.of(context).pop((add: add, remove: remove));
          },
          child: Text(l10n.actionApply),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Language dialog: pick a target and/or native language for the whole
// selection. An untouched picker leaves that language alone.
// ---------------------------------------------------------------------------
class _BulkLanguageDialog extends StatefulWidget {
  const _BulkLanguageDialog();

  @override
  State<_BulkLanguageDialog> createState() => _BulkLanguageDialogState();
}

class _BulkLanguageDialogState extends State<_BulkLanguageDialog> {
  String? _target;
  String? _native;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.titleSetLanguageForCards),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.messageBulkLanguageHint,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            LanguagePicker(
              label: l10n.labelTargetLanguage,
              value: _target,
              onChanged: (v) => setState(() => _target = v),
            ),
            const SizedBox(height: 12),
            LanguagePicker(
              label: l10n.labelNativeLanguage,
              value: _native,
              onChanged: (v) => setState(() => _native = v),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.labelCancel),
        ),
        FilledButton(
          onPressed: (_target == null && _native == null)
              ? null
              : () => Navigator.of(
                  context,
                ).pop((target: _target, native: _native)),
          child: Text(l10n.actionApply),
        ),
      ],
    );
  }
}
