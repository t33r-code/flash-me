import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flash_me/models/card_set.dart';
import 'package:flash_me/providers/card_set_provider.dart';
import 'package:flash_me/screens/sets/set_detail_screen.dart';
import 'package:flash_me/screens/sets/set_form_screen.dart';

class MySetsScreen extends ConsumerWidget {
  const MySetsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final setsAsync = ref.watch(userSetsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('My Sets')),
      body: setsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const Center(child: Text('Failed to load sets.')),
        data: (sets) => sets.isEmpty
            ? const _EmptyState()
            : ListView.builder(
                padding: const EdgeInsets.all(8),
                itemCount: sets.length,
                itemBuilder: (ctx, i) => _SetTile(cardSet: sets[i]),
              ),
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: null,
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const SetFormScreen()),
        ),
        tooltip: 'Create set',
        child: const Icon(Icons.add),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Empty state shown when the user has no sets yet.
// ---------------------------------------------------------------------------
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.library_books_outlined,
                size: 80, color: Colors.grey),
            const SizedBox(height: 16),
            Text('No sets yet',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              'Tap + to create your first set.',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// A single row in the sets list.
// ---------------------------------------------------------------------------
class _SetTile extends StatelessWidget {
  final CardSet cardSet;
  const _SetTile({required this.cardSet});

  // Parse '#RRGGBB' to a Flutter Color.
  Color _hexColor(String hex) {
    final h = hex.replaceFirst('#', '');
    return Color(int.parse('ff$h', radix: 16));
  }

  // Human-readable relative date for the last-updated timestamp.
  String _relativeDate(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(dt.year, dt.month, dt.day);
    final diff = today.difference(d).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    if (dt.year == now.year) {
      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      return '${months[dt.month - 1]} ${dt.day}';
    }
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final color =
        cardSet.color != null ? _hexColor(cardSet.color!) : null;
    final count = cardSet.cardCount;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => SetDetailScreen(cardSet: cardSet),
          ),
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Coloured accent bar on the left edge.
              if (color != null)
                Container(width: 6, color: color)
              else
                const SizedBox(width: 6),

              // Set info.
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Name + card count on the same row.
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              cardSet.name,
                              style: Theme.of(context).textTheme.titleMedium,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '$count card${count == 1 ? '' : 's'}',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant),
                          ),
                        ],
                      ),

                      // Description (if present).
                      if (cardSet.description != null &&
                          cardSet.description!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          cardSet.description!,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],

                      // Tags + last updated.
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          // Tags as compact chips (up to 3 shown).
                          if (cardSet.tags.isNotEmpty) ...[
                            Expanded(
                              child: Wrap(
                                spacing: 4,
                                runSpacing: 0,
                                children: cardSet.tags
                                    .take(3)
                                    .map(
                                      (tag) => Chip(
                                        label: Text(tag),
                                        labelStyle: Theme.of(context)
                                            .textTheme
                                            .labelSmall,
                                        padding: EdgeInsets.zero,
                                        materialTapTargetSize:
                                            MaterialTapTargetSize
                                                .shrinkWrap,
                                        visualDensity:
                                            VisualDensity.compact,
                                      ),
                                    )
                                    .toList(),
                              ),
                            ),
                          ] else
                            const Spacer(),

                          // Last updated date.
                          Text(
                            _relativeDate(cardSet.updatedAt),
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Chevron affordance.
              const Icon(Icons.chevron_right, size: 20),
              const SizedBox(width: 4),
            ],
          ),
        ),
      ),
    );
  }
}
