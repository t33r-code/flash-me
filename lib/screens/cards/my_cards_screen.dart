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
  bool _selectionMode = false;
  Set<String> _selected = {};
  String? _anchorId; // last plain-toggled row — the origin for Shift+click
  bool _isBusy = false; // a bulk action is running; actions are disabled

  // Card ids in display order (flash then workbook), rebuilt each build so
  // Shift+click ranges follow exactly what the user sees.
  List<String> _orderedIds = [];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _exitSelection() {
    setState(() {
      _selectionMode = false;
      _selected = {};
      _anchorId = null;
    });
  }

  // Keeps the selection honest when the search/tag filter narrows the list.
  // Call inside setState after changing a filter.
  void _pruneToVisible() {
    if (!_selectionMode) return;
    final flash = _filterFlash(ref.read(userCardsProvider).asData?.value ?? []);
    final workbook =
        _filterWorkbook(ref.read(userWorkbookCardsProvider).asData?.value ?? []);
    final visible = [
      ...flash.map((c) => c.id),
      ...workbook.map((c) => c.id),
    ];
    _selected = pruneSelection(_selected, visible);
    if (_anchorId != null && !_selected.contains(_anchorId)) _anchorId = null;
  }

  // Selected ids mapped to their card type, resolved from the live card lists.
  Map<String, String> _selectedIdToType() {
    final flash = ref.read(userCardsProvider).asData?.value ?? <FlashCard>[];
    final workbook =
        ref.read(userWorkbookCardsProvider).asData?.value ?? <WorkbookCard>[];
    final map = <String, String>{};
    for (final c in flash) {
      if (_selected.contains(c.id)) map[c.id] = AppConstants.cardTypeFlashcard;
    }
    for (final c in workbook) {
      if (_selected.contains(c.id)) map[c.id] = AppConstants.cardTypeWorkbook;
    }
    return map;
  }

  void _openCard(String id) {
    final flash = ref.read(userCardsProvider).asData?.value ?? <FlashCard>[];
    final match = flash.where((c) => c.id == id);
    if (match.isNotEmpty) {
      Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => CardFormScreen(card: match.first)));
      return;
    }
    final workbook =
        ref.read(userWorkbookCardsProvider).asData?.value ?? <WorkbookCard>[];
    final wb = workbook.where((c) => c.id == id);
    if (wb.isNotEmpty) {
      Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => WorkbookCardFormScreen(card: wb.first)));
    }
  }

  // Row tap. Outside selection mode a plain tap opens the card and a modifier
  // click starts a selection; inside, taps toggle and Shift extends the range.
  void _onTapCard(String id) {
    final keys = HardwareKeyboard.instance;
    // Meta covers ⌘ on macOS, where Ctrl isn't the multi-select modifier.
    final multi = keys.isControlPressed || keys.isMetaPressed;
    final range = keys.isShiftPressed;

    if (!_selectionMode) {
      if (multi || range) {
        setState(() {
          _selectionMode = true;
          _selected = {id};
          _anchorId = id;
        });
      } else {
        _openCard(id);
      }
      return;
    }

    if (range && _anchorId != null) {
      // Union the anchor→target span in, rather than replacing the selection,
      // so extending never silently discards earlier picks.
      final span = idsInRange(_orderedIds, _anchorId!, id);
      setState(() {
        _selected =
            span.isEmpty ? toggleId(_selected, id) : {..._selected, ...span};
      });
      return;
    }

    setState(() {
      _selected = toggleId(_selected, id);
      _anchorId = id;
    });
  }

  void _onLongPressCard(String id) {
    if (_selectionMode) return;
    setState(() {
      _selectionMode = true;
      _selected = {id};
      _anchorId = id;
    });
  }

  void _toggleSelectAll() {
    setState(() {
      final all = _orderedIds.toSet();
      final allSelected = all.isNotEmpty && _selected.containsAll(all);
      _selected = allSelected ? {} : all;
      _anchorId = null;
    });
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  // Bulk add-to-set: pick a target set, then run the shared #210 language
  // checks + batched add (same path the set builder uses).
  Future<void> _bulkAddToSet() async {
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

    final idToType = _selectedIdToType();
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
  Future<void> _bulkDelete() async {
    final l10n = context.l10n;
    final idToType = _selectedIdToType();
    if (idToType.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.titleDeleteCards),
        content: Text(l10n.messageDeleteCardsConfirm(idToType.length)),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(l10n.labelCancel)),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(ctx).colorScheme.error),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.actionDelete),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isBusy = true);
    try {
      final cardRepo = ref.read(cardRepositoryProvider);
      final workbookRepo = ref.read(workbookCardRepositoryProvider);
      for (final entry in idToType.entries) {
        if (entry.value == AppConstants.cardTypeFlashcard) {
          await cardRepo.deleteCard(entry.key);
        } else {
          await workbookRepo.deleteCard(entry.key);
        }
      }
      if (!mounted) return;
      setState(() => _isBusy = false);
      _exitSelection();
    } catch (_) {
      if (!mounted) return;
      setState(() => _isBusy = false);
      _snack(l10n.errorFailedDeleteCards);
    }
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
              child: Text(l10n.titleCreateCard,
                  style: Theme.of(context).textTheme.titleMedium),
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
                      builder: (_) => const WorkbookCardFormScreen()),
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
      List<FlashCard> cards, List<WorkbookCard> workbookCards) {
    final tags = <String>{};
    for (final c in cards) { tags.addAll(c.tags); }
    for (final c in workbookCards) { tags.addAll(c.tags); }
    final sorted = tags.toList()..sort();
    return sorted;
  }

  List<FlashCard> _filterFlash(List<FlashCard> cards) {
    var result = cards;
    if (_selectedTag != null) {
      result = result.where((c) => c.tags.contains(_selectedTag)).toList();
    }
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      result = result
          .where((c) =>
              c.primaryWord.toLowerCase().contains(q) ||
              c.translation.toLowerCase().contains(q))
          .toList();
    }
    return result;
  }

  List<WorkbookCard> _filterWorkbook(List<WorkbookCard> cards) {
    var result = cards;
    if (_selectedTag != null) {
      result = result.where((c) => c.tags.contains(_selectedTag)).toList();
    }
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      result = result
          .where((c) => c.prompt.toLowerCase().contains(q))
          .toList();
    }
    return result;
  }

  // Contextual app bar shown while selecting: count + the bulk actions.
  // Tag / language / remove-from-set land here in the #238 follow-up.
  AppBar _selectionAppBar(AppLocalizations l10n, bool allSelected) {
    final enabled = _selected.isNotEmpty && !_isBusy;
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.close),
        tooltip: l10n.tooltipExitSelection,
        onPressed: _isBusy ? null : _exitSelection,
      ),
      title: Text(l10n.labelSelectedCount(_selected.length)),
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
          icon: const Icon(Icons.delete_outline),
          tooltip: l10n.tooltipDeleteSelected,
          onPressed: enabled ? _bulkDelete : null,
        ),
      ],
    );
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
        _orderedIds.isNotEmpty && _selected.containsAll(_orderedIds);

    return Scaffold(
      appBar: _selectionMode
          ? _selectionAppBar(l10n, allSelected)
          : AppBar(
              title: Text(l10n.titleMyCards),
              actions: [
                IconButton(
                  icon: const Icon(Icons.checklist),
                  tooltip: l10n.actionSelect,
                  onPressed: hasCards
                      ? () => setState(() => _selectionMode = true)
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
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
                  ...allTags.map((tag) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(tag),
                          selected: _selectedTag == tag,
                          onSelected: (_) => setState(() {
                            _selectedTag = _selectedTag == tag ? null : tag;
                            _pruneToVisible();
                          }),
                        ),
                      )),
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
                allCards.isEmpty && allWorkbook.isEmpty),
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
                color: Theme.of(context).colorScheme.onSurfaceVariant),
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
        final id = i < cards.length
            ? cards[i].id
            : workbookCards[i - cards.length].id;
        // Taps route through the parent so Ctrl/Shift and mode are handled once.
        void onTap() => _onTapCard(id);
        void onLongPress() => _onLongPressCard(id);
        if (i < cards.length) {
          return _FlashCardTile(
            card: cards[i],
            selectionMode: _selectionMode,
            selected: _selected.contains(id),
            onTap: onTap,
            onLongPress: onLongPress,
          );
        }
        return _WorkbookCardTile(
          card: workbookCards[i - cards.length],
          selectionMode: _selectionMode,
          selected: _selected.contains(id),
          onTap: onTap,
          onLongPress: onLongPress,
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
              subtitle: Text(hasLang
                  ? '${set.cardCount} · ${set.targetLanguage!.toUpperCase()} → ${set.nativeLanguage!.toUpperCase()}'
                  : '${set.cardCount}'),
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
            Text(context.l10n.titleMyCards,
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              context.l10n.messageNoCardsYetCreate,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: onSurfaceVariant),
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
      color: selected
          ? Theme.of(context).colorScheme.secondaryContainer
          : null,
      child: ListTile(
        leading: _tileLeading(
            context, Icons.style_outlined, selectionMode, selected, onTap),
        title: Text(card.primaryWord),
        subtitle: Text(subtitle),
        trailing: _tileTrailing(context, card.tags, selectionMode,
            onSurfaceVariant),
        onTap: onTap,
        onLongPress: onLongPress,
      ),
    );
  }
}

// A checkbox while selecting, otherwise the card-type icon. The checkbox
// delegates to the row's own onTap so both do the same modifier-aware thing.
Widget _tileLeading(BuildContext context, IconData icon, bool selectionMode,
    bool selected, VoidCallback onTap) {
  if (!selectionMode) return Icon(icon);
  return Checkbox(value: selected, onChanged: (_) => onTap());
}

// Tag chip + chevron; the chevron is dropped while selecting since tapping
// no longer navigates.
Widget? _tileTrailing(BuildContext context, List<String> tags,
    bool selectionMode, Color onSurfaceVariant) {
  final chip = tags.isNotEmpty
      ? Chip(
          label: Text(tags.first),
          visualDensity: VisualDensity.compact,
        )
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
      color: selected
          ? Theme.of(context).colorScheme.secondaryContainer
          : null,
      child: ListTile(
        leading: _tileLeading(
            context, Icons.book_outlined, selectionMode, selected, onTap),
        title: Text(
          card.prompt,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(context.l10n.labelQuestionCount(qCount)),
        trailing: _tileTrailing(context, card.tags, selectionMode,
            onSurfaceVariant),
        onTap: onTap,
        onLongPress: onLongPress,
      ),
    );
  }
}
