import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flash_me/models/card_set.dart';
import 'package:flash_me/models/flash_card.dart';
import 'package:flash_me/models/workbook_card.dart';
import 'package:flash_me/providers/auth_provider.dart';
import 'package:flash_me/providers/card_provider.dart';
import 'package:flash_me/providers/card_set_provider.dart';
import 'package:flash_me/providers/export_provider.dart';
import 'package:flash_me/providers/question_template_provider.dart';
import 'package:flash_me/providers/template_provider.dart';
import 'package:flash_me/providers/workbook_card_provider.dart';
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

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Set'),
        content: Text(
          'Delete "${widget.cardSet.name}"? '
          'Cards are not deleted, only removed from this set.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(ctx).colorScheme.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    setState(() => _isDeleting = true);
    try {
      final uid = ref.read(authStateProvider).asData?.value ?? '';
      await ref
          .read(cardSetRepositoryProvider)
          .deleteSet(widget.cardSet.id, uid);
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Failed to delete set. Please try again.')),
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
          const SnackBar(content: Text('Failed to remove card.')),
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
      builder: (_) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 20),
            Text('Preparing export…'),
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
            SnackBar(content: Text('Saved to $savedPath')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // dismiss progress dialog
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Export failed. Please try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
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
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _CardPickerSheet(
        setId: widget.cardSet.id,
        userId: uid,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Keep title in sync with edits made via SetFormScreen.
    final liveSet =
        ref.watch(setByIdProvider(widget.cardSet.id)) ?? widget.cardSet;

    // Flash cards already linked to this set (cardsInSetProvider queries cards/).
    final flashCardsAsync = ref.watch(cardsInSetProvider(widget.cardSet.id));
    // All workbook cards owned by the user — filtered by cardIdsInSet below.
    final allWorkbookAsync = ref.watch(userWorkbookCardsProvider);
    // All card IDs in the set (both types) from the setCards join collection.
    final cardIdsInSet =
        ref.watch(cardIdsInSetProvider(widget.cardSet.id)).asData?.value.toSet() ??
            {};

    // Workbook cards that belong to this set.
    final workbookCardsInSet = (allWorkbookAsync.asData?.value ?? [])
        .where((c) => cardIdsInSet.contains(c.id))
        .toList();

    final isLoading = flashCardsAsync.isLoading || allWorkbookAsync.isLoading;
    final hasError = flashCardsAsync.hasError || allWorkbookAsync.hasError;
    final flashCards = flashCardsAsync.asData?.value ?? [];

    final totalCount = flashCards.length + workbookCardsInSet.length;

    Widget body;
    if (isLoading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (hasError) {
      body = const Center(child: Text('Failed to load cards.'));
    } else if (totalCount == 0) {
      body = _EmptyState(onAddCards: _showCardPicker);
    } else {
      // Combined list: flash cards first, then workbook cards.
      body = ListView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: totalCount,
        itemBuilder: (ctx, i) {
          final String cardId;
          final Widget tile;

          if (i < flashCards.length) {
            final card = flashCards[i];
            cardId = card.id;
            tile = _FlashCardInSetTile(card: card);
          } else {
            final card = workbookCardsInSet[i - flashCards.length];
            cardId = card.id;
            tile = _WorkbookCardInSetTile(card: card);
          }

          // Swipe left to remove the card from this set (works for both types).
          return Dismissible(
            key: Key(cardId),
            direction: DismissDirection.endToStart,
            background: Container(
              alignment: Alignment.centerRight,
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
            confirmDismiss: (_) => _removeCard(cardId),
            child: tile,
          );
        },
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(liveSet.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.download_outlined),
            tooltip: 'Export set',
            onPressed: _isExporting ? null : () => _exportSet(liveSet),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Delete set',
            onPressed: _isDeleting ? null : _confirmDelete,
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit set',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => SetFormScreen(cardSet: liveSet),
              ),
            ),
          ),
          // Quick-study shortcut — bypasses the Study tab set picker for this set.
          IconButton(
            icon: const Icon(Icons.play_circle_outline),
            tooltip: 'Study this set',
            onPressed: _study,
          ),
        ],
      ),
      body: body,
      floatingActionButton: FloatingActionButton(
        heroTag: 'addCards',
        onPressed: _showCardPicker,
        tooltip: 'Add cards',
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
            Text('No cards yet',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              'Tap + to add cards to this set.',
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
              label: const Text('Add Cards'),
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
  const _FlashCardInSetTile({required this.card});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        leading: const Icon(Icons.style_outlined),
        title: Text(card.primaryWord),
        subtitle: Text(card.translation),
        trailing: card.tags.isNotEmpty
            ? Chip(
                label: Text(card.tags.first),
                visualDensity: VisualDensity.compact,
              )
            : null,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Workbook card row inside the set detail list.
// ---------------------------------------------------------------------------
class _WorkbookCardInSetTile extends StatelessWidget {
  final WorkbookCard card;
  const _WorkbookCardInSetTile({required this.card});

  @override
  Widget build(BuildContext context) {
    final qCount = card.questions.length;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        leading: const Icon(Icons.book_outlined),
        title: Text(
          card.prompt,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text('$qCount question${qCount == 1 ? '' : 's'}'),
        trailing: card.tags.isNotEmpty
            ? Chip(
                label: Text(card.tags.first),
                visualDensity: VisualDensity.compact,
              )
            : null,
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
class _CardPickerSheet extends ConsumerStatefulWidget {
  final String setId;
  final String userId;
  const _CardPickerSheet({required this.setId, required this.userId});

  @override
  ConsumerState<_CardPickerSheet> createState() => _CardPickerSheetState();
}

class _CardPickerSheetState extends ConsumerState<_CardPickerSheet> {
  // Selected card IDs and their types — needed to batch addCardsToSet by type.
  final Set<String> _selected = {};
  final Map<String, String> _idToType = {};
  bool _isAdding = false;

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
          const SnackBar(content: Text('Failed to add cards.')),
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
    final allFlashAsync = ref.watch(userCardsProvider);
    final allWorkbookAsync = ref.watch(userWorkbookCardsProvider);
    final cardIdsInSet =
        ref.watch(cardIdsInSetProvider(widget.setId)).asData?.value.toSet() ??
            {};

    final isLoading = allFlashAsync.isLoading || allWorkbookAsync.isLoading;
    final hasError = allFlashAsync.hasError || allWorkbookAsync.hasError;

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
                Text('Add Cards',
                    style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                FilledButton(
                  onPressed:
                      _selected.isEmpty || _isAdding ? null : _addSelected,
                  child: _isAdding
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : Text(_selected.isEmpty
                          ? 'Add'
                          : 'Add (${_selected.length})'),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Card list.
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : hasError
                    ? const Center(child: Text('Failed to load cards.'))
                    : _buildList(
                        context,
                        scrollController,
                        allFlashAsync.asData?.value ?? [],
                        allWorkbookAsync.asData?.value ?? [],
                        cardIdsInSet,
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
  ) {
    // Flash card buckets.
    final flashInSet =
        allFlash.where((c) => cardIdsInSet.contains(c.id)).toList();
    final inSetWords = flashInSet.map((c) => c.primaryWord).toSet();
    final flashNotInSet = allFlash
        .where((c) =>
            !cardIdsInSet.contains(c.id) &&
            !inSetWords.contains(c.primaryWord))
        .toList();
    // Different card, same word — can't add without creating a duplicate word.
    final flashWordConflict = allFlash
        .where((c) =>
            !cardIdsInSet.contains(c.id) &&
            inSetWords.contains(c.primaryWord))
        .toList();

    // Workbook card buckets — no word conflict possible.
    final workbookNotInSet =
        allWorkbook.where((c) => !cardIdsInSet.contains(c.id)).toList();
    final workbookInSet =
        allWorkbook.where((c) => cardIdsInSet.contains(c.id)).toList();

    final hasAnythingSelectable =
        flashNotInSet.isNotEmpty || workbookNotInSet.isNotEmpty;

    // Guard against a false "all added" flash: Firestore's local cache can
    // update the stream before addCardsToSet resolves and closes the sheet.
    if (!hasAnythingSelectable && _isAdding) {
      return const Center(child: CircularProgressIndicator());
    }

    if (allFlash.isEmpty && allWorkbook.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'No cards yet. Create cards from the Cards tab.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    if (!hasAnythingSelectable) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'All your cards are already in this set.',
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
          _SectionHeader(label: 'Flash Cards', icon: Icons.style_outlined),
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
              'Duplicate word — already in set',
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
              'Already in set',
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
          _SectionHeader(label: 'Workbook Cards', icon: Icons.book_outlined),
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
              subtitle: Text(
                '${card.questions.length} question${card.questions.length == 1 ? '' : 's'}',
              ),
            ),
          ),
        ],

        // Workbook cards already in set (reference only).
        if (workbookInSet.isNotEmpty) ...[
          const Divider(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text(
              'Already in set',
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
              subtitle: Text(
                '${card.questions.length} question${card.questions.length == 1 ? '' : 's'}',
              ),
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
