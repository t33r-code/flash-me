import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flash_me/models/card_set.dart';
import 'package:flash_me/widgets/help_menu_button.dart';
import 'package:flash_me/models/flash_card.dart';
import 'package:flash_me/models/workbook_card.dart';
import 'package:flash_me/providers/auth_provider.dart';
import 'package:flash_me/providers/card_provider.dart';
import 'package:flash_me/providers/card_set_provider.dart';
import 'package:flash_me/providers/export_provider.dart';
import 'package:flash_me/providers/question_template_provider.dart';
import 'package:flash_me/providers/tag_provider.dart';
import 'package:flash_me/providers/template_provider.dart';
import 'package:flash_me/providers/workbook_card_provider.dart';
import 'package:flash_me/utils/extensions.dart';
import 'package:flash_me/utils/helpers.dart';
import 'package:flash_me/utils/set_ordering.dart';
import 'package:flash_me/screens/sets/set_form_screen.dart';
import 'package:flash_me/screens/study/study_setup_screen.dart';
import 'package:flash_me/utils/constants.dart';

// ---------------------------------------------------------------------------
// SetDetailScreen — live card list for a set with add/remove membership.
// ---------------------------------------------------------------------------
class SetDetailScreen extends ConsumerStatefulWidget {
  final CardSet cardSet; // initial value; AppBar title updates via setByIdProvider
  const SetDetailScreen({super.key, required this.cardSet});

  @override
  ConsumerState<SetDetailScreen> createState() => _SetDetailScreenState();
}

class _SetDetailScreenState extends ConsumerState<SetDetailScreen> {
  bool _isDeleting = false;
  bool _isExporting = false;
  bool _isPublishing = false;
  // Card order applied optimistically right after a drag, held until the
  // position-ordered stream catches up. Null when not mid-reorder.
  List<String>? _optimisticOrder;

  // Drag ended: rebuild the full ordered id list and persist it via #244's
  // reorderCards. [currentOrder] is the ids as currently displayed.
  void _onReorder(List<String> currentOrder, int oldIndex, int newIndex) {
    final ids = reorderedIds(currentOrder, oldIndex, newIndex);
    if (_sameSequence(ids, currentOrder)) return; // dropped in place
    setState(() => _optimisticOrder = ids);
    _persistReorder(ids);
  }

