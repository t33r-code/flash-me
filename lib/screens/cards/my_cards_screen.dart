import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flash_me/l10n/app_localizations.dart';
import 'package:flash_me/models/card_set.dart';
import 'package:flash_me/models/flash_card.dart';
import 'package:flash_me/widgets/help_menu_button.dart';
import 'package:flash_me/models/workbook_card.dart';
import 'package:flash_me/providers/auth_provider.dart';
import 'package:flash_me/providers/card_provider.dart';
import 'package:flash_me/providers/card_set_provider.dart';
import 'package:flash_me/providers/workbook_card_provider.dart';
import 'package:flash_me/screens/cards/card_form_screen.dart';
import 'package:flash_me/screens/cards/workbook_card_form_screen.dart';
import 'package:flash_me/utils/constants.dart';
import 'package:flash_me/utils/extensions.dart';
import 'package:flash_me/utils/selection.dart';
import 'package:flash_me/widgets/add_cards_to_set.dart';
import 'package:flash_me/widgets/bulk_card_actions.dart';
import 'package:flash_me/widgets/context_menu.dart';
import 'package:flash_me/widgets/hover_highlight.dart';

class MyCardsScreen extends ConsumerStatefulWidget {
  const MyCardsScreen({super.key});

  @override
  ConsumerState<MyCardsScreen> createState() => _MyCardsScreenState();
}

