import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flash_me/models/flash_card.dart';
import 'package:flash_me/providers/card_provider.dart';
import 'package:flash_me/screens/cards/card_form_screen.dart';

class MyCardsScreen extends ConsumerWidget {
  const MyCardsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cardsAsync = ref.watch(userCardsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('My Cards')),
      body: Column(
        children: [
          // Search bar — full-text search wired up in a future subphase.
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: TextField(
              enabled: false,
              decoration: InputDecoration(
                hintText: 'Search cards...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(28),
                  borderSide: BorderSide.none,
                ),
                filled: true,
              ),
            ),
          ),
          // Tag filter chips — wired up in a future subphase.
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                FilterChip(
                  label: const Text('All tags'),
                  selected: true,
                  onSelected: (_) {},
                ),
              ],
            ),
          ),
          Expanded(
            child: cardsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) =>
                  const Center(child: Text('Failed to load cards.')),
              data: (cards) => cards.isEmpty
                  ? const _EmptyState()
                  : ListView.builder(
                      padding: const EdgeInsets.all(8),
                      itemCount: cards.length,
                      itemBuilder: (ctx, i) => _CardTile(card: cards[i]),
                    ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const CardFormScreen()),
        ),
        tooltip: 'Create card',
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.style_outlined, size: 80, color: Colors.grey),
          const SizedBox(height: 16),
          Text('My Cards', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            'No cards yet. Tap + to create your first card.',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// Single card row: shows primary word, translation, and first tag if any.
class _CardTile extends StatelessWidget {
  final FlashCard card;
  const _CardTile({required this.card});

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
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => CardFormScreen(card: card),
          ),
        ),
      ),
    );
  }
}