  Future<void> _persistReorder(List<String> orderedCardIds) async {
    final uid = ref.read(authStateProvider).asData?.value ?? '';
    try {
      await ref.read(cardSetRepositoryProvider).reorderCards(
            setId: widget.cardSet.id,
            userId: uid,
            orderedCardIds: orderedCardIds,
          );
    } catch (_) {
      if (mounted) {
        // Drop the override so the list snaps back to the persisted order.
        setState(() => _optimisticOrder = null);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.errorFailedReorderCards)),
        );
      }
    }
  }

  // Order to render: the optimistic drag order while a write is in flight and
  // membership is unchanged; otherwise the stream's position order. Clears the
  // override once the write lands or a card is added/removed.
  List<String> _displayOrder(List<String> streamOrder) {
    final opt = _optimisticOrder;
    if (opt == null) return streamOrder;
    // Membership changed, or the stream now matches the override → use stream
    // order (both cases mean the override is stale; clearing is a no-op visually
    // in the match case, so it's safe to do during build).
    if (!_sameContents(opt, streamOrder) || _sameSequence(opt, streamOrder)) {
      _optimisticOrder = null;
      return streamOrder;
    }
    return opt;
  }

  bool _sameSequence(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  bool _sameContents(List<String> a, List<String> b) =>
      a.length == b.length && a.toSet().containsAll(b);

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.l10n.titleDeleteSet),
        content: Text(context.l10n.messageDeleteSetConfirm(widget.cardSet.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(context.l10n.labelCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(ctx).colorScheme.error),
            child: Text(context.l10n.labelDelete),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    setState(() => _isDeleting = true);
    try {
      final uid = ref.read(authStateProvider).asData?.value ?? '';
      final tagsToDecrement = widget.cardSet.tags
          .map(AppHelpers.normalizeTag)
          .where((t) => t.isNotEmpty)
          .toList();
      final tagRepo = ref.read(tagRepositoryProvider);
      await ref
          .read(cardSetRepositoryProvider)
          .deleteSet(widget.cardSet.id, uid);
      for (final norm in tagsToDecrement) { tagRepo.decrementTag(norm); }
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.errorFailedDeleteSet)),
        );
      }
    } finally {
      if (mounted) setState(() => _isDeleting = false);
    }
  }

  // Awaits the Firestore delete and returns true/false for confirmDismiss.
  // Using confirmDismiss (rather than onDismissed) ensures the stream has
  // already updated before Dismissible completes its animation, avoiding
  // a race where both the stream and Dismissible try to remove the same
  // widget simultaneously, which causes a brief ErrorWidget flash.
  Future<bool> _removeCard(String cardId) async {
    final uid = ref.read(authStateProvider).asData?.value ?? '';
    try {
      await ref.read(cardSetRepositoryProvider).removeCardFromSet(
            setId: widget.cardSet.id,
            cardId: cardId,
            userId: uid,
          );
      return true;
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.errorFailedRemoveCard)),
        );
      }
      return false; // cancels the dismiss animation so the card stays visible
    }
  }

  // Exports the set as a self-contained ZIP archive.
  Future<void> _exportSet(CardSet liveSet) async {
    setState(() => _isExporting = true);
    final uid = ref.read(authStateProvider).asData?.value ?? '';
    final cards =
        ref.read(cardsInSetProvider(widget.cardSet.id)).asData?.value ?? [];
    // Fetch templates directly from repositories — don't rely on cached
    // stream state, which may be AsyncLoading if the Templates tab hasn't
    // been opened yet.
    final cardTemplates = await ref
        .read(templateRepositoryProvider)
        .watchUserTemplates(uid)
        .first;
    final questionTemplates = await ref
        .read(questionTemplateRepositoryProvider)
        .getUserTemplates(uid);

    // Show a non-dismissible progress dialog while the archive is built.
    if (!mounted) return;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        content: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 20),
            Text(ctx.l10n.messagePreparingExport),
          ],
        ),
      ),
    );

    try {
      final savedPath = await ref
          .read(exportServiceProvider)
          .exportSet(
            liveSet,
            cards,
            cardTemplates: cardTemplates,
            questionTemplates: questionTemplates,
          );
      if (mounted) {
        Navigator.of(context).pop(); // dismiss progress dialog
        if (savedPath != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.l10n.messageSavedTo(savedPath))),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // dismiss progress dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.errorExportFailed)),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  // Opens the "Offer in Market" bottom sheet for a private set.
  Future<void> _offerInMarket(CardSet liveSet) async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _MarketPublishSheet(cardSet: liveSet),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _isPublishing = true);
    try {
      await ref
          .read(cardSetRepositoryProvider)
          .updateSet(liveSet.copyWith(isPublic: true));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.errorFailedPublish)),
        );
      }
    } finally {
      if (mounted) setState(() => _isPublishing = false);
    }
  }

  // Shows the un-publish confirmation with acquisitionCount guard.
  Future<void> _removeFromMarket(CardSet liveSet) async {
    final count = liveSet.acquisitionCount;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.l10n.titleRemoveFromMarket),
        content: Text(
          count > 0
              ? context.l10n.messageRemoveFromMarketAcquired(liveSet.name, count)
              : context.l10n.messageRemoveFromMarketNoAcquisitions(liveSet.name),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(context.l10n.labelCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(ctx).colorScheme.error),
            child: Text(context.l10n.labelDelete),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _isPublishing = true);
    try {
      await ref
          .read(cardSetRepositoryProvider)
          .updateSet(liveSet.copyWith(isPublic: false));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.errorFailedRemoveFromMarket)),
        );
      }
    } finally {
      if (mounted) setState(() => _isPublishing = false);
    }
  }

  // Navigates to the study setup screen for this set.
  void _study() {
    final currentSet =
        ref.read(setByIdProvider(widget.cardSet.id)) ?? widget.cardSet;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => StudySetupScreen(cardSet: currentSet),
    ));
  }

  // Opens the card picker bottom sheet.
  Future<void> _showCardPicker() async {
    final uid = ref.read(authStateProvider).asData?.value ?? '';
    // Use the live set so a just-edited language pair is reflected immediately.
    final currentSet =
        ref.read(setByIdProvider(widget.cardSet.id)) ?? widget.cardSet;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _CardPickerSheet(
        setId: widget.cardSet.id,
        userId: uid,
        targetLanguage: currentSet.targetLanguage,
        nativeLanguage: currentSet.nativeLanguage,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    // Keep title in sync with edits made via SetFormScreen.
    final liveSet =
        ref.watch(setByIdProvider(widget.cardSet.id)) ?? widget.cardSet;

    // Ordered join links (both card types) drive the display order + reorder.
    final linksAsync = ref.watch(setCardsInSetProvider(widget.cardSet.id));
    // Card content, resolved by id per type.
    final flashCardsAsync = ref.watch(cardsInSetProvider(widget.cardSet.id));
    final allWorkbookAsync = ref.watch(userWorkbookCardsProvider);

    final isLoading = linksAsync.isLoading ||
        flashCardsAsync.isLoading ||
        allWorkbookAsync.isLoading;
    final hasError = linksAsync.hasError ||
        flashCardsAsync.hasError ||
        allWorkbookAsync.hasError;

    final links = linksAsync.asData?.value ?? [];
    final flashById = {
      for (final c in flashCardsAsync.asData?.value ?? <FlashCard>[]) c.id: c
    };
    final workbookById = {
      for (final c in allWorkbookAsync.asData?.value ?? <WorkbookCard>[]) c.id: c
    };
    final typeById = {for (final l in links) l.cardId: l.cardType};

    // Position order from the stream, then any in-flight optimistic drag order.
    final order = _displayOrder([for (final l in links) l.cardId]);

    // Resolve each ordered id to a renderable tile, skipping ids whose card
    // content hasn't loaded (or was deleted). The join order is authoritative.
    final entries = <({String cardId, FlashCard? flash, WorkbookCard? workbook})>[];
    for (final id in order) {
      if (typeById[id] == AppConstants.cardTypeWorkbook) {
        final wb = workbookById[id];
        if (wb != null) entries.add((cardId: id, flash: null, workbook: wb));
      } else {
        final fc = flashById[id];
        if (fc != null) entries.add((cardId: id, flash: fc, workbook: null));
      }
    }

    Widget body;
    if (isLoading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (hasError) {
      body = Center(child: Text(l10n.errorFailedLoadCards));
    } else if (entries.isEmpty) {
      body = _EmptyState(onAddCards: _showCardPicker);
    } else {
      // Single position-ordered list across both card types. Drag the handle to
      // reorder (persists via reorderCards); swipe left to remove.
      final orderedIds = [for (final e in entries) e.cardId];
      body = ReorderableListView.builder(
        padding: const EdgeInsets.all(8),
        buildDefaultDragHandles: false,
        itemCount: entries.length,
        // onReorder is the cross-version-safe callback (onReorderItem is newer
        // and absent on older stable Flutter). We adjust newIndex ourselves.
        // ignore: deprecated_member_use
        onReorder: (oldIndex, newIndex) =>
            _onReorder(orderedIds, oldIndex, newIndex),
        itemBuilder: (ctx, i) {
          final entry = entries[i];
          final handle = ReorderableDragStartListener(
            index: i,
            child: Tooltip(
              message: ctx.l10n.tooltipDragToReorder,
              child: Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Icon(Icons.drag_handle,
                    color: Theme.of(ctx).colorScheme.onSurfaceVariant),
              ),
            ),
          );
          final tile = entry.flash != null
              ? _FlashCardInSetTile(card: entry.flash!, dragHandle: handle)
              : _WorkbookCardInSetTile(
                  card: entry.workbook!, dragHandle: handle);

          // Swipe left to remove the card from this set (works for both types).
          // Key must sit on the outer widget for ReorderableListView.
          return Dismissible(
            key: ValueKey(entry.cardId),
            direction: DismissDirection.endToStart,
            background: Container(
              alignment: Alignment.centerRight,
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              padding: const EdgeInsets.only(right: 20),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.remove_circle_outline,
                color: Theme.of(context).colorScheme.onErrorContainer,
              ),
            ),
            confirmDismiss: (_) => _removeCard(entry.cardId),
            child: tile,
          );
        },
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(liveSet.name),
        actions: [
          // Market publish/unpublish toggle.
          // Outlined = private; filled + primary colour = currently in Market.
          IconButton(
            icon: liveSet.isPublic
                ? const Icon(Icons.unpublished_outlined)
                : const Icon(Icons.storefront_outlined),
            tooltip: liveSet.isPublic
                ? l10n.tooltipRemoveFromMarket
                : l10n.tooltipOfferInMarket,
            onPressed: _isPublishing
                ? null
                : () => liveSet.isPublic
                    ? _removeFromMarket(liveSet)
                    : _offerInMarket(liveSet),
          ),
          IconButton(
            icon: const Icon(Icons.download_outlined),
            tooltip: l10n.tooltipExportSet,
            onPressed: _isExporting ? null : () => _exportSet(liveSet),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: l10n.tooltipDeleteSet,
            onPressed: _isDeleting ? null : _confirmDelete,
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: l10n.tooltipEditSet,
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => SetFormScreen(cardSet: liveSet),
              ),
            ),
          ),
          // Quick-study shortcut — bypasses the Study tab set picker for this set.
          IconButton(
            icon: const Icon(Icons.play_circle_outline),
            tooltip: l10n.tooltipStudyThisSet,
            onPressed: _study,
          ),
          const HelpMenuButton(HelpContext.sets),
        ],
      ),
      body: body,
      floatingActionButton: FloatingActionButton(
        heroTag: 'addCards',
        onPressed: _showCardPicker,
        tooltip: l10n.tooltipAddCards,
        child: const Icon(Icons.add),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Empty state — shown when the set has no cards yet.
// ---------------------------------------------------------------------------
class _EmptyState extends StatelessWidget {
  final VoidCallback onAddCards;
  const _EmptyState({required this.onAddCards});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.style_outlined,
                size: 80,
                color: Theme.of(context).colorScheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(context.l10n.titleNoCardsYet,
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              context.l10n.messageNoCardsHint,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onAddCards,
              icon: const Icon(Icons.add),
              label: Text(context.l10n.actionAddCards),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Flash card row inside the set detail list.
// ---------------------------------------------------------------------------
class _FlashCardInSetTile extends StatelessWidget {
  final FlashCard card;
  // Optional reorder handle rendered at the trailing edge (set detail only).
  final Widget? dragHandle;
  const _FlashCardInSetTile({required this.card, this.dragHandle});

  @override
  Widget build(BuildContext context) {
    final chip = card.tags.isNotEmpty
        ? Chip(
            label: Text(card.tags.first),
            visualDensity: VisualDensity.compact,
          )
        : null;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        leading: const Icon(Icons.style_outlined),
        title: Text(card.primaryWord),
        subtitle: Text(card.translation),
        trailing: _tileTrailing(chip, dragHandle),
      ),
    );
  }
}

// Combines an optional tag chip with an optional drag handle for a tile's
// trailing slot. Returns null when neither is present.
Widget? _tileTrailing(Widget? chip, Widget? dragHandle) {
  if (chip == null && dragHandle == null) return null;
  if (dragHandle == null) return chip;
  if (chip == null) return dragHandle;
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: [chip, const SizedBox(width: 4), dragHandle],
  );
}

