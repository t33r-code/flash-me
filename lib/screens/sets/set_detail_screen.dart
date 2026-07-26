import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flash_me/l10n/app_localizations.dart';
import 'package:flash_me/models/card_set.dart';
import 'package:flash_me/widgets/help_menu_button.dart';
import 'package:flash_me/models/flash_card.dart';
import 'package:flash_me/models/set_card.dart';
import 'package:flash_me/models/workbook_card.dart';
import 'package:flash_me/providers/auth_provider.dart';
import 'package:flash_me/providers/card_provider.dart';
import 'package:flash_me/providers/card_set_provider.dart';
import 'package:flash_me/providers/workbook_card_provider.dart';
import 'package:flash_me/utils/extensions.dart';
import 'package:flash_me/utils/helpers.dart';
import 'package:flash_me/utils/layout_breakpoints.dart';
import 'package:flash_me/utils/selection.dart';
import 'package:flash_me/widgets/add_cards_to_set.dart';
import 'package:flash_me/widgets/bulk_card_actions.dart';
import 'package:flash_me/widgets/keyboard_actions.dart';
import 'package:flash_me/widgets/context_menu.dart';
import 'package:flash_me/widgets/set_actions.dart';
import 'package:flash_me/utils/set_ordering.dart';
import 'package:flash_me/screens/cards/card_form_screen.dart';
import 'package:flash_me/screens/cards/workbook_card_form_screen.dart';
import 'package:flash_me/utils/constants.dart';

// ---------------------------------------------------------------------------
// _PaneEdit — what the wide detail pane is showing instead of the card list
// (#259). `card == null` means creating a new card of that type; non-null
// means editing that existing card. Each variant owns its own GlobalKey so the
// pane's toolbar Save button can invoke the embedded editor's save() directly.
// ---------------------------------------------------------------------------
sealed class _PaneEdit {
  const _PaneEdit();
}

class _FlashPaneEdit extends _PaneEdit {
  final FlashCard? card;
  // Non-null for a Clone (#231): card stays null (new-card path), seeded from
  // this instead.
  final FlashCard? cloneFrom;
  final GlobalKey<CardEditorBodyState> key = GlobalKey();
  _FlashPaneEdit({this.card, this.cloneFrom});
}

class _WorkbookPaneEdit extends _PaneEdit {
  final WorkbookCard? card;
  // Non-null for a Clone (#274): card stays null (new-card path), seeded from
  // this instead.
  final WorkbookCard? cloneFrom;
  final GlobalKey<WorkbookEditorBodyState> key = GlobalKey();
  _WorkbookPaneEdit({this.card, this.cloneFrom});
}

// ---------------------------------------------------------------------------
// SetDetailScreen — live card list for a set with add/remove membership.
// ---------------------------------------------------------------------------
class SetDetailScreen extends ConsumerStatefulWidget {
  final CardSet
  cardSet; // initial value; AppBar title updates via setByIdProvider
  // When hosted in a pane (multi-pane #236) rather than pushed full-screen, the
  // host provides onExit so deleting the set clears the pane selection instead
  // of popping a route. Null in the pushed/full-screen case (pops as usual).
  final VoidCallback? onExit;
  const SetDetailScreen({super.key, required this.cardSet, this.onExit});

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

  // What the wide detail pane is showing instead of the card list (#259).
  // Only ever set when widget.onExit != null (i.e. hosted in the pane) —
  // narrow/full-screen usage never touches this and always uses the pushed
  // full-screen editor instead.
  _PaneEdit? _paneEdit;
  bool _isPaneSaving = false;

  // cardId of the row currently hovered by a mouse pointer, driving
  // hover-reveal of the row quick-actions (#260). Only tracked in pane mode —
  // touch/narrow layouts show the actions unconditionally (no hover concept).
  String? _hoveredCardId;

  // Wide only (#234): whether the right-side library drawer is open. Cards are
  // dragged from it onto the card list, or added via its own button.
  bool _libraryOpen = false;

  // Multi-select over the set's cards (#238 part 2). Same model as the card
  // library. While selecting, drag-to-reorder and swipe-to-remove come off the
  // rows (see the itemBuilder) so gestures can't fight a checkbox tap.
  final _selection = SelectionModel();
  bool _isBulkBusy = false;
  // Card ids in display order + their types, refreshed each build so Shift
  // ranges and Select all follow what's on screen.
  List<String> _orderedIds = [];
  Map<String, String> _typeById = {};

  void _exitSelection() => setState(_selection.exit);

  Map<String, String> _selectedIdToType() => {
    for (final id in _selection.selected)
      if (_typeById[id] != null) id: _typeById[id]!,
  };

  // Row tap: modifier-click starts a selection while browsing; in selection
  // mode taps toggle and Shift extends the range.
  void _onTapRow(String cardId) {
    final keys = HardwareKeyboard.instance;
    final multi = keys.isControlPressed || keys.isMetaPressed;
    final range = keys.isShiftPressed;

    if (!_selection.mode) {
      // A plain tap outside selection mode stays a no-op — rows are opened by
      // double-click (#259) or the row's Edit action (#260).
      if (multi || range) setState(() => _selection.enterWith(cardId));
      return;
    }
    setState(() {
      if (range) {
        _selection.extendTo(cardId, _orderedIds);
      } else {
        _selection.toggle(cardId);
      }
    });
  }

  void _onLongPressRow(String cardId) {
    if (_selection.mode) return;
    setState(() => _selection.enterWith(cardId));
  }

