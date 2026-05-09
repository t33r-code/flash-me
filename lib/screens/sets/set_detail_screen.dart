import 'package:flutter/material.dart';
import 'package:flash_me/models/card_set.dart';
import 'package:flash_me/screens/sets/set_form_screen.dart';

// ---------------------------------------------------------------------------
// SetDetailScreen — shows a set's cards and management options.
// Phase 4a: placeholder body; full card list added in Phase 4b.
// ---------------------------------------------------------------------------
class SetDetailScreen extends StatelessWidget {
  final CardSet cardSet;
  const SetDetailScreen({super.key, required this.cardSet});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(cardSet.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit set',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => SetFormScreen(cardSet: cardSet),
              ),
            ),
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.library_books_outlined,
                size: 80, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              '${cardSet.cardCount} card${cardSet.cardCount == 1 ? '' : 's'}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Card management coming in the next update.',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