// ---------------------------------------------------------------------------
// Workbook card row inside the set detail list.
// ---------------------------------------------------------------------------
class _WorkbookCardInSetTile extends StatelessWidget {
  final WorkbookCard card;
  // Optional reorder handle rendered at the trailing edge (set detail only).
  final Widget? dragHandle;
  const _WorkbookCardInSetTile({required this.card, this.dragHandle});

  @override
  Widget build(BuildContext context) {
    final chip = card.tags.isNotEmpty
        ? Chip(
            label: Text(card.tags.first),
            visualDensity: VisualDensity.compact,
          )
        : null;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        leading: const Icon(Icons.book_outlined),
        title: Text(
          card.prompt,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(context.l10n.labelQuestionCount(card.questions.length)),
        trailing: _tileTrailing(chip, dragHandle),
      ),
    );
  }
}

// Three-way result for the "set language?" dialog in _CardPickerSheet.
enum _LangChoice { setAndAdd, addOnly, cancel }

// ---------------------------------------------------------------------------
// _CardPickerSheet — bottom sheet for adding cards to a set.
//
// Shows flash cards and workbook cards in separate sections (each split into
// selectable / word-conflict / already-in-set sub-sections as applicable).
// Flash cards track word conflicts; workbook cards do not have a primaryWord.
// ---------------------------------------------------------------------------
class _CardPickerSheet extends ConsumerStatefulWidget {
  final String setId;
  final String userId;
  // If the set has a language pair, these are pre-populated so the picker
  // defaults to showing only cards in the same language.
  final String? targetLanguage;
  final String? nativeLanguage;
  const _CardPickerSheet({
    required this.setId,
    required this.userId,
    this.targetLanguage,
    this.nativeLanguage,
  });

