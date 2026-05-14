import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flash_me/models/card_set.dart';
import 'package:flash_me/providers/card_set_provider.dart';
import 'package:flash_me/screens/study/study_setup_screen.dart';

// ---------------------------------------------------------------------------
// StudyScreen — the Study tab home.
//
// Shows all available study modes as tappable cards. Modes that are not yet
// implemented are displayed in a disabled state with a "Soon" badge so the
// UI scales gracefully as new modes are added.
// ---------------------------------------------------------------------------
class StudyScreen extends ConsumerWidget {
  const StudyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Study')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _StudyModeCard(
            icon: Icons.library_books_outlined,
            title: 'Study a Set',
            subtitle: 'Work through the cards in one of your sets.',
            onTap: () => _openSetPicker(context, ref),
          ),
          const SizedBox(height: 12),
          const _StudyModeCard(
            icon: Icons.flag_outlined,
            title: 'Study Review',
            subtitle: 'Focus on cards you have flagged for review.',
            comingSoon: true,
          ),
          const SizedBox(height: 12),
          const _StudyModeCard(
            icon: Icons.trending_down_outlined,
            title: 'Study Mistakes',
            subtitle: 'Drill questions you have answered incorrectly recently.',
            comingSoon: true,
          ),
        ],
      ),
    );
  }

  Future<void> _openSetPicker(BuildContext context, WidgetRef ref) async {
    final sets = ref.read(userSetsProvider).asData?.value ?? [];
    if (sets.isEmpty) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('No sets yet — create one in My Sets first.')),
      );
      return;
    }

    final selected = await showModalBottomSheet<CardSet>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _SetPickerSheet(sets: sets),
    );
    if (selected == null || !context.mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => StudySetupScreen(cardSet: selected)),
    );
  }
}

// ---------------------------------------------------------------------------
// _StudyModeCard — tappable card for one study mode; disabled when comingSoon.
// ---------------------------------------------------------------------------
class _StudyModeCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final bool comingSoon;

  const _StudyModeCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.comingSoon = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final enabled = !comingSoon;
    // Use .withAlpha instead of deprecated .withOpacity
    final disabledColor = scheme.onSurface.withAlpha(97); // ~0.38 opacity

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: enabled ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          child: Row(
            children: [
              Icon(
                icon,
                size: 32,
                color: enabled ? scheme.primary : disabledColor,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: enabled ? null : disabledColor,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: enabled
                                ? scheme.onSurfaceVariant
                                : disabledColor,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (comingSoon)
                // "Soon" badge for unimplemented modes
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Soon',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                  ),
                )
              else
                Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _SetPickerSheet — bottom sheet listing the user's sets for study selection.
// ---------------------------------------------------------------------------
class _SetPickerSheet extends StatelessWidget {
  final List<CardSet> sets;
  const _SetPickerSheet({required this.sets});

  Color _hexColor(String hex) {
    final h = hex.replaceFirst('#', '');
    return Color(int.parse('ff$h', radix: 16));
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (ctx, scrollController) => Column(
        children: [
          // Drag handle + title
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              children: [
                Container(
                  width: 32,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 12),
                Text('Choose a Set',
                    style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              controller: scrollController,
              itemCount: sets.length,
              itemBuilder: (_, i) {
                final s = sets[i];
                return ListTile(
                  leading: s.color != null
                      ? CircleAvatar(
                          backgroundColor: _hexColor(s.color!),
                          radius: 10,
                          child: const SizedBox.shrink(),
                        )
                      : const Icon(Icons.library_books_outlined),
                  title: Text(s.name),
                  subtitle: Text(
                      '${s.cardCount} card${s.cardCount == 1 ? '' : 's'}'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(ctx).pop(s),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
