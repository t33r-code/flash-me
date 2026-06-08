import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flash_me/models/flash_card.dart';
import 'package:flash_me/models/workbook_card.dart';
import 'package:flash_me/providers/card_provider.dart';
import 'package:flash_me/providers/workbook_card_provider.dart';
import 'package:flash_me/screens/cards/card_form_screen.dart';
import 'package:flash_me/screens/cards/workbook_card_form_screen.dart';

class MyCardsScreen extends ConsumerStatefulWidget {
  const MyCardsScreen({super.key});

  @override
  ConsumerState<MyCardsScreen> createState() => _MyCardsScreenState();
}

class _MyCardsScreenState extends ConsumerState<MyCardsScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String? _selectedTag; // null = show all

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Shows a bottom sheet letting the user choose Flash Card or Workbook Card.
  void _showCardTypeChooser(BuildContext context) {
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
              child: Text('Create a card',
                  style: Theme.of(context).textTheme.titleMedium),
            ),
            ListTile(
              leading: const Icon(Icons.style_outlined),
              title: const Text('Flash Card'),
              subtitle:
                  const Text('Word + translation with optional fields'),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const CardFormScreen()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.book_outlined),
              title: const Text('Workbook Card'),
              subtitle: const Text(
                  'Prompt with text, multiple choice, or word order questions'),
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

  @override
  Widget build(BuildContext context) {
    final cardsAsync = ref.watch(userCardsProvider);
    final workbookCardsAsync = ref.watch(userWorkbookCardsProvider);

    final allCards = cardsAsync.asData?.value ?? [];
    final allWorkbook = workbookCardsAsync.asData?.value ?? [];
    final allTags = _allTags(allCards, allWorkbook);

    final filteredCards = _filterFlash(allCards);
    final filteredWorkbook = _filterWorkbook(allWorkbook);

    return Scaffold(
      appBar: AppBar(title: const Text('My Cards')),
      body: Column(
        children: [
          // Search bar.
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search cards…',
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
                  borderRadius: BorderRadius.circular(28),
                  borderSide: BorderSide.none,
                ),
                filled: true,
              ),
              onChanged: (v) => setState(() => _searchQuery = v.trim()),
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
                    label: const Text('All'),
                    selected: _selectedTag == null,
                    onSelected: (_) => setState(() => _selectedTag = null),
                  ),
                  const SizedBox(width: 8),
                  ...allTags.map((tag) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(tag),
                          selected: _selectedTag == tag,
                          onSelected: (_) => setState(
                              () => _selectedTag =
                                  _selectedTag == tag ? null : tag),
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
        tooltip: 'Create card',
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
    if (hasError) return const Center(child: Text('Failed to load cards.'));
    if (isEmpty) return const _EmptyState();

    if (cards.isEmpty && workbookCards.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            'No cards match your search.',
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
        if (i < cards.length) return _FlashCardTile(card: cards[i]);
        return _WorkbookCardTile(card: workbookCards[i - cards.length]);
      },
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
            Text('My Cards', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              'No cards yet. Tap + to create your first card.',
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
  const _FlashCardTile({required this.card});

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
      child: ListTile(
        leading: const Icon(Icons.style_outlined),
        title: Text(card.primaryWord),
        subtitle: Text(subtitle),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (card.tags.isNotEmpty) ...[
              Chip(
                label: Text(card.tags.first),
                visualDensity: VisualDensity.compact,
              ),
              const SizedBox(width: 4),
            ],
            Icon(Icons.chevron_right, size: 20, color: onSurfaceVariant),
          ],
        ),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => CardFormScreen(card: card),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Single workbook card row: prompt (truncated), question count, first tag.
// ---------------------------------------------------------------------------
class _WorkbookCardTile extends StatelessWidget {
  final WorkbookCard card;
  const _WorkbookCardTile({required this.card});

  @override
  Widget build(BuildContext context) {
    final onSurfaceVariant = Theme.of(context).colorScheme.onSurfaceVariant;
    final qCount = card.questions.length;
    final subtitle = '$qCount question${qCount == 1 ? '' : 's'}';
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        leading: const Icon(Icons.book_outlined),
        title: Text(
          card.prompt,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(subtitle),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (card.tags.isNotEmpty) ...[
              Chip(
                label: Text(card.tags.first),
                visualDensity: VisualDensity.compact,
              ),
              const SizedBox(width: 4),
            ],
            Icon(Icons.chevron_right, size: 20, color: onSurfaceVariant),
          ],
        ),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => WorkbookCardFormScreen(card: card),
          ),
        ),
      ),
    );
  }
}
