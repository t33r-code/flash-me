import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flash_me/models/card_set.dart';
import 'package:flash_me/models/flash_card.dart';
import 'package:flash_me/providers/auth_provider.dart';
import 'package:flash_me/providers/card_provider.dart';
import 'package:flash_me/providers/card_set_provider.dart';
import 'package:flash_me/screens/sets/set_form_screen.dart';

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
    final cardsAsync = ref.watch(cardsInSetProvider(widget.cardSet.id));

    return Scaffold(
      appBar: AppBar(
        title: Text(liveSet.name),
        actions: [
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
        ],
      ),
      body: cardsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) =>
            const Center(child: Text('Failed to load cards.')),
        data: (cards) => cards.isEmpty
            ? _EmptyState(onAddCards: _showCardPicker)
            : ListView.builder(
                padding: const EdgeInsets.all(8),
                itemCount: cards.length,
                itemBuilder: (ctx, i) {
                  final card = cards[i];
                  // Swipe left to remove the card from this set.
                  return Dismissible(
                    key: Key(card.id),
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
                        color:
                            Theme.of(context).colorScheme.onErrorContainer,
                      ),
                    ),
                    confirmDismiss: (_) => _removeCard(card.id),
                    child: _CardInSetTile(card: card),
                  );
                },
              ),
      ),
      floatingActionButton: FloatingActionButton(
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
            const Icon(Icons.style_outlined, size: 80, color: Colors.grey),
            const SizedBox(height: 16),
            Text('No cards yet',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              'Tap + to add cards to this set.',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: Colors.grey),
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
// A single card row inside the set detail list.
// ---------------------------------------------------------------------------
class _CardInSetTile extends StatelessWidget {
  final FlashCard card;
  const _CardInSetTile({required this.card});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
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
// _CardPickerSheet — bottom sheet for adding cards to a set.
//
// Shows all user cards split into two sections:
//   - Selectable: cards not yet in the set (multi-select with checkboxes)
//   - Already added: greyed-out list at the bottom for reference
// ---------------------------------------------------------------------------
class _CardPickerSheet extends ConsumerStatefulWidget {
  final String setId;
  final String userId;
  const _CardPickerSheet({required this.setId, required this.userId});

  @override
  ConsumerState<_CardPickerSheet> createState() => _CardPickerSheetState();
}

class _CardPickerSheetState extends ConsumerState<_CardPickerSheet> {
  final Set<String> _selected = {};
  bool _isAdding = false;

  Future<void> _addSelected() async {
    if (_selected.isEmpty) return;
    setState(() => _isAdding = true);
    try {
      await ref.read(cardSetRepositoryProvider).addCardsToSet(
            setId: widget.setId,
            cardIds: _selected.toList(),
            userId: widget.userId,
          );
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

  @override
  Widget build(BuildContext context) {
    final allCardsAsync = ref.watch(userCardsProvider);
    final cardIdsInSet =
        ref.watch(cardIdsInSetProvider(widget.setId)).asData?.value.toSet() ??
            {};

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
            child: allCardsAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (_, _) =>
                  const Center(child: Text('Failed to load cards.')),
              data: (allCards) {
                if (allCards.isEmpty) {
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

                final notInSet = allCards
                    .where((c) => !cardIdsInSet.contains(c.id))
                    .toList();
                final inSet = allCards
                    .where((c) => cardIdsInSet.contains(c.id))
                    .toList();

                // Guard against a false "all added" flash: Firestore's local
                // cache can update the stream before addCardsToSet resolves
                // and closes the sheet. Show a spinner in that window instead.
                if (notInSet.isEmpty && _isAdding) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (notInSet.isEmpty) {
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
                    // Selectable cards.
                    ...notInSet.map(
                      (card) => CheckboxListTile(
                        value: _selected.contains(card.id),
                        onChanged: (v) => setState(() {
                          if (v == true) {
                            _selected.add(card.id);
                          } else {
                            _selected.remove(card.id);
                          }
                        }),
                        title: Text(card.primaryWord),
                        subtitle: Text(card.translation),
                        secondary: card.tags.isNotEmpty
                            ? Chip(
                                label: Text(card.tags.first),
                                visualDensity: VisualDensity.compact,
                              )
                            : null,
                      ),
                    ),

                    // Already-in-set section (for reference).
                    if (inSet.isNotEmpty) ...[
                      const Divider(),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                        child: Text(
                          'Already in set',
                          style: Theme.of(context)
                              .textTheme
                              .labelMedium
                              ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .outline),
                        ),
                      ),
                      ...inSet.map(
                        (card) => ListTile(
                          enabled: false,
                          title: Text(card.primaryWord),
                          subtitle: Text(card.translation),
                          trailing: const Icon(Icons.check),
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
