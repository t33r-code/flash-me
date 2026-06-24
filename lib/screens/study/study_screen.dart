import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flash_me/models/card_set.dart';
import 'package:flash_me/models/study_candidate.dart';
import 'package:flash_me/widgets/help_menu_button.dart';
import 'package:flash_me/providers/card_set_provider.dart';
import 'package:flash_me/screens/study/study_setup_screen.dart';
import 'package:flash_me/utils/extensions.dart';
import 'package:flash_me/utils/transitions.dart';

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
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.titleStudy),
        actions: const [HelpMenuButton(HelpContext.study)],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _StudyModeCard(
            icon: Icons.library_books_outlined,
            title: l10n.titleStudyASet,
            subtitle: l10n.messageStudyASetSubtitle,
            onTap: () => _openSetPicker(context, ref),
          ),
          const SizedBox(height: 12),
          _StudyModeCard(
            icon: Icons.flag_outlined,
            title: l10n.titleStudyReview,
            subtitle: l10n.messageStudyReviewSubtitle,
            onTap: () => _openSynthetic(context, StudyMode.review),
          ),
          const SizedBox(height: 12),
          _StudyModeCard(
            icon: Icons.trending_down_outlined,
            title: l10n.titleStudyMistakes,
            subtitle: l10n.messageStudyMistakesSubtitle,
            onTap: () => _openSynthetic(context, StudyMode.mistakes),
          ),
        ],
      ),
    );
  }

  Future<void> _openSetPicker(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final sets = ref.read(userSetsProvider).asData?.value ?? [];
    if (sets.isEmpty) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.messageNoSetsYetStudy)),
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
      studyEnterRoute(StudySetupScreen(cardSet: selected)),
    );
  }

  // Opens the synthetic study setup for a filtered mode (Review / Mistakes).
  // The pool is assembled on the setup screen, which shows an empty state when
  // there are no eligible cards — so tapping is never blocked here.
  void _openSynthetic(BuildContext context, StudyMode mode) {
    final name = mode == StudyMode.review
        ? context.l10n.titleStudyReview
        : context.l10n.titleStudyMistakes;
    final shell = CardSet.synthetic(id: syntheticSetIdFor(mode), name: name);
    Navigator.of(context).push(
      studyEnterRoute(StudySetupScreen(cardSet: shell, syntheticMode: mode)),
    );
  }
}

// ---------------------------------------------------------------------------
// _StudyModeCard — tappable card for one study mode.
// ---------------------------------------------------------------------------
class _StudyModeCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  const _StudyModeCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          child: Row(
            children: [
              Icon(icon, size: 32, color: scheme.primary),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
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
                Text(context.l10n.titleChooseSet,
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
                  subtitle: Text(context.l10n.labelCardCount(s.cardCount)),
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