  @override
  ConsumerState<_CardPickerSheet> createState() => _CardPickerSheetState();
}

class _CardPickerSheetState extends ConsumerState<_CardPickerSheet> {
  // Selected card IDs and their types — needed to batch addCardsToSet by type.
  final Set<String> _selected = {};
  final Map<String, String> _idToType = {};
  bool _isAdding = false;
  final _searchController = TextEditingController();
  String _searchQuery = '';
  // The currently selected language pair filter; null = "All".
  // Initialised to the set's language pair so the picker opens pre-filtered;
  // falls back to null ("All") at render time if that pair has no cards yet.
  (String, String)? _langFilter;

  @override
  void initState() {
    super.initState();
    if (widget.targetLanguage != null && widget.nativeLanguage != null) {
      _langFilter = (widget.targetLanguage!, widget.nativeLanguage!);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Checks language consistency before adding, showing a warning or
  // "set language?" dialog as needed, then delegates to _addSelected().
  Future<void> _checkLanguageAndAdd() async {
    if (_selected.isEmpty) return;
    final l10n = context.l10n;

    // Use already-loaded Riverpod values — ref.read is sync here.
    final allFlash =
        ref.read(userCardsProvider).asData?.value ?? <FlashCard>[];
    final allWorkbook =
        ref.read(userWorkbookCardsProvider).asData?.value ?? <WorkbookCard>[];

    // Collect distinct language pairs from the selection.
    // Cards with no language metadata are neutral — counted separately so the
    // dialog can be transparent about mixed language/no-language selections.
    final selectedPairs = <(String, String)>{};
    int neutralCount = 0;
    for (final c in allFlash) {
      if (_selected.contains(c.id)) {
        if (c.targetLanguage != null && c.nativeLanguage != null) {
          selectedPairs.add((c.targetLanguage!, c.nativeLanguage!));
        } else {
          neutralCount++;
        }
      }
    }
    for (final c in allWorkbook) {
      if (_selected.contains(c.id)) {
        if (c.targetLanguage != null && c.nativeLanguage != null) {
          selectedPairs.add((c.targetLanguage!, c.nativeLanguage!));
        } else {
          neutralCount++;
        }
      }
    }

    // No language metadata on any selected card — nothing to check.
    if (selectedPairs.isEmpty) {
      await _addSelected();
      return;
    }

    // Effective language of the set: the declared pair only.
    // A set with no declared pair always goes to the "offer / warn" path below,
    // even if it already contains cards with language metadata.
    final (String, String)? setLang =
        (widget.targetLanguage != null && widget.nativeLanguage != null)
            ? (widget.targetLanguage!, widget.nativeLanguage!)
            : null;

    if (setLang == null) {
      // Set has no effective language yet.
      if (selectedPairs.length == 1) {
        // All selected cards share one pair — offer to adopt it as the set's language.
        final pair = selectedPairs.first;
        final label =
            '${pair.$1.toUpperCase()} → ${pair.$2.toUpperCase()}';
        final choice = await showDialog<_LangChoice>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(l10n.titleSetLanguage),
            content: Text(l10n.messageSetLanguagePrompt(neutralCount, label)),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(_LangChoice.cancel),
                child: Text(l10n.labelCancel),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(_LangChoice.addOnly),
                child: Text(l10n.actionAddOnly),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(_LangChoice.setAndAdd),
                child: Text(l10n.actionSetLanguageAndAdd),
              ),
            ],
          ),
        );
        if (!mounted) return;
        if (choice == null || choice == _LangChoice.cancel) return;
        if (choice == _LangChoice.setAndAdd) {
          final currentSet = ref.read(setByIdProvider(widget.setId));
          if (currentSet != null) {
            await ref.read(cardSetRepositoryProvider).updateSet(
                  currentSet.copyWith(
                    targetLanguage: pair.$1,
                    nativeLanguage: pair.$2,
                  ),
                );
          }
        }
      } else {
        // Selected cards span multiple pairs — warn.
        final proceed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(l10n.titleMixedLanguages),
            content: Text(l10n.messageMixedLanguages),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: Text(l10n.labelCancel),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: Text(l10n.actionAddAnyway),
              ),
            ],
          ),
        );
        if (!mounted || proceed != true) return;
      }
    } else {
      // Set has an effective language — warn if any selected card conflicts.
      final hasConflict = selectedPairs.any((p) => p != setLang);
      if (hasConflict) {
        final setLabel =
            '${setLang.$1.toUpperCase()} → ${setLang.$2.toUpperCase()}';
        final proceed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(l10n.titleDifferentLanguage),
            content: Text(l10n.messageDifferentLanguage(setLabel)),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: Text(l10n.labelCancel),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: Text(l10n.actionAddAnyway),
              ),
            ],
          ),
        );
        if (!mounted || proceed != true) return;
      }
    }

    await _addSelected();
  }

  Future<void> _addSelected() async {
    if (_selected.isEmpty) return;
    setState(() => _isAdding = true);
    try {
      final repo = ref.read(cardSetRepositoryProvider);

      // Batch by type — addCardsToSet takes a single cardType per call.
      final flashIds = _selected
          .where((id) => _idToType[id] == AppConstants.cardTypeFlashcard)
          .toList();
      final workbookIds = _selected
          .where((id) => _idToType[id] == AppConstants.cardTypeWorkbook)
          .toList();

      if (flashIds.isNotEmpty) {
        await repo.addCardsToSet(
          setId: widget.setId,
          cardIds: flashIds,
          userId: widget.userId,
          cardType: AppConstants.cardTypeFlashcard,
        );
      }
      if (workbookIds.isNotEmpty) {
        await repo.addCardsToSet(
          setId: widget.setId,
          cardIds: workbookIds,
          userId: widget.userId,
          cardType: AppConstants.cardTypeWorkbook,
        );
      }

      if (mounted) Navigator.of(context).pop();
      // Do NOT reset _isAdding on success: the widget is still mounted
      // during the exit animation and resetting it would briefly flip the
      // picker back to the "all cards already in this set" state.
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.errorFailedLoadCards)),
        );
        setState(() => _isAdding = false); // re-enable button for retry
      }
    }
  }

  void _toggle(String cardId, String cardType, bool? checked) {
    setState(() {
      if (checked == true) {
        _selected.add(cardId);
        _idToType[cardId] = cardType;
      } else {
        _selected.remove(cardId);
        _idToType.remove(cardId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final allFlashAsync = ref.watch(userCardsProvider);
    final allWorkbookAsync = ref.watch(userWorkbookCardsProvider);
    final cardIdsInSet =
        ref.watch(cardIdsInSetProvider(widget.setId)).asData?.value.toSet() ??
            {};

    final isLoading = allFlashAsync.isLoading || allWorkbookAsync.isLoading;
    final hasError = allFlashAsync.hasError || allWorkbookAsync.hasError;

    // Eagerly extract card lists so the language chips can count per-pair.
    final allFlash = allFlashAsync.asData?.value ?? <FlashCard>[];
    final allWorkbook = allWorkbookAsync.asData?.value ?? <WorkbookCard>[];

    // Count how many cards exist for each (target, native) language pair.
    final pairCounts = <(String, String), int>{};
    for (final c in allFlash) {
      if (c.targetLanguage != null && c.nativeLanguage != null) {
        final key = (c.targetLanguage!, c.nativeLanguage!);
        pairCounts[key] = (pairCounts[key] ?? 0) + 1;
      }
    }
    for (final c in allWorkbook) {
      if (c.targetLanguage != null && c.nativeLanguage != null) {
        final key = (c.targetLanguage!, c.nativeLanguage!);
        pairCounts[key] = (pairCounts[key] ?? 0) + 1;
      }
    }

    // Set's pair goes first (if it exists in the pool), then by card count desc.
    final setsPair = (widget.targetLanguage != null && widget.nativeLanguage != null)
        ? (widget.targetLanguage!, widget.nativeLanguage!)
        : null;
    final sortedPairs = pairCounts.keys.toList()
      ..sort((a, b) {
        if (a == setsPair) return -1;
        if (b == setsPair) return 1;
        return pairCounts[b]!.compareTo(pairCounts[a]!);
      });

    // Fall back to "All" when the saved filter pair is no longer in the pool.
    final effectiveLangFilter =
        (_langFilter != null && pairCounts.containsKey(_langFilter))
            ? _langFilter
            : null;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      builder: (ctx, scrollController) => Column(
        children: [
          // Drag handle.
          const SizedBox(height: 8),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header row with title and Add button.
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Text(l10n.actionAddCards,
                    style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                FilledButton(
                  onPressed: _selected.isEmpty || _isAdding
                      ? null
                      : _checkLanguageAndAdd,
                  child: _isAdding
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : Text(_selected.isEmpty
                          ? l10n.actionAdd
                          : l10n.actionAddCount(_selected.length)),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Language filter chips — all pairs present in the pool, scrollable.
          // The set's own pair (if any) is sorted first; others by card count.
          if (sortedPairs.isNotEmpty)
            SizedBox(
              height: 44,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    FilterChip(
                      label: Text(l10n.labelAll),
                      selected: effectiveLangFilter == null,
                      onSelected: (_) => setState(() => _langFilter = null),
                      visualDensity: VisualDensity.compact,
                    ),
                    for (final pair in sortedPairs) ...[
                      const SizedBox(width: 8),
                      FilterChip(
                        label: Text(
                          '${pair.$1.toUpperCase()} → ${pair.$2.toUpperCase()}',
                        ),
                        selected: effectiveLangFilter == pair,
                        onSelected: (_) =>
                            setState(() => _langFilter = pair),
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ],
                ),
              ),
            ),

          // Search bar.
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 2),
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
                        }),
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                isDense: true,
              ),
              onChanged: (v) => setState(() => _searchQuery = v.trim()),
            ),
          ),

          // Card list.
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : hasError
                    ? Center(child: Text(l10n.errorFailedLoadCards))
                    : _buildList(
                        context,
                        scrollController,
                        allFlash,
                        allWorkbook,
                        cardIdsInSet,
                        effectiveLangFilter,
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildList(
    BuildContext context,
    ScrollController scrollController,
    List<FlashCard> allFlash,
    List<WorkbookCard> allWorkbook,
    Set<String> cardIdsInSet,
    (String, String)? langFilter,
  ) {
    final l10n = context.l10n;

    // Apply diacritic-forgiving search filter to both card types.
    final normQuery = _searchQuery.isEmpty
        ? ''
        : AppHelpers.normalizeSearch(_searchQuery);
    var filteredFlash = normQuery.isEmpty
        ? allFlash
        : allFlash
            .where((c) =>
                AppHelpers.normalizeSearch(c.primaryWord).contains(normQuery) ||
                AppHelpers.normalizeSearch(c.translation).contains(normQuery) ||
                c.tags.any(
                    (t) => AppHelpers.normalizeSearch(t).contains(normQuery)))
            .toList();
    var filteredWorkbook = normQuery.isEmpty
        ? allWorkbook
        : allWorkbook
            .where((c) =>
                AppHelpers.normalizeSearch(c.prompt).contains(normQuery))
            .toList();

    // Language filter — restrict to cards matching the selected pair.
    // Cards with no language metadata are excluded when a filter is active.
    if (langFilter != null) {
      filteredFlash = filteredFlash
          .where((c) =>
              c.targetLanguage == langFilter.$1 &&
              c.nativeLanguage == langFilter.$2)
          .toList();
      filteredWorkbook = filteredWorkbook
          .where((c) =>
              c.targetLanguage == langFilter.$1 &&
              c.nativeLanguage == langFilter.$2)
          .toList();
    }

    // Flash card buckets (based on filtered list).
    final flashInSet =
        filteredFlash.where((c) => cardIdsInSet.contains(c.id)).toList();
    final inSetWords = flashInSet.map((c) => c.primaryWord).toSet();
    final flashNotInSet = filteredFlash
        .where((c) =>
            !cardIdsInSet.contains(c.id) &&
            !inSetWords.contains(c.primaryWord))
        .toList();
    // Different card, same word — can't add without creating a duplicate word.
    final flashWordConflict = filteredFlash
        .where((c) =>
            !cardIdsInSet.contains(c.id) &&
            inSetWords.contains(c.primaryWord))
        .toList();

    // Workbook card buckets — no word conflict possible.
    final workbookNotInSet =
        filteredWorkbook.where((c) => !cardIdsInSet.contains(c.id)).toList();
    final workbookInSet =
        filteredWorkbook.where((c) => cardIdsInSet.contains(c.id)).toList();

    final hasAnythingSelectable =
        flashNotInSet.isNotEmpty || workbookNotInSet.isNotEmpty;

    // Guard against a false "all added" flash: Firestore's local cache can
    // update the stream before addCardsToSet resolves and closes the sheet.
    if (!hasAnythingSelectable && _isAdding) {
      return const Center(child: CircularProgressIndicator());
    }

    // Library is genuinely empty (not a search result — check unfiltered).
    if (allFlash.isEmpty && allWorkbook.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            l10n.messageNoCardsYetTab,
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    // Active search produced no matches at all.
    if (normQuery.isNotEmpty &&
        filteredFlash.isEmpty &&
        filteredWorkbook.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            l10n.messageNoCardsMatchSearch,
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    // No search active and every card is already in the set.
    if (normQuery.isEmpty && !hasAnythingSelectable) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            l10n.messageAllCardsInSet,
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return ListView(
      controller: scrollController,
      children: [
        // ── Selectable flash cards ──────────────────────────────────────────
        if (flashNotInSet.isNotEmpty) ...[
          _SectionHeader(label: l10n.labelSectionFlashCards, icon: Icons.style_outlined),
          ...flashNotInSet.map(
            (card) => CheckboxListTile(
              value: _selected.contains(card.id),
              onChanged: (v) =>
                  _toggle(card.id, AppConstants.cardTypeFlashcard, v),
              secondary: const Icon(Icons.style_outlined),
              title: Text(card.primaryWord),
              subtitle: Text(card.translation),
            ),
          ),
        ],

        // Flash cards blocked by word conflict.
        if (flashWordConflict.isNotEmpty) ...[
          const Divider(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text(
              l10n.labelDuplicateWordInSet,
              style: Theme.of(context)
                  .textTheme
                  .labelMedium
                  ?.copyWith(color: Theme.of(context).colorScheme.outline),
            ),
          ),
          ...flashWordConflict.map(
            (card) => ListTile(
              enabled: false,
              leading: const Icon(Icons.style_outlined),
              title: Text(card.primaryWord),
              subtitle: Text(card.translation),
              trailing: const Icon(Icons.block_outlined),
            ),
          ),
        ],

        // Flash cards already in set (reference only).
        if (flashInSet.isNotEmpty) ...[
          const Divider(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text(
              l10n.labelAlreadyInSet,
              style: Theme.of(context)
                  .textTheme
                  .labelMedium
                  ?.copyWith(color: Theme.of(context).colorScheme.outline),
            ),
          ),
          ...flashInSet.map(
            (card) => ListTile(
              enabled: false,
              leading: const Icon(Icons.style_outlined),
              title: Text(card.primaryWord),
              subtitle: Text(card.translation),
              trailing: const Icon(Icons.check),
            ),
          ),
        ],

        // ── Selectable workbook cards ───────────────────────────────────────
        if (workbookNotInSet.isNotEmpty) ...[
          if (flashNotInSet.isNotEmpty || flashWordConflict.isNotEmpty || flashInSet.isNotEmpty)
            const Divider(),
          _SectionHeader(label: l10n.labelSectionWorkbookCards, icon: Icons.book_outlined),
          ...workbookNotInSet.map(
            (card) => CheckboxListTile(
              value: _selected.contains(card.id),
              onChanged: (v) =>
                  _toggle(card.id, AppConstants.cardTypeWorkbook, v),
              secondary: const Icon(Icons.book_outlined),
              title: Text(
                card.prompt,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(l10n.labelQuestionCount(card.questions.length)),
            ),
          ),
        ],

        // Workbook cards already in set (reference only).
        if (workbookInSet.isNotEmpty) ...[
          const Divider(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text(
              l10n.labelAlreadyInSet,
              style: Theme.of(context)
                  .textTheme
                  .labelMedium
                  ?.copyWith(color: Theme.of(context).colorScheme.outline),
            ),
          ),
          ...workbookInSet.map(
            (card) => ListTile(
              enabled: false,
              leading: const Icon(Icons.book_outlined),
              title: Text(
                card.prompt,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(l10n.labelQuestionCount(card.questions.length)),
              trailing: const Icon(Icons.check),
            ),
          ),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Thin section header with an icon — used to label Flash / Workbook sections.
// ---------------------------------------------------------------------------
class _SectionHeader extends StatelessWidget {
  final String label;
  final IconData icon;
  const _SectionHeader({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Theme.of(context).colorScheme.outline),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context)
                .textTheme
                .labelMedium
                ?.copyWith(color: Theme.of(context).colorScheme.outline),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Bottom sheet shown when the user taps "Offer in Market".
// Returns true when the user confirms publishing, null/false on dismiss.
// The options list is intentionally extensible: future acquisition types
// (subscriptions, pricing) will appear here alongside Allow Clone.
// ---------------------------------------------------------------------------
class _MarketPublishSheet extends StatefulWidget {
  final CardSet cardSet;
  const _MarketPublishSheet({required this.cardSet});

  @override
  State<_MarketPublishSheet> createState() => _MarketPublishSheetState();
}

class _MarketPublishSheetState extends State<_MarketPublishSheet> {
  // Allow Clone is the only option in this phase — on and not yet toggleable.
  // Kept as state so future options can be wired in without restructuring.
  final bool _allowClone = true;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar.
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            Text(l10n.titleOfferInMarket, style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              l10n.messageOfferInMarketDescription(widget.cardSet.name),
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 20),

            // Options — each future acquisition type appears here as a tile.
            Text(l10n.titleOptions, style: theme.textTheme.titleSmall),
            const SizedBox(height: 4),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.labelAllowClone),
              subtitle: Text(l10n.messageAllowCloneSubtitle),
              value: _allowClone,
              // Not yet user-toggleable — the only supported type in this phase.
              onChanged: null,
            ),

            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: Text(l10n.labelCancel),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    icon: const Icon(Icons.storefront_outlined),
                    label: Text(l10n.actionOfferInMarket),
                    onPressed: () => Navigator.of(context).pop(true),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