class _MyCardsScreenState extends ConsumerState<MyCardsScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String? _selectedTag; // null = show all

  // Multi-select (#238). Mode is explicit: entered via the Select button,
  // long-press (touch), or Ctrl/Shift+click (desktop); only ✕ leaves it.
  final _selection = SelectionModel();
  bool _isBusy = false; // a bulk action is running; actions are disabled

  // Cards hidden optimistically while their background delete runs, so the
  // list doesn't dissolve row-by-row as each Firestore delete lands. Ids stay
  // here after a successful delete — the card is gone, so filtering on a dead
  // id is harmless, and it avoids a flash if the stream hasn't caught up yet.
  // Failed ids are removed so those rows come back.
  final Set<String> _pendingDelete = {};

  // Card ids in display order (flash then workbook), rebuilt each build so
  // Shift+click ranges follow exactly what the user sees.
  List<String> _orderedIds = [];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _exitSelection() => setState(_selection.exit);

  // Keeps the selection honest when the search/tag filter narrows the list.
  // Call inside setState after changing a filter.
  void _pruneToVisible() {
    if (!_selection.mode) return;
    final flash = _filterFlash(ref.read(userCardsProvider).asData?.value ?? []);
    final workbook = _filterWorkbook(
      ref.read(userWorkbookCardsProvider).asData?.value ?? [],
    );
    _selection.prune([...flash.map((c) => c.id), ...workbook.map((c) => c.id)]);
  }

  // Selected ids mapped to their card type, resolved from the live card lists.
  Map<String, String> _selectedIdToType() {
    final flash = ref.read(userCardsProvider).asData?.value ?? <FlashCard>[];
    final workbook =
        ref.read(userWorkbookCardsProvider).asData?.value ?? <WorkbookCard>[];
    final map = <String, String>{};
    for (final c in flash) {
      if (_selection.contains(c.id)) map[c.id] = AppConstants.cardTypeFlashcard;
    }
    for (final c in workbook) {
      if (_selection.contains(c.id)) map[c.id] = AppConstants.cardTypeWorkbook;
    }
    return map;
  }

  void _openCard(String id) {
    final flash = ref.read(userCardsProvider).asData?.value ?? <FlashCard>[];
    final match = flash.where((c) => c.id == id);
    if (match.isNotEmpty) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => CardFormScreen(card: match.first)),
      );
      return;
    }
    final workbook =
        ref.read(userWorkbookCardsProvider).asData?.value ?? <WorkbookCard>[];
    final wb = workbook.where((c) => c.id == id);
    if (wb.isNotEmpty) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => WorkbookCardFormScreen(card: wb.first),
        ),
      );
    }
  }

  // Row tap. Outside selection mode a plain tap opens the card and a modifier
  // click starts a selection; inside, taps toggle and Shift extends the range.
  void _onTapCard(String id) {
    final keys = HardwareKeyboard.instance;
    // Meta covers ⌘ on macOS, where Ctrl isn't the multi-select modifier.
    final multi = keys.isControlPressed || keys.isMetaPressed;
    final range = keys.isShiftPressed;

    if (!_selection.mode) {
      if (multi || range) {
        setState(() => _selection.enterWith(id));
      } else {
        _openCard(id);
      }
      return;
    }

    setState(() {
      if (range) {
        _selection.extendTo(id, _orderedIds);
      } else {
        _selection.toggle(id);
      }
    });
  }

  void _onLongPressCard(String id) {
    if (_selection.mode) return;
    setState(() => _selection.enterWith(id));
  }

  void _toggleSelectAll() =>
      setState(() => _selection.toggleSelectAll(_orderedIds));

  // Right-click menu for a single card (#237) — reuses the exact same bulk
  // helpers as the selection toolbar, just with a one-entry map, so a single
  // right-click action and a multi-select bulk action always behave alike.
  List<ContextMenuAction> _cardContextActions(String id, String cardType) {
    final l10n = context.l10n;
    final entry = {id: cardType};
    return [
      ContextMenuAction(
        icon: Icons.edit_outlined,
        label: l10n.tooltipEditCard,
        onSelected: () => _openCard(id),
      ),
      ContextMenuAction(
        icon: Icons.playlist_add,
        label: l10n.titleAddToSet,
        onSelected: () => _bulkAddToSet(entry),
      ),
      ContextMenuAction(
        icon: Icons.label_outline,
        label: l10n.actionTag,
        onSelected: () => _bulkTag(entry),
      ),
      ContextMenuAction(
        icon: Icons.translate,
        label: l10n.tooltipSetLanguageSelected,
        onSelected: () => _bulkLanguage(entry),
      ),
      ContextMenuAction(
        icon: Icons.delete_outline,
        label: l10n.tooltipDeleteCard,
        destructive: true,
        onSelected: () => _bulkDelete(entry),
      ),
    ];
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  // Bulk add-to-set: pick a target set, then run the shared #210 language
  // checks + batched add (same path the set builder uses). [idToType]
  // defaults to the current selection; the context menu (#237) passes a
  // single-card map instead so the same path serves both entry points.
  Future<void> _bulkAddToSet([Map<String, String>? selection]) async {
    final idToType = selection ?? _selectedIdToType();
    final l10n = context.l10n;
    final sets = ref.read(userSetsProvider).asData?.value ?? <CardSet>[];
    if (sets.isEmpty) {
      _snack(l10n.messageNoSets);
      return;
    }
    final chosen = await showDialog<CardSet>(
      context: context,
      builder: (_) => _SetPickerDialog(sets: sets),
    );
    if (chosen == null || !mounted) return;

    final uid = ref.read(authStateProvider).asData?.value ?? '';
    setState(() => _isBusy = true);
    try {
      final added = await addCardsWithLanguageCheck(
        context,
        ref,
        setId: chosen.id,
        userId: uid,
        setTarget: chosen.targetLanguage,
        setNative: chosen.nativeLanguage,
        idToType: idToType,
      );
      if (!mounted) return;
      setState(() => _isBusy = false);
      if (!added) return; // user cancelled a language dialog
      _snack(l10n.messageCardsAddedToSet(idToType.length, chosen.name));
      _exitSelection();
    } catch (_) {
      if (!mounted) return;
      setState(() => _isBusy = false);
      _snack(l10n.errorFailedAddCardsToSet);
    }
  }

  // Bulk delete behind one confirmation. Each card goes through the existing
  // per-card delete, which also clears its set links and Storage media.
  // [idToType] defaults to the current selection; see _bulkAddToSet.
  Future<void> _bulkDelete([Map<String, String>? selection]) async {
    final idToType = selection ?? _selectedIdToType();
    final l10n = context.l10n;
    if (idToType.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.titleDeleteCards),
        content: Text(l10n.messageDeleteCardsConfirm(idToType.length)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.labelCancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.actionDelete),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    // Hide the rows and leave selection mode straight away, then delete in the
    // background. Each card is deleted individually (that's what clears its set
    // links and media), so without this the list would visibly dissolve a row
    // at a time as each delete came back through the Firestore stream.
    setState(() => _pendingDelete.addAll(idToType.keys));
    _exitSelection();

    final cardRepo = ref.read(cardRepositoryProvider);
    final workbookRepo = ref.read(workbookCardRepositoryProvider);
    final failed = <String>[];
    for (final entry in idToType.entries) {
      try {
        if (entry.value == AppConstants.cardTypeFlashcard) {
          await cardRepo.deleteCard(entry.key);
        } else {
          await workbookRepo.deleteCard(entry.key);
        }
      } catch (_) {
        failed.add(entry.key);
      }
    }
    // Deletes are allowed to finish even if the user navigated away; only the
    // UI feedback below needs the screen to still be mounted.
    if (!mounted || failed.isEmpty) return;
    // Bring back only the rows we couldn't delete.
    setState(() => _pendingDelete.removeAll(failed));
    _snack(l10n.errorFailedDeleteCards);
  }

  // Shows a bottom sheet letting the user choose Flash Card or Workbook Card.
  void _showCardTypeChooser(BuildContext context) {
    final l10n = context.l10n;
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text(
                l10n.titleCreateCard,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.style_outlined),
              title: Text(l10n.labelFlashCard),
              subtitle: Text(l10n.messageFlashCardSubtitle),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const CardFormScreen()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.book_outlined),
              title: Text(l10n.labelWorkbookCard),
              subtitle: Text(l10n.messageWorkbookCardSubtitle),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const WorkbookCardFormScreen(),
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // Unique sorted tags from both card lists (full unfiltered data).
  List<String> _allTags(
    List<FlashCard> cards,
    List<WorkbookCard> workbookCards,
  ) {
    final tags = <String>{};
    for (final c in cards) {
      tags.addAll(c.tags);
    }
    for (final c in workbookCards) {
      tags.addAll(c.tags);
    }
    final sorted = tags.toList()..sort();
    return sorted;
  }

  List<FlashCard> _filterFlash(List<FlashCard> cards) {
    // Drop cards whose delete is still in flight (see _pendingDelete).
    var result = cards.where((c) => !_pendingDelete.contains(c.id)).toList();
    if (_selectedTag != null) {
      result = result.where((c) => c.tags.contains(_selectedTag)).toList();
    }
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      result = result
          .where(
            (c) =>
                c.primaryWord.toLowerCase().contains(q) ||
                c.translation.toLowerCase().contains(q),
          )
          .toList();
    }
    return result;
  }

  List<WorkbookCard> _filterWorkbook(List<WorkbookCard> cards) {
    // Drop cards whose delete is still in flight (see _pendingDelete).
    var result = cards.where((c) => !_pendingDelete.contains(c.id)).toList();
    if (_selectedTag != null) {
      result = result.where((c) => c.tags.contains(_selectedTag)).toList();
    }
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      result = result.where((c) => c.prompt.toLowerCase().contains(q)).toList();
    }
    return result;
  }

  // Contextual app bar shown while selecting: count + the bulk actions.
  // Tag / language / remove-from-set land here in the #238 follow-up.
  AppBar _selectionAppBar(AppLocalizations l10n, bool allSelected) {
    final enabled = _selection.isNotEmpty && !_isBusy;
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.close),
        tooltip: l10n.tooltipExitSelection,
        onPressed: _isBusy ? null : _exitSelection,
      ),
      title: Text(l10n.labelSelectedCount(_selection.length)),
      actions: [
        IconButton(
          icon: const Icon(Icons.select_all),
          tooltip: allSelected ? l10n.actionDeselectAll : l10n.actionSelectAll,
          onPressed: _isBusy ? null : _toggleSelectAll,
        ),
        IconButton(
          icon: const Icon(Icons.playlist_add),
          tooltip: l10n.titleAddToSet,
          onPressed: enabled ? _bulkAddToSet : null,
        ),
        IconButton(
          icon: const Icon(Icons.label_outline),
          tooltip: l10n.tooltipTagSelected,
          onPressed: enabled ? _bulkTag : null,
        ),
        IconButton(
          icon: const Icon(Icons.translate),
          tooltip: l10n.tooltipSetLanguageSelected,
          onPressed: enabled ? _bulkLanguage : null,
        ),
        IconButton(
          icon: const Icon(Icons.delete_outline),
          tooltip: l10n.tooltipDeleteSelected,
          onPressed: enabled ? _bulkDelete : null,
        ),
      ],
    );
  }

  // Bulk tag / language: both run the shared dialog + apply, then report.
  // The selection stays put so several edits can be stacked in one pass.
  // [idToType] defaults to the current selection; see _bulkAddToSet.
  Future<void> _bulkTag([Map<String, String>? idToType]) =>
      _runBulkEdit(bulkEditTags, idToType);
  Future<void> _bulkLanguage([Map<String, String>? idToType]) =>
      _runBulkEdit(bulkEditLanguage, idToType);

  Future<void> _runBulkEdit(
    Future<bool> Function(
      BuildContext,
      WidgetRef, {
      required Map<String, String> idToType,
    })
    action,
    Map<String, String>? selection,
  ) async {
    final l10n = context.l10n;
    final idToType = selection ?? _selectedIdToType();
    if (idToType.isEmpty) return;
    setState(() => _isBusy = true);
    try {
      final applied = await action(context, ref, idToType: idToType);
      if (!mounted) return;
      setState(() => _isBusy = false);
      if (applied) _snack(l10n.messageCardsUpdated(idToType.length));
    } catch (_) {
      if (!mounted) return;
      setState(() => _isBusy = false);
      _snack(l10n.errorFailedUpdateCards);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cardsAsync = ref.watch(userCardsProvider);
    final workbookCardsAsync = ref.watch(userWorkbookCardsProvider);

    final allCards = cardsAsync.asData?.value ?? [];
    final allWorkbook = workbookCardsAsync.asData?.value ?? [];
    final allTags = _allTags(allCards, allWorkbook);

    final filteredCards = _filterFlash(allCards);
    final filteredWorkbook = _filterWorkbook(allWorkbook);

    // Display order drives Shift+click ranges and Select all.
    _orderedIds = [
      ...filteredCards.map((c) => c.id),
      ...filteredWorkbook.map((c) => c.id),
    ];
    final hasCards = allCards.isNotEmpty || allWorkbook.isNotEmpty;
    final allSelected =
        _orderedIds.isNotEmpty && _selection.selected.containsAll(_orderedIds);

    return Scaffold(
      appBar: _selection.mode
          ? _selectionAppBar(l10n, allSelected)
          : AppBar(
              title: Text(l10n.titleMyCards),
              actions: [
                IconButton(
                  icon: const Icon(Icons.checklist),
                  tooltip: l10n.actionSelect,
                  onPressed: hasCards
                      ? () => setState(() => _selection.mode = true)
                      : null,
                ),
                const HelpMenuButton(HelpContext.cards),
              ],
            ),
      body: Column(
        children: [
          // Search bar.
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: l10n.hintSearchCards,
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => setState(() {
                          _searchController.clear();
                          _searchQuery = '';
                          _pruneToVisible();
                        }),
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(28),
                  borderSide: BorderSide.none,
                ),
                filled: true,
              ),
              onChanged: (v) => setState(() {
                _searchQuery = v.trim();
                _pruneToVisible();
              }),
            ),
          ),

          // Tag filter chips — only rendered when there are tags to show.
          if (allTags.isNotEmpty)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  FilterChip(
                    label: Text(l10n.labelAll),
                    selected: _selectedTag == null,
                    onSelected: (_) => setState(() {
                      _selectedTag = null;
                      _pruneToVisible();
                    }),
                  ),
                  const SizedBox(width: 8),
                  ...allTags.map(
                    (tag) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(tag),
                        selected: _selectedTag == tag,
                        onSelected: (_) => setState(() {
                          _selectedTag = _selectedTag == tag ? null : tag;
                          _pruneToVisible();
                        }),
                      ),
                    ),
                  ),
                ],
              ),
            ),

          Expanded(
            child: _buildCardList(
              context,
              cardsAsync.isLoading || workbookCardsAsync.isLoading,
              cardsAsync.hasError || workbookCardsAsync.hasError,
              filteredCards,
              filteredWorkbook,
              allCards.isEmpty && allWorkbook.isEmpty,
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: null,
        onPressed: () => _showCardTypeChooser(context),
        tooltip: l10n.tooltipCreateCard,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildCardList(
    BuildContext context,
    bool isLoading,
    bool hasError,
    List<FlashCard> cards,
    List<WorkbookCard> workbookCards,
    bool isEmpty,
  ) {
    if (isLoading) return const Center(child: CircularProgressIndicator());
    if (hasError) return Center(child: Text(context.l10n.errorFailedLoadCards));
    if (isEmpty) return const _EmptyState();

    if (cards.isEmpty && workbookCards.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            context.l10n.messageNoCardsMatchSearch,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final itemCount = cards.length + workbookCards.length;
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: itemCount,
      itemBuilder: (ctx, i) {
        final isFlash = i < cards.length;
        final id = isFlash ? cards[i].id : workbookCards[i - cards.length].id;
        final cardType = isFlash
            ? AppConstants.cardTypeFlashcard
            : AppConstants.cardTypeWorkbook;
        // Taps route through the parent so Ctrl/Shift and mode are handled once.
        void onTap() => _onTapCard(id);
        void onLongPress() => _onLongPressCard(id);
        final tile = isFlash
            ? _FlashCardTile(
                card: cards[i],
                selectionMode: _selection.mode,
                selected: _selection.contains(id),
                onTap: onTap,
                onLongPress: onLongPress,
              )
            : _WorkbookCardTile(
                card: workbookCards[i - cards.length],
                selectionMode: _selection.mode,
                selected: _selection.contains(id),
                onTap: onTap,
                onLongPress: onLongPress,
              );
        // Right-click and hover (#237) — additive on top of the existing tap
        // handling above; secondary-tap doesn't compete with the primary-tap
        // recognizers ListTile/InkWell already use internally.
        return HoverHighlight(
          child: GestureDetector(
            onSecondaryTapDown: (details) => showContextMenu(
              context,
              details.globalPosition,
              _cardContextActions(id, cardType),
            ),
            child: tile,
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Set picker — choose which set the selected cards get added to (#238).
// ---------------------------------------------------------------------------
class _SetPickerDialog extends StatelessWidget {
  final List<CardSet> sets;
  const _SetPickerDialog({required this.sets});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.titleChooseSet),
      contentPadding: const EdgeInsets.symmetric(vertical: 12),
      content: SizedBox(
        width: 360,
        // Cap the height so a long set list scrolls instead of overflowing.
        height: 360,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: sets.length,
          itemBuilder: (ctx, i) {
            final set = sets[i];
            final hasLang =
                set.targetLanguage != null && set.nativeLanguage != null;
            return ListTile(
              leading: const Icon(Icons.folder_outlined),
              title: Text(set.name),
              subtitle: Text(
                hasLang
                    ? '${set.cardCount} · ${set.targetLanguage!.toUpperCase()} → ${set.nativeLanguage!.toUpperCase()}'
                    : '${set.cardCount}',
              ),
              onTap: () => Navigator.of(ctx).pop(set),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.labelCancel),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Empty state — shown when the user has no cards of any type.
// ---------------------------------------------------------------------------
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final onSurfaceVariant = Theme.of(context).colorScheme.onSurfaceVariant;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.style_outlined, size: 80, color: onSurfaceVariant),
            const SizedBox(height: 16),
            Text(
              context.l10n.titleMyCards,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              context.l10n.messageNoCardsYetCreate,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Single flash card row: primary word, translation, language badge, first tag.
// ---------------------------------------------------------------------------
class _FlashCardTile extends StatelessWidget {
  final FlashCard card;
  final bool selectionMode;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  const _FlashCardTile({
    required this.card,
    required this.selectionMode,
    required this.selected,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final onSurfaceVariant = Theme.of(context).colorScheme.onSurfaceVariant;
    final hasLanguage =
        card.targetLanguage != null && card.nativeLanguage != null;
    final subtitle = hasLanguage
        ? '${card.translation}  ·  ${card.targetLanguage!.toUpperCase()} → ${card.nativeLanguage!.toUpperCase()}'
        : card.translation;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      // Tint selected rows so the selection reads at a glance.
      color: selected ? Theme.of(context).colorScheme.secondaryContainer : null,
      child: ListTile(
        leading: _tileLeading(
          context,
          Icons.style_outlined,
          selectionMode,
          selected,
          onTap,
        ),
        title: Text(card.primaryWord),
        subtitle: Text(subtitle),
        trailing: _tileTrailing(
          context,
          card.tags,
          selectionMode,
          onSurfaceVariant,
        ),
        onTap: onTap,
        onLongPress: onLongPress,
      ),
    );
  }
}

// A checkbox while selecting, otherwise the card-type icon. The checkbox
// delegates to the row's own onTap so both do the same modifier-aware thing.
Widget _tileLeading(
  BuildContext context,
  IconData icon,
  bool selectionMode,
  bool selected,
  VoidCallback onTap,
) {
  if (!selectionMode) return Icon(icon);
  return Checkbox(value: selected, onChanged: (_) => onTap());
}

// Tag chip + chevron; the chevron is dropped while selecting since tapping
// no longer navigates.
Widget? _tileTrailing(
  BuildContext context,
  List<String> tags,
  bool selectionMode,
  Color onSurfaceVariant,
) {
  final chip = tags.isNotEmpty
      ? Chip(label: Text(tags.first), visualDensity: VisualDensity.compact)
      : null;
  if (selectionMode) return chip;
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      if (chip != null) ...[chip, const SizedBox(width: 4)],
      Icon(Icons.chevron_right, size: 20, color: onSurfaceVariant),
    ],
  );
}

// ---------------------------------------------------------------------------
// Single workbook card row: prompt (truncated), question count, first tag.
// ---------------------------------------------------------------------------
class _WorkbookCardTile extends StatelessWidget {
  final WorkbookCard card;
  final bool selectionMode;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  const _WorkbookCardTile({
    required this.card,
    required this.selectionMode,
    required this.selected,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final onSurfaceVariant = Theme.of(context).colorScheme.onSurfaceVariant;
    final qCount = card.questions.length;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      color: selected ? Theme.of(context).colorScheme.secondaryContainer : null,
      child: ListTile(
        leading: _tileLeading(
          context,
          Icons.book_outlined,
          selectionMode,
          selected,
          onTap,
        ),
        title: Text(card.prompt, maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: Text(context.l10n.labelQuestionCount(qCount)),
        trailing: _tileTrailing(
          context,
          card.tags,
          selectionMode,
          onSurfaceVariant,
        ),
        onTap: onTap,
        onLongPress: onLongPress,
      ),
    );
  }
}
