import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flash_me/models/card_set.dart';
import 'package:flash_me/providers/auth_provider.dart';
import 'package:flash_me/providers/card_set_provider.dart';
import 'package:flash_me/screens/sets/set_form_screen.dart';

// ---------------------------------------------------------------------------
// SetDetailScreen — shows a set's cards and management options.
// Phase 4a: placeholder body; full card list added in Phase 4b.
// ---------------------------------------------------------------------------
class SetDetailScreen extends ConsumerStatefulWidget {
  final CardSet cardSet;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.cardSet.name),
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
                builder: (_) => SetFormScreen(cardSet: widget.cardSet),
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
              '${widget.cardSet.cardCount} card${widget.cardSet.cardCount == 1 ? '' : 's'}',
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
