import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flash_me/models/card_set.dart';
import 'package:flash_me/providers/auth_provider.dart';
import 'package:flash_me/providers/set_acquisition_provider.dart';
import 'package:flash_me/utils/helpers.dart';

// ---------------------------------------------------------------------------
// CloneConfirmationScreen — dedicated screen (not a dialog) shown when a user
// taps a Market set. Structured to accommodate preview details in future
// iterations (Mk-5 card-level acquisition info, thumbnails, etc.).
// ---------------------------------------------------------------------------
class CloneConfirmationScreen extends ConsumerStatefulWidget {
  final CardSet marketSet; // the public set being cloned
  final String creatorDisplayName; // pre-resolved so the screen can show it immediately

  const CloneConfirmationScreen({
    super.key,
    required this.marketSet,
    required this.creatorDisplayName,
  });

  @override
  ConsumerState<CloneConfirmationScreen> createState() =>
      _CloneConfirmationScreenState();
}

class _CloneConfirmationScreenState
    extends ConsumerState<CloneConfirmationScreen> {
  bool _isCloning = false;

  Future<void> _clone() async {
    final uid = ref.read(authStateProvider).asData?.value;
    if (uid == null) return;

    setState(() => _isCloning = true);
    try {
      await ref.read(setAcquisitionRepositoryProvider).cloneSet(
            originalSetId: widget.marketSet.id,
            clonerId: uid,
          );
      if (!mounted) return;
      // Pop back to the market — the My Sets tab will update via its stream.
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('"${widget.marketSet.name}" added to My Sets.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      AppLogger.error('Clone failed: $e');
      if (!mounted) return;
      setState(() => _isCloning = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to clone set. Please try again.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final set = widget.marketSet;
    final count = set.cardCount;
    final hasLanguage = set.targetLanguage != null && set.nativeLanguage != null;

    return Scaffold(
      appBar: AppBar(title: const Text('Clone Set')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Set name + color accent
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (set.color != null) ...[
                  Container(
                    width: 4,
                    height: 48,
                    decoration: BoxDecoration(
                      color: _hexColor(set.color!),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Text(set.name, style: textTheme.headlineSmall),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Creator + stats row
            Row(
              children: [
                Icon(Icons.person_outline,
                    size: 14, color: scheme.onSurfaceVariant),
                const SizedBox(width: 4),
                Text(
                  widget.creatorDisplayName,
                  style: textTheme.bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
                const SizedBox(width: 16),
                Icon(Icons.style_outlined,
                    size: 14, color: scheme.onSurfaceVariant),
                const SizedBox(width: 4),
                Text(
                  '$count card${count == 1 ? '' : 's'}',
                  style: textTheme.bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
                if (hasLanguage) ...[
                  const SizedBox(width: 16),
                  Text(
                    '${set.targetLanguage!.toUpperCase()} → ${set.nativeLanguage!.toUpperCase()}',
                    style: textTheme.bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ],
              ],
            ),

            // Description
            if (set.description != null && set.description!.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(set.description!, style: textTheme.bodyMedium),
            ],

            // Tags
            if (set.tags.isNotEmpty) ...[
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: set.tags
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

            const SizedBox(height: 32),
            const Divider(),
            const SizedBox(height: 16),

            // What happens info box
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('What happens when you clone?',
                      style: textTheme.titleSmall),
                  const SizedBox(height: 8),
                  _InfoRow(
                    icon: Icons.library_add_outlined,
                    text:
                        'A copy of this set is added to your My Sets.',
                  ),
                  _InfoRow(
                    icon: Icons.edit_outlined,
                    text: 'Your copy is fully editable and independent.',
                  ),
                  _InfoRow(
                    icon: Icons.link_off,
                    text:
                        'Changes to the original won\'t affect your copy.',
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Clone button
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _isCloning ? null : _clone,
                icon: _isCloning
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.library_add_outlined),
                label: Text(_isCloning ? 'Cloning…' : 'Clone to My Sets'),
              ),
            ),

            const SizedBox(height: 12),

            // Cancel
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: _isCloning
                    ? null
                    : () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Parse '#RRGGBB' string to a Flutter Color.
  Color _hexColor(String hex) {
    final h = hex.replaceFirst('#', '');
    return Color(int.parse('ff$h', radix: 16));
  }
}

// Small icon + text row used in the info box.
class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: scheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: Theme.of(context).textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}
