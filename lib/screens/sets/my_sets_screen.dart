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
    final onSurfaceVariant = Theme.of(context).colorScheme.onSurfaceVariant;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.library_books_outlined,
                size: 80, color: onSurfaceVariant),
            const SizedBox(height: 16),
            Text('No sets yet',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              'Tap + to create your first set.',
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
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final color = cardSet.color != null ? _hexColor(cardSet.color!) : null;
    final count = cardSet.cardCount;
    final hasLanguage =
        cardSet.targetLanguage != null && cardSet.nativeLanguage != null;

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

              // Left: name, description, tags.
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 8, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        cardSet.name,
                        style: textTheme.titleMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (cardSet.description != null &&
                          cardSet.description!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          cardSet.description!,
                          style: textTheme.bodySmall
                              ?.copyWith(color: scheme.onSurfaceVariant),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      if (cardSet.tags.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 4,
                          runSpacing: 0,
                          children: cardSet.tags
                              .take(3)
                              .map((tag) => Chip(
                                    label: Text(tag),
                                    labelStyle: textTheme.labelSmall,
                                    padding: EdgeInsets.zero,
                                    materialTapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                    visualDensity: VisualDensity.compact,
                                  ))
                              .toList(),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // Right info column: language (top) · card count · date (bottom).
              // Uses spaceBetween so the date is always pushed to the bottom of
              // the tile regardless of how many lines the left content has.
              Padding(
                padding: const EdgeInsets.fromLTRB(0, 12, 8, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Top group: language badge (if set) above card count.
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (hasLanguage)
                          Text(
                            '${cardSet.targetLanguage!.toUpperCase()} → ${cardSet.nativeLanguage!.toUpperCase()}',
                            style: textTheme.labelSmall
                                ?.copyWith(color: scheme.onSurfaceVariant),
                          ),
                        Text(
                          '$count card${count == 1 ? '' : 's'}',
                          style: textTheme.bodySmall
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                    // Bottom: last updated date.
                    Text(
                      _relativeDate(cardSet.updatedAt),
                      style: textTheme.bodySmall
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
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