  // Bulk remove-from-set: one confirmation, then drop each join doc. The cards
  // themselves are untouched — deletion stays a Cards-tab capability (#260).
  Future<void> _bulkRemoveFromSet() async {
    final l10n = context.l10n;
    final ids = _selection.selected.toList();
    if (ids.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      // Enter confirms the primary action (#235); Esc / tap-away cancels.
      builder: (ctx) => KeyboardActions(
        onConfirm: () => Navigator.of(ctx).pop(true),
        child: AlertDialog(
          title: Text(l10n.titleRemoveFromSet),
          content: Text(l10n.messageRemoveFromSetConfirm(ids.length)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(l10n.labelCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(l10n.actionRemove),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || !mounted) return;

    final uid = ref.read(authStateProvider).asData?.value ?? '';
    final repo = ref.read(cardSetRepositoryProvider);
    setState(() => _isBulkBusy = true);
    try {
      for (final id in ids) {
        await repo.removeCardFromSet(
          setId: widget.cardSet.id,
          cardId: id,
          userId: uid,
        );
      }
      if (!mounted) return;
      setState(() => _isBulkBusy = false);
      _exitSelection();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.messageCardsRemovedFromSet(ids.length))),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _isBulkBusy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.errorFailedRemoveCardsFromSet)),
      );
    }
  }

  // Bulk tag / language reuse the same shared dialogs as the card library.
  Future<void> _bulkTag() => _runBulkEdit(bulkEditTags);
  Future<void> _bulkLanguage() => _runBulkEdit(bulkEditLanguage);

  Future<void> _runBulkEdit(
    Future<bool> Function(
      BuildContext,
      WidgetRef, {
      required Map<String, String> idToType,
    })
    action,
  ) async {
    final l10n = context.l10n;
    final idToType = _selectedIdToType();
    if (idToType.isEmpty) return;
    setState(() => _isBulkBusy = true);
    try {
      final applied = await action(context, ref, idToType: idToType);
      if (!mounted) return;
      setState(() => _isBulkBusy = false);
      if (applied) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.messageCardsUpdated(idToType.length))),
        );
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _isBulkBusy = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.errorFailedUpdateCards)));
    }
  }

  // Contextual toolbar while selecting: count + the set-scoped bulk actions.
  // No Delete (Cards tab only, #260) and no Add-to-set (the library's job).
  AppBar _selectionAppBar(AppLocalizations l10n) {
    final enabled = _selection.isNotEmpty && !_isBulkBusy;
    final allSelected =
        _orderedIds.isNotEmpty && _selection.selected.containsAll(_orderedIds);
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.close),
        tooltip: l10n.tooltipExitSelection,
        onPressed: _isBulkBusy ? null : _exitSelection,
      ),
      title: Text(l10n.labelSelectedCount(_selection.length)),
      actions: [
        IconButton(
          icon: const Icon(Icons.select_all),
          tooltip: allSelected ? l10n.actionDeselectAll : l10n.actionSelectAll,
          onPressed: _isBulkBusy
              ? null
              : () => setState(() => _selection.toggleSelectAll(_orderedIds)),
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
          icon: const Icon(Icons.remove_circle_outline),
          tooltip: l10n.tooltipRemoveFromSet,
          onPressed: enabled ? _bulkRemoveFromSet : null,
        ),
      ],
    );
  }

  // Drop handler for cards dragged from the library drawer onto the set list.
  // Appends them (addCardsToSet) after the shared #210 language checks.
  Future<void> _dropCards(Map<String, String> idToType) async {
    final live = ref.read(setByIdProvider(widget.cardSet.id)) ?? widget.cardSet;
    final uid = ref.read(authStateProvider).asData?.value ?? '';
    try {
      await addCardsWithLanguageCheck(
        context,
        ref,
        setId: widget.cardSet.id,
        userId: uid,
        setTarget: live.targetLanguage,
        setNative: live.nativeLanguage,
        idToType: idToType,
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.errorFailedAddCardToSet)),
        );
      }
    }
  }

  void _exitPaneEdit() {
    if (mounted) setState(() => _paneEdit = null);
  }

  void _startNewCardInPane(String cardType) {
    setState(
      () => _paneEdit = cardType == AppConstants.cardTypeWorkbook
          ? _WorkbookPaneEdit()
          : _FlashPaneEdit(),
    );
  }

  void _editFlashCardInPane(FlashCard card) {
    setState(() => _paneEdit = _FlashPaneEdit(card: card));
  }

  void _editWorkbookCardInPane(WorkbookCard card) {
    setState(() => _paneEdit = _WorkbookPaneEdit(card: card));
  }

  void _cloneFlashCardInPane(FlashCard card) {
    setState(() => _paneEdit = _FlashPaneEdit(cloneFrom: card));
  }

  void _cloneWorkbookCardInPane(WorkbookCard card) {
    setState(() => _paneEdit = _WorkbookPaneEdit(cloneFrom: card));
  }

  // Clone entry point (#231 Flash Cards, #274 Workbook Cards). Mirrors
  // _editCardRow's wide→pane / narrow→full-screen split. Cloning from within
  // a set always links the new card to the current (live) set — the whole
  // point of cloning here rather than from the Cards tab, where the clone
  // stays unattached.
  void _cloneCardRow(
    ({String cardId, FlashCard? flash, WorkbookCard? workbook}) entry,
  ) {
    if (widget.onExit != null) {
      if (entry.flash != null) {
        _cloneFlashCardInPane(entry.flash!);
      } else {
        _cloneWorkbookCardInPane(entry.workbook!);
      }
      return;
    }
    final live = ref.read(setByIdProvider(widget.cardSet.id)) ?? widget.cardSet;
    if (entry.flash != null) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) =>
              CardFormScreen(cloneFrom: entry.flash, parentSet: live),
        ),
      );
    } else {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => WorkbookCardFormScreen(
            cloneFrom: entry.workbook,
            parentSet: live,
          ),
        ),
      );
    }
  }

  // Right-click menu for a card row (#237) — the same two actions as the
  // hover-reveal quick-actions (#260), just reachable without hovering first.
  List<ContextMenuAction> _rowContextActions(
    ({String cardId, FlashCard? flash, WorkbookCard? workbook}) entry,
    SetCard link,
  ) {
    final l10n = context.l10n;
    return [
      ContextMenuAction(
        icon: Icons.edit_outlined,
        label: l10n.tooltipEditCard,
        onSelected: () => _editCardRow(entry),
      ),
      // Clone (#231 Flash, #274 Workbook).
      ContextMenuAction(
        icon: Icons.copy_outlined,
        label: l10n.tooltipCloneCard,
        onSelected: () => _cloneCardRow(entry),
      ),
      ContextMenuAction(
        icon: Icons.remove_circle_outline,
        label: l10n.tooltipRemoveFromSet,
        onSelected: () => _removeCard(link),
      ),
    ];
  }

  // Edit entry point shared by the row's Edit quick-action (#260) and
  // double-tap (#259): wide (hosted in the pane) edits in place; narrow has no
  // in-place editing surface, so it pushes the full-screen editor instead —
  // the same split used throughout this screen (see _addToSet).
  void _editCardRow(
    ({String cardId, FlashCard? flash, WorkbookCard? workbook}) entry,
  ) {
    if (widget.onExit != null) {
      if (entry.flash != null) {
        _editFlashCardInPane(entry.flash!);
      } else {
        _editWorkbookCardInPane(entry.workbook!);
      }
    } else if (entry.flash != null) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => CardFormScreen(card: entry.flash)),
      );
    } else {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => WorkbookCardFormScreen(card: entry.workbook),
        ),
      );
    }
  }

  String _paneEditTitle(AppLocalizations l10n) => switch (_paneEdit) {
    _FlashPaneEdit(cloneFrom: != null) => l10n.titleCloneCard,
    _FlashPaneEdit(card: null) => l10n.titleNewCard,
    _FlashPaneEdit() => l10n.titleEditCard,
    _WorkbookPaneEdit(cloneFrom: != null) => l10n.titleCloneCard,
    _WorkbookPaneEdit(card: null) => l10n.titleNewWorkbookCard,
    _WorkbookPaneEdit() => l10n.titleEditWorkbookCard,
    null => '',
  };

  // Invoked by the pane's toolbar Save button — dispatches to whichever
  // embedded editor is currently showing.
  void _savePaneEdit() {
    switch (_paneEdit) {
      case _FlashPaneEdit(:final key):
        key.currentState?.save();
      case _WorkbookPaneEdit(:final key):
        key.currentState?.save();
      case null:
        break;
    }
  }

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
      await ref
          .read(cardSetRepositoryProvider)
          .reorderCards(
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
    setState(() => _isDeleting = true);
    final deleted = await deleteSetWithConfirm(context, ref, widget.cardSet);
    if (!mounted) return;
    setState(() => _isDeleting = false);
    if (!deleted) return;
    // In a pane, clear the host's selection; full-screen, pop the route.
    if (widget.onExit != null) {
      widget.onExit!();
    } else {
      Navigator.of(context).pop();
    }
  }

  // Awaits the Firestore delete and returns true/false for confirmDismiss.
  // Using confirmDismiss (rather than onDismissed) ensures the stream has
  // already updated before Dismissible completes its animation, avoiding
  // a race where both the stream and Dismissible try to remove the same
  // widget simultaneously, which causes a brief ErrorWidget flash.
  Future<bool> _removeCard(SetCard link) async {
    final uid = ref.read(authStateProvider).asData?.value ?? '';
    try {
      await ref
          .read(cardSetRepositoryProvider)
          .removeCardFromSet(
            setId: widget.cardSet.id,
            cardId: link.cardId,
            userId: uid,
          );
      // Offer to undo — re-links the card at its prior position.
      if (mounted) {
        final messenger = ScaffoldMessenger.of(context)..clearSnackBars();
        messenger.showSnackBar(
          SnackBar(
            content: Text(context.l10n.messageCardRemovedFromSet),
            action: SnackBarAction(
              label: context.l10n.actionUndo,
              onPressed: () => _undoRemove(link),
            ),
          ),
        );
      }
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

  // Re-links a just-removed card at its original position (undo).
  Future<void> _undoRemove(SetCard link) async {
    final uid = ref.read(authStateProvider).asData?.value ?? '';
    try {
      await ref
          .read(cardSetRepositoryProvider)
          .addCardToSet(
            setId: widget.cardSet.id,
            cardId: link.cardId,
            userId: uid,
            cardType: link.cardType,
            position: link.position,
          );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.errorFailedAddCardToSet)),
        );
      }
    }
  }

  // Exports the set as a self-contained ZIP archive.
  Future<void> _exportSet(CardSet liveSet) async {
    setState(() => _isExporting = true);
    await exportSetWithProgress(context, ref, liveSet);
    if (mounted) setState(() => _isExporting = false);
  }

  // Toggles market-publish state (offer / remove), with the acquisitionCount
  // guard and "Offer in Market" sheet handled by the shared implementation.
  Future<void> _toggleMarketPublish(CardSet liveSet) async {
    setState(() => _isPublishing = true);
    await toggleMarketPublish(context, ref, liveSet);
    if (mounted) setState(() => _isPublishing = false);
  }

  // Navigates to the study setup screen for this set.
  void _study() => openStudySetup(context, ref, widget.cardSet);

  // Bottom sheet: create a new card in this set (flash/workbook, seeded with the
  // set so it links on save — #233) or add existing cards via the picker.
  void _addToSet() {
    final l10n = context.l10n;
    final set = ref.read(setByIdProvider(widget.cardSet.id)) ?? widget.cardSet;
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
                l10n.titleAddToSet,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.style_outlined),
              title: Text(l10n.labelFlashCard),
              subtitle: Text(l10n.messageFlashCardSubtitle),
              onTap: () {
                Navigator.of(context).pop();
                // Wide (hosted in the #236 pane): edit in place (#259).
                // Narrow: full-screen editor, as before.
                if (widget.onExit != null) {
                  _startNewCardInPane(AppConstants.cardTypeFlashcard);
                } else {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => CardFormScreen(parentSet: set),
                    ),
                  );
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.book_outlined),
              title: Text(l10n.labelWorkbookCard),
              subtitle: Text(l10n.messageWorkbookCardSubtitle),
              onTap: () {
                Navigator.of(context).pop();
                if (widget.onExit != null) {
                  _startNewCardInPane(AppConstants.cardTypeWorkbook);
                } else {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => WorkbookCardFormScreen(parentSet: set),
                    ),
                  );
                }
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.library_add_outlined),
              title: Text(l10n.actionAddExistingCards),
              onTap: () {
                Navigator.of(context).pop();
                // Wide (pane): open the inline library drawer (#234, drag-in).
                // Narrow: the card-library bottom sheet (tap-to-add).
                if (widget.onExit != null) {
                  setState(() => _libraryOpen = true);
                } else {
                  _showCardPicker();
                }
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // Opens the card library as a bottom sheet (narrow / full-screen).
  Future<void> _showCardPicker() async {
    final uid = ref.read(authStateProvider).asData?.value ?? '';
    // Use the live set so a just-edited language pair is reflected immediately.
    final currentSet =
        ref.read(setByIdProvider(widget.cardSet.id)) ?? widget.cardSet;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _CardLibrary(
        setId: widget.cardSet.id,
        userId: uid,
        targetLanguage: currentSet.targetLanguage,
        nativeLanguage: currentSet.nativeLanguage,
        onClose: () => Navigator.of(context).pop(),
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

    final isLoading =
        linksAsync.isLoading ||
        flashCardsAsync.isLoading ||
        allWorkbookAsync.isLoading;
    final hasError =
        linksAsync.hasError ||
        flashCardsAsync.hasError ||
        allWorkbookAsync.hasError;

    final links = linksAsync.asData?.value ?? [];
    final flashById = {
      for (final c in flashCardsAsync.asData?.value ?? <FlashCard>[]) c.id: c,
    };
    final workbookById = {
      for (final c in allWorkbookAsync.asData?.value ?? <WorkbookCard>[])
        c.id: c,
    };
    final typeById = {for (final l in links) l.cardId: l.cardType};
    // cardId -> join doc, so removal can capture position/type for undo.
    final linkById = {for (final l in links) l.cardId: l};

    // Position order from the stream, then any in-flight optimistic drag order.
    final order = _displayOrder([for (final l in links) l.cardId]);

    // Resolve each ordered id to a renderable tile, skipping ids whose card
    // content hasn't loaded (or was deleted). The join order is authoritative.
    final entries =
        <({String cardId, FlashCard? flash, WorkbookCard? workbook})>[];
    for (final id in order) {
      if (typeById[id] == AppConstants.cardTypeWorkbook) {
        final wb = workbookById[id];
        if (wb != null) entries.add((cardId: id, flash: null, workbook: wb));
      } else {
        final fc = flashById[id];
        if (fc != null) entries.add((cardId: id, flash: fc, workbook: null));
      }
    }
    // Feeds the selection model: display order for Shift ranges / Select all,
    // and the type map so bulk actions can resolve each id's repository.
    _orderedIds = [for (final e in entries) e.cardId];
    _typeById = {
      for (final e in entries)
        e.cardId: e.flash != null
            ? AppConstants.cardTypeFlashcard
            : AppConstants.cardTypeWorkbook,
    };

    Widget body;
    if (isLoading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (hasError) {
      body = Center(child: Text(l10n.errorFailedLoadCards));
    } else if (entries.isEmpty) {
      body = _EmptyState(onAddCards: _addToSet);
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
          final selecting = _selection.mode;

          // While selecting, the drag handle and quick-actions come off the row
          // and the Dismissible is skipped (below), so reorder/swipe gestures
          // can't fight a checkbox tap. Both return when selection mode ends.
          final handle = selecting
              ? null
              : ReorderableDragStartListener(
                  index: i,
                  child: Tooltip(
                    message: ctx.l10n.tooltipDragToReorder,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Icon(
                        Icons.drag_handle,
                        color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                );

          // Edit + Remove-from-set quick-actions (#260). On wide/pane layouts
          // they hover-reveal; on narrow/touch they're always visible (no
          // hover concept, and no other way to reach Edit there).
          final actionsVisible =
              widget.onExit == null || _hoveredCardId == entry.cardId;
          final actions = selecting
              ? null
              : _rowQuickActions(
                  visible: actionsVisible,
                  editTooltip: ctx.l10n.tooltipEditCard,
                  removeTooltip: ctx.l10n.tooltipRemoveFromSet,
                  onEdit: () => _editCardRow(entry),
                  onRemove: () => _removeCard(linkById[entry.cardId]!),
                  // Clone (#231 Flash, #274 Workbook).
                  cloneTooltip: ctx.l10n.tooltipCloneCard,
                  onClone: () => _cloneCardRow(entry),
                );

          // Hover tint (#237) reuses the same _hoveredCardId tracking as the
          // quick-actions reveal below — only ever true on wide/pane, since
          // narrow/touch has no MouseRegion wired up to set it.
          final hovering =
              widget.onExit != null && _hoveredCardId == entry.cardId;

          final tile = entry.flash != null
              ? _FlashCardInSetTile(
                  card: entry.flash!,
                  dragHandle: handle,
                  actions: actions,
                  selectionMode: selecting,
                  selected: _selection.contains(entry.cardId),
                  hovering: hovering,
                  onToggle: () => _onTapRow(entry.cardId),
                )
              : _WorkbookCardInSetTile(
                  card: entry.workbook!,
                  dragHandle: handle,
                  actions: actions,
                  selectionMode: selecting,
                  selected: _selection.contains(entry.cardId),
                  hovering: hovering,
                  onToggle: () => _onTapRow(entry.cardId),
                );

          // Taps live here rather than on the ListTile so the row keeps its
          // no-ripple feel and double-click-to-edit (#259) isn't disturbed.
          // Double-tap is dropped while selecting so taps toggle immediately
          // (with onDoubleTap set, onTap waits out the double-tap timeout).
          // Right-click (#237) is likewise dropped while selecting.
          final tappable = GestureDetector(
            onTap: () => _onTapRow(entry.cardId),
            onLongPress: () => _onLongPressRow(entry.cardId),
            onDoubleTap: (!selecting && widget.onExit != null)
                ? () => _editCardRow(entry)
                : null,
            onSecondaryTapDown: selecting
                ? null
                : (details) => showContextMenu(
                    context,
                    details.globalPosition,
                    _rowContextActions(entry, linkById[entry.cardId]!),
                  ),
            child: tile,
          );

          // Tracks hover for the actions above — wide/pane layouts only;
          // narrow/touch has no hover concept, and there are no hover actions
          // to reveal while selecting.
          final rowContent = (widget.onExit != null && !selecting)
              ? MouseRegion(
                  onEnter: (_) => setState(() => _hoveredCardId = entry.cardId),
                  onExit: (_) => setState(() {
                    if (_hoveredCardId == entry.cardId) {
                      _hoveredCardId = null;
                    }
                  }),
                  child: tappable,
                )
              : tappable;

          // No swipe-to-remove while selecting; the key still has to sit on the
          // outer widget for ReorderableListView either way.
          if (selecting) {
            return KeyedSubtree(key: ValueKey(entry.cardId), child: rowContent);
          }

          // Swipe left to remove the card from this set (works for both types).
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
            confirmDismiss: (_) => _removeCard(linkById[entry.cardId]!),
            child: rowContent,
          );
        },
      );
    }

    // Pane mode (#259): when the wide detail pane is editing a card, the whole
    // toolbar + body morph — set actions swap for Cancel/Save, and the card
    // list is replaced by the embedded editor. Only reachable when
    // widget.onExit != null (see _startNewCardInPane / _editFlashCardInPane).
    final paneEdit = _paneEdit;
    if (paneEdit != null) {
      body = switch (paneEdit) {
        _FlashPaneEdit(:final card, :final cloneFrom, :final key) =>
          CardEditorBody(
            key: key,
            card: card,
            parentSet: liveSet,
            cloneFrom: cloneFrom,
            showFooterActions: false,
            onSaved: _exitPaneEdit,
            onCancel: _exitPaneEdit,
            onSavingChanged: (v) =>
                mounted ? setState(() => _isPaneSaving = v) : null,
          ),
        _WorkbookPaneEdit(:final card, :final cloneFrom, :final key) =>
          WorkbookEditorBody(
            key: key,
            card: card,
            parentSet: liveSet,
            cloneFrom: cloneFrom,
            showFooterActions: false,
            onSaved: _exitPaneEdit,
            onCancel: _exitPaneEdit,
            onSavingChanged: (v) =>
                mounted ? setState(() => _isPaneSaving = v) : null,
          ),
      };
    }

    // Wide layout + library open: show the card list beside an inline library
    // drawer. The list is a DragTarget so cards can be dropped in to add them.
    // Suppressed while the pane is showing a card editor (paneEdit != null).
    if (widget.onExit != null && _libraryOpen && paneEdit == null) {
      final scheme = Theme.of(context).colorScheme;
      final uid = ref.read(authStateProvider).asData?.value ?? '';
      // Capture the card list before reassigning `body`; the DragTarget builder
      // closure must not reference the (about-to-be-Row) `body` or it recurses.
      final listBody = body;
      // The library covering the whole pane — used when there isn't room to dock
      // it beside the list (drag-and-drop isn't possible, but multi-select + Add
      // still works). Also the exit target when the list itself is hidden.
      final fullPaneLibrary = _CardLibrary(
        setId: widget.cardSet.id,
        userId: uid,
        targetLanguage: liveSet.targetLanguage,
        nativeLanguage: liveSet.nativeLanguage,
        asDrawer: true,
        onClose: () => setState(() => _libraryOpen = false),
      );
      body = LayoutBuilder(
        builder: (context, constraints) {
          // Too narrow to dock the drawer beside a usable card list (the roughly
          // square window case): show the library over the whole pane instead of
          // a squeezed side-by-side that would overflow the card rows.
          if (constraints.maxWidth < kLibraryDrawerMinPaneWidth) {
            return fullPaneLibrary;
          }
          return Row(
            children: [
              Expanded(
                child: DragTarget<Map<String, String>>(
                  onAcceptWithDetails: (details) => _dropCards(details.data),
                  builder: (ctx, candidate, rejected) => ColoredBox(
                    // Tint the drop zone while a drag hovers over it.
                    color: candidate.isNotEmpty
                        ? scheme.primaryContainer.withValues(alpha: 0.18)
                        : Colors.transparent,
                    child: listBody,
                  ),
                ),
              ),
              const VerticalDivider(width: 1, thickness: 1),
              SizedBox(width: 320, child: fullPaneLibrary),
            ],
          );
        },
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // Narrow pane: collapse the set-management actions into a ⋮ menu so the
        // AppBar action row can't overflow (only relevant in the wide pane).
        final narrowPane =
            widget.onExit != null &&
            constraints.maxWidth < kSetToolbarOverflowWidth;
        final scaffold = Scaffold(
          appBar: _selection.mode
              ? _selectionAppBar(l10n)
              : AppBar(
                  title: Text(
                    paneEdit == null ? liveSet.name : _paneEditTitle(l10n),
                  ),
                  automaticallyImplyLeading: paneEdit == null,
                  actions: paneEdit != null
                      ? [
                          // Card mode: only Cancel / Save. No delete here — card
                          // deletion is only available from the Cards tab editor.
                          TextButton(
                            onPressed: _isPaneSaving ? null : _exitPaneEdit,
                            child: Text(l10n.labelCancel),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(right: 12),
                            child: FilledButton(
                              onPressed: _isPaneSaving ? null : _savePaneEdit,
                              child: _isPaneSaving
                                  ? const SizedBox(
                                      height: 16,
                                      width: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : Text(l10n.actionSaveChanges),
                            ),
                          ),
                        ]
                      : _setModeActions(l10n, liveSet, narrowPane),
                ),
          body: body,
          // Mobile-only affordance — hidden in the wide pane, where "Add card"
          // is a toolbar action instead (see actions above).
          floatingActionButton: (paneEdit == null && widget.onExit == null)
              ? FloatingActionButton(
                  heroTag: 'addCards',
                  onPressed: _addToSet,
                  tooltip: l10n.tooltipAddCards,
                  child: const Icon(Icons.add),
                )
              : null,
        );

        // Only the pane hosts a card editor that should intercept back
        // navigation (narrow/full-screen editing already has its own pushed
        // route to pop). Known limitation: since MainScreen keeps every tab
        // mounted, this can still apply while the Sets tab isn't the visible
        // one; acceptable for v1.
        if (widget.onExit == null) return scaffold;
        return PopScope(
          canPop: paneEdit == null,
          onPopInvokedWithResult: (didPop, result) {
            if (!didPop) _exitPaneEdit();
          },
          child: scaffold,
        );
      },
    );
  }

  // Set-mode toolbar actions. When [narrowPane], the set-management actions
  // (market/export/edit/delete) fold into the top of the existing ⋮ Help menu
  // so the AppBar can't overflow; the builder actions (+, library, study) stay.
  List<Widget> _setModeActions(
    AppLocalizations l10n,
    CardSet liveSet,
    bool narrowPane,
  ) {
    final management = _setManagementActions(l10n, liveSet);

    return [
      // Add card — pane mode only (the FAB covers narrow). A local popup menu
      // picks the card type; existing cards are the library toggle beside it.
      if (widget.onExit != null)
        PopupMenuButton<String>(
          icon: const Icon(Icons.add),
          tooltip: l10n.tooltipAddCards,
          // Open below the button, not over it (default is `over`).
          position: PopupMenuPosition.under,
          onSelected: _startNewCardInPane,
          itemBuilder: (context) => [
            PopupMenuItem(
              value: AppConstants.cardTypeFlashcard,
              child: _menuRow(Icons.style_outlined, l10n.labelFlashCard),
            ),
            PopupMenuItem(
              value: AppConstants.cardTypeWorkbook,
              child: _menuRow(Icons.book_outlined, l10n.labelWorkbookCard),
            ),
          ],
        ),
      // Toggle the inline existing-cards library panel; acts as close too.
      if (widget.onExit != null)
        IconButton(
          isSelected: _libraryOpen,
          icon: const Icon(Icons.library_add_outlined),
          selectedIcon: const Icon(Icons.library_add),
          tooltip: l10n.actionAddExistingCards,
          onPressed: () => setState(() => _libraryOpen = !_libraryOpen),
        ),
      // On the wide pane there's always room for a dedicated Select button —
      // even when the pane narrows, management folds into the ⋮ menu below and
      // frees up the space. Only the truly tight narrow/full-screen toolbar
      // (no equivalent fold to lean on) keeps Select in the menu instead.
      if (widget.onExit != null && _orderedIds.isNotEmpty)
        IconButton(
          icon: const Icon(Icons.checklist),
          tooltip: l10n.actionSelect,
          onPressed: () => setState(() => _selection.mode = true),
        ),
      // Roomy pane: management actions inline. Narrow: they move into the ⋮ menu.
      if (!narrowPane)
        for (final a in management)
          IconButton(
            icon: Icon(a.icon),
            tooltip: a.label,
            onPressed: a.enabled ? a.onSelected : null,
          ),
      // Quick-study shortcut — bypasses the Study tab set picker.
      IconButton(
        icon: const Icon(Icons.play_circle_outline),
        tooltip: l10n.tooltipStudyThisSet,
        onPressed: _study,
      ),
      HelpMenuButton(
        HelpContext.sets,
        extraActions: [
          // Narrow/full-screen has no dedicated Select button (see above) —
          // long-press and Ctrl/Shift+click still work without it; this just
          // gives mouse users without modifiers a discoverable way in.
          if (widget.onExit == null && _orderedIds.isNotEmpty)
            HelpMenuAction(
              icon: Icons.checklist,
              label: l10n.actionSelect,
              onSelected: () => setState(() => _selection.mode = true),
            ),
          if (narrowPane) ...management,
        ],
      ),
    ];
  }

  // Set-management actions (market/export/edit/delete), rendered either as
  // inline toolbar IconButtons or as ⋮ menu items depending on pane width.
  List<HelpMenuAction> _setManagementActions(
    AppLocalizations l10n,
    CardSet liveSet,
  ) {
    return [
      HelpMenuAction(
        // Market publish/unpublish toggle.
        icon: liveSet.isPublic
            ? Icons.unpublished_outlined
            : Icons.storefront_outlined,
        label: liveSet.isPublic
            ? l10n.tooltipRemoveFromMarket
            : l10n.tooltipOfferInMarket,
        enabled: !_isPublishing,
        onSelected: () => _toggleMarketPublish(liveSet),
      ),
      HelpMenuAction(
        icon: Icons.download_outlined,
        label: l10n.tooltipExportSet,
        enabled: !_isExporting,
        onSelected: () => _exportSet(liveSet),
      ),
      HelpMenuAction(
        icon: Icons.edit_outlined,
        label: l10n.tooltipEditSet,
        onSelected: () => openEditSet(context, liveSet),
      ),
      HelpMenuAction(
        icon: Icons.delete_outline,
        label: l10n.tooltipDeleteSet,
        enabled: !_isDeleting,
        onSelected: _confirmDelete,
      ),
    ];
  }

  // Icon + label row for a popup-menu item.
  Widget _menuRow(IconData icon, String label) =>
      Row(children: [Icon(icon), const SizedBox(width: 12), Text(label)]);
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
            Icon(
              Icons.style_outlined,
              size: 80,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              context.l10n.titleNoCardsYet,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              context.l10n.messageNoCardsHint,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
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
  // Optional Edit / Remove-from-set quick-actions (#260), already
  // opacity/hit-test-gated by the caller for hover-reveal.
  final Widget? actions;
  // Multi-select (#238 part 2) — leading swaps to a checkbox while selecting.
  final bool selectionMode;
  final bool selected;
  // Hover tint (#237) — driven by the same _hoveredCardId that reveals the
  // quick-actions above, so it's only ever true on wide/pane layouts.
  final bool hovering;
  final VoidCallback? onToggle;
  const _FlashCardInSetTile({
    required this.card,
    this.dragHandle,
    this.actions,
    this.selectionMode = false,
    this.selected = false,
    this.hovering = false,
    this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      color: _tileColor(context, selected, hovering),
      child: ListTile(
        leading: selectionMode
            ? Checkbox(value: selected, onChanged: (_) => onToggle?.call())
            : const Icon(Icons.style_outlined),
        title: Text(card.primaryWord),
        subtitle: Text(card.translation),
        trailing: _tileTrailing(actions, dragHandle),
      ),
    );
  }
}

// Selection tint wins over hover tint; neither means the default Card colour.
Color? _tileColor(BuildContext context, bool selected, bool hovering) {
  final scheme = Theme.of(context).colorScheme;
  if (selected) return scheme.secondaryContainer;
  if (hovering) return scheme.surfaceContainerHighest.withValues(alpha: 0.5);
  return null;
}

// Combines the quick-actions and drag handle for a tile's trailing slot.
// Returns null when neither is present.
Widget? _tileTrailing(Widget? actions, Widget? dragHandle) {
  final parts = [actions, dragHandle].whereType<Widget>().toList();
  if (parts.isEmpty) return null;
  if (parts.length == 1) return parts.first;
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      for (var i = 0; i < parts.length; i++) ...[
        if (i > 0) const SizedBox(width: 4),
        parts[i],
      ],
    ],
  );
}

// Row of Edit / Remove-from-set quick-actions (#260). When [visible] is
// false (hover-reveal, wide layouts only) the row is faded out AND excluded
// from hit-testing so it can't intercept taps meant for the row underneath.
Widget _rowQuickActions({
  required bool visible,
  required String editTooltip,
  required String removeTooltip,
  required VoidCallback onEdit,
  required VoidCallback onRemove,
  // Clone (#231 Flash, #274 Workbook) — available on both card types.
  required String cloneTooltip,
  required VoidCallback onClone,
}) {
  return IgnorePointer(
    ignoring: !visible,
    child: AnimatedOpacity(
      opacity: visible ? 1 : 0,
      duration: const Duration(milliseconds: 120),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 20),
            tooltip: editTooltip,
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: onEdit,
          ),
          const SizedBox(width: 12),
          IconButton(
            icon: const Icon(Icons.copy_outlined, size: 20),
            tooltip: cloneTooltip,
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: onClone,
          ),
          const SizedBox(width: 12),
          IconButton(
            icon: const Icon(Icons.remove_circle_outline, size: 20),
            tooltip: removeTooltip,
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: onRemove,
          ),
        ],
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Workbook card row inside the set detail list.
// ---------------------------------------------------------------------------
class _WorkbookCardInSetTile extends StatelessWidget {
  final WorkbookCard card;
  // Optional reorder handle rendered at the trailing edge (set detail only).
  final Widget? dragHandle;
  // Optional Edit / Remove-from-set quick-actions (#260), already
  // opacity/hit-test-gated by the caller for hover-reveal.
  final Widget? actions;
  // Multi-select (#238 part 2) — leading swaps to a checkbox while selecting.
  final bool selectionMode;
  final bool selected;
  // Hover tint (#237) — see _FlashCardInSetTile.
  final bool hovering;
  final VoidCallback? onToggle;
  const _WorkbookCardInSetTile({
    required this.card,
    this.dragHandle,
    this.actions,
    this.selectionMode = false,
    this.selected = false,
    this.hovering = false,
    this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      color: _tileColor(context, selected, hovering),
      child: ListTile(
        leading: selectionMode
            ? Checkbox(value: selected, onChanged: (_) => onToggle?.call())
            : const Icon(Icons.book_outlined),
        title: Text(card.prompt, maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: Text(context.l10n.labelQuestionCount(card.questions.length)),
        trailing: _tileTrailing(actions, dragHandle),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _CardPickerSheet — bottom sheet for adding cards to a set.
//
// Shows flash cards and workbook cards in separate sections (each split into
// selectable / word-conflict / already-in-set sub-sections as applicable).
// Flash cards track word conflicts; workbook cards do not have a primaryWord.
// ---------------------------------------------------------------------------
class _CardLibrary extends ConsumerStatefulWidget {
  final String setId;
  final String userId;
  // If the set has a language pair, these are pre-populated so the library
  // defaults to showing only cards in the same language.
  final String? targetLanguage;
  final String? nativeLanguage;
  // Wide (#234): render as an inline side drawer (no bottom-sheet chrome) and
  // make selectable rows draggable into the set list. Narrow: a bottom sheet.
  final bool asDrawer;
  // Dismiss the library. The bottom sheet calls this after a successful add
  // (to pop); the drawer calls it from its close button (a successful add
  // instead just clears the selection and stays open so you can keep adding).
  final VoidCallback onClose;
  const _CardLibrary({
    required this.setId,
    required this.userId,
    required this.onClose,
    this.targetLanguage,
    this.nativeLanguage,
    this.asDrawer = false,
  });

  @override
  ConsumerState<_CardLibrary> createState() => _CardLibraryState();
}

class _CardLibraryState extends ConsumerState<_CardLibrary> {
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

  // Add the current selection, running the shared #210 language checks. On
  // success the host decides what happens next via onAdded (bottom sheet pops;
  // drawer clears the selection and stays open).
  Future<void> _commit() async {
    if (_selected.isEmpty) return;
    setState(() => _isAdding = true);
    try {
      final added = await addCardsWithLanguageCheck(
        context,
        ref,
        setId: widget.setId,
        userId: widget.userId,
        setTarget: widget.targetLanguage,
        setNative: widget.nativeLanguage,
        idToType: {for (final id in _selected) id: _idToType[id]!},
      );
      if (!mounted) return;
      if (added) {
        if (widget.asDrawer) {
          // Stay open; clear the selection so the author can keep adding.
          setState(() {
            _selected.clear();
            _idToType.clear();
            _isAdding = false;
          });
        } else {
          widget.onClose();
          // Don't reset _isAdding: the sheet is animating out, and resetting
          // briefly flips to the "all cards added" state.
        }
      } else {
        setState(() => _isAdding = false);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.errorFailedLoadCards)),
        );
        setState(() => _isAdding = false);
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

  // In drawer mode (#234), makes a selectable row draggable into the set list.
  // The drag payload is the whole checkbox selection if this card is part of it,
  // otherwise just this card — so you can drag one card without selecting first.
  Widget _selectableTile(Widget tile, String cardId, String cardType) {
    if (!widget.asDrawer) return tile;
    final payload = _selected.contains(cardId)
        ? {for (final id in _selected) id: _idToType[id]!}
        : {cardId: cardType};
    return Draggable<Map<String, String>>(
      data: payload,
      dragAnchorStrategy: pointerDragAnchorStrategy,
      feedback: _DragFeedback(count: payload.length),
      childWhenDragging: Opacity(opacity: 0.4, child: tile),
      child: tile,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Drawer: the inner content directly (its Column fills the drawer height).
    if (widget.asDrawer) return _buildInner(context, null);
    // Bottom sheet: a draggable, resizable sheet with a grab handle on top.
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      builder: (ctx, scrollController) => Column(
        children: [
          const SizedBox(height: 8),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Theme.of(ctx).colorScheme.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Expanded(child: _buildInner(ctx, scrollController)),
        ],
      ),
    );
  }

  Widget _buildInner(BuildContext context, ScrollController? scrollController) {
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
    final setsPair =
        (widget.targetLanguage != null && widget.nativeLanguage != null)
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

    return Column(
      children: [
        // Header row: (drawer) close button, title, and Add button.
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              if (widget.asDrawer)
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: l10n.labelCancel,
                    onPressed: widget.onClose,
                  ),
                ),
              Text(
                l10n.actionAddCards,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const Spacer(),
              FilledButton(
                onPressed: _selected.isEmpty || _isAdding ? null : _commit,
                child: _isAdding
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        _selected.isEmpty
                            ? l10n.actionAdd
                            : l10n.actionAddCount(_selected.length),
                      ),
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
                      onSelected: (_) => setState(() => _langFilter = pair),
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
    );
  }

  Widget _buildList(
    BuildContext context,
    ScrollController? scrollController,
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
              .where(
                (c) =>
                    AppHelpers.normalizeSearch(
                      c.primaryWord,
                    ).contains(normQuery) ||
                    AppHelpers.normalizeSearch(
                      c.translation,
                    ).contains(normQuery) ||
                    c.tags.any(
                      (t) => AppHelpers.normalizeSearch(t).contains(normQuery),
                    ),
              )
              .toList();
    var filteredWorkbook = normQuery.isEmpty
        ? allWorkbook
        : allWorkbook
              .where(
                (c) => AppHelpers.normalizeSearch(c.prompt).contains(normQuery),
              )
              .toList();

    // Language filter — restrict to cards matching the selected pair.
    // Cards with no language metadata are excluded when a filter is active.
    if (langFilter != null) {
      filteredFlash = filteredFlash
          .where(
            (c) =>
                c.targetLanguage == langFilter.$1 &&
                c.nativeLanguage == langFilter.$2,
          )
          .toList();
      filteredWorkbook = filteredWorkbook
          .where(
            (c) =>
                c.targetLanguage == langFilter.$1 &&
                c.nativeLanguage == langFilter.$2,
          )
          .toList();
    }

    // Flash card buckets (based on filtered list).
    final flashInSet = filteredFlash
        .where((c) => cardIdsInSet.contains(c.id))
        .toList();
    final inSetWords = flashInSet.map((c) => c.primaryWord).toSet();
    final flashNotInSet = filteredFlash
        .where(
          (c) =>
              !cardIdsInSet.contains(c.id) &&
              !inSetWords.contains(c.primaryWord),
        )
        .toList();
    // Different card, same word — can't add without creating a duplicate word.
    final flashWordConflict = filteredFlash
        .where(
          (c) =>
              !cardIdsInSet.contains(c.id) &&
              inSetWords.contains(c.primaryWord),
        )
        .toList();

    // Workbook card buckets — no word conflict possible.
    final workbookNotInSet = filteredWorkbook
        .where((c) => !cardIdsInSet.contains(c.id))
        .toList();
    final workbookInSet = filteredWorkbook
        .where((c) => cardIdsInSet.contains(c.id))
        .toList();

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
          child: Text(l10n.messageNoCardsYetTab, textAlign: TextAlign.center),
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
          child: Text(l10n.messageAllCardsInSet, textAlign: TextAlign.center),
        ),
      );
    }

    return ListView(
      controller: scrollController,
      children: [
        // ── Selectable flash cards ──────────────────────────────────────────
        if (flashNotInSet.isNotEmpty) ...[
          _SectionHeader(
            label: l10n.labelSectionFlashCards,
            icon: Icons.style_outlined,
          ),
          ...flashNotInSet.map(
            (card) => _selectableTile(
              CheckboxListTile(
                value: _selected.contains(card.id),
                onChanged: (v) =>
                    _toggle(card.id, AppConstants.cardTypeFlashcard, v),
                secondary: const Icon(Icons.style_outlined),
                title: Text(card.primaryWord),
                subtitle: Text(card.translation),
              ),
              card.id,
              AppConstants.cardTypeFlashcard,
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
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
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
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
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
          if (flashNotInSet.isNotEmpty ||
              flashWordConflict.isNotEmpty ||
              flashInSet.isNotEmpty)
            const Divider(),
          _SectionHeader(
            label: l10n.labelSectionWorkbookCards,
            icon: Icons.book_outlined,
          ),
          ...workbookNotInSet.map(
            (card) => _selectableTile(
              CheckboxListTile(
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
              card.id,
              AppConstants.cardTypeWorkbook,
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
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
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
// Floating pill shown under the pointer while dragging cards from the library
// drawer into the set list (#234): a card icon + the number being dragged.
// ---------------------------------------------------------------------------
class _DragFeedback extends StatelessWidget {
  final int count;
  const _DragFeedback({required this.count});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: scheme.primaryContainer,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8)],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.playlist_add,
              size: 18,
              color: scheme.onPrimaryContainer,
            ),
            const SizedBox(width: 6),
            Text(
              '$count',
              style: TextStyle(
                color: scheme.onPrimaryContainer,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
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
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
        ],
      ),
    );
  }
}
