import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flash_me/models/card_set.dart';
import 'package:flash_me/models/set_acquisition.dart';
import 'package:flash_me/models/set_update_diff.dart';
import 'package:flash_me/providers/auth_provider.dart';
import 'package:flash_me/providers/set_acquisition_provider.dart';
import 'package:flash_me/utils/exceptions.dart';
import 'package:flash_me/utils/extensions.dart';
import 'package:flash_me/utils/helpers.dart';

// ---------------------------------------------------------------------------
// CloneConfirmationScreen — shown when the user taps a Market set tile.
//
// Two modes depending on prior acquisition:
//   • First time  → standard clone confirmation with "Clone to My Sets" button
//   • Already cloned → update flow: checks for changes and offers Update / OK
// ---------------------------------------------------------------------------
class CloneConfirmationScreen extends ConsumerStatefulWidget {
  final CardSet marketSet;
  final String creatorDisplayName;

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
  bool _isBusy = false; // true while clone or update is in flight

  // ---- Clone (first time) --------------------------------------------------

  Future<void> _clone(String uid) async {
    setState(() => _isBusy = true);
    try {
      await ref.read(setAcquisitionRepositoryProvider).cloneSet(
            originalSetId: widget.marketSet.id,
            clonerId: uid,
          );
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(context.l10n.messageCloneSuccess(widget.marketSet.name)),
        behavior: SnackBarBehavior.floating,
      ));
    } catch (e) {
      AppLogger.error('Clone failed: $e');
      if (!mounted) return;
      setState(() => _isBusy = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(context.l10n.errorFailedCloneSet),
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  // ---- Update (already cloned) --------------------------------------------

  Future<void> _applyUpdate(
      String uid, String acquiredSetId, SetUpdateDiff diff) async {
    setState(() => _isBusy = true);
    try {
      await ref.read(setAcquisitionRepositoryProvider).applySetUpdate(
            originalSetId: widget.marketSet.id,
            acquiredSetId: acquiredSetId,
            clonerId: uid,
            diff: diff,
          );
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(context.l10n.messageUpdateSuccess(widget.marketSet.name)),
        behavior: SnackBarBehavior.floating,
      ));
    } catch (e) {
      AppLogger.error('Update failed: $e');
      if (!mounted) return;
      setState(() => _isBusy = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(context.l10n.errorFailedUpdateSet),
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  // ---- Build ---------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final uid = ref.watch(authStateProvider).asData?.value ?? '';
    final acquisitions =
        ref.watch(userAcquisitionsProvider).asData?.value ?? {};
    final prior = acquisitions[widget.marketSet.id];

    if (prior != null) {
      return _buildUpdateScaffold(uid, prior);
    }
    return _buildCloneScaffold(uid);
  }

  // ---- Clone scaffold (first time) ----------------------------------------

  Widget _buildCloneScaffold(String uid) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.titleCloneSet)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SetHeader(set: widget.marketSet, creator: widget.creatorDisplayName),
            const SizedBox(height: 32),
            const Divider(),
            const SizedBox(height: 16),
            _InfoBox(children: [
              _InfoRow(
                icon: Icons.library_add_outlined,
                text: l10n.infoCloneAddedToMySets,
              ),
              _InfoRow(
                icon: Icons.edit_outlined,
                text: l10n.infoCloneFullyEditable,
              ),
              _InfoRow(
                icon: Icons.link_off,
                text: l10n.infoCloneNoChanges,
              ),
            ]),
            const SizedBox(height: 32),
            _ActionButton(
              onPressed: _isBusy ? null : () => _clone(uid),
              isBusy: _isBusy,
              label: l10n.actionCloneToMySets,
              busyLabel: l10n.labelCloning,
              icon: Icons.library_add_outlined,
            ),
            const SizedBox(height: 12),
            _CancelButton(enabled: !_isBusy),
          ],
        ),
      ),
    );
  }

  // ---- Update scaffold (already cloned) ------------------------------------

  Widget _buildUpdateScaffold(String uid, SetAcquisition prior) {
    final l10n = context.l10n;
    final diffAsync = ref.watch(setUpdateDiffProvider((
      originalSetId: widget.marketSet.id,
      clonerId: uid,
    )));

    return Scaffold(
      appBar: AppBar(title: Text(l10n.titleAlreadyHaveSet)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SetHeader(set: widget.marketSet, creator: widget.creatorDisplayName),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 16),

            // Already-cloned notice
            _InfoBox(children: [
              _InfoRow(
                icon: Icons.check_circle_outline,
                text: l10n.infoAlreadyHaveCopy,
              ),
            ]),
            const SizedBox(height: 24),

            // Diff state: loading / error / data
            diffAsync.when(
              loading: () => Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Column(
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 12),
                      Text(l10n.messageCheckingForUpdates),
                    ],
                  ),
                ),
              ),
              error: (err, _) {
                // Source set missing means the creator's account was deleted.
                final isGone = err is AppException && err.code == 'set-not-found';
                return Text(
                  isGone
                      ? l10n.messageSetNoLongerAvailable
                      : l10n.messageCouldNotCheckUpdates,
                );
              },
              data: (diff) => diff.hasChanges
                  ? _buildUpdatesAvailable(uid, prior.acquiredSetId, diff)
                  : _buildUpToDate(),
            ),
          ],
        ),
      ),
    );
  }

  // Updates available section
  Widget _buildUpdatesAvailable(
      String uid, String acquiredSetId, SetUpdateDiff diff) {
    final l10n = context.l10n;
    final newCount = diff.newCards.length;
    final updatedCount = diff.updatedCards.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _InfoBox(children: [
          if (newCount > 0)
            _InfoRow(
              icon: Icons.add_circle_outline,
              text: l10n.messageNewCardsAdded(newCount),
            ),
          if (updatedCount > 0)
            _InfoRow(
              icon: Icons.refresh,
              text: l10n.messageCardsUpdatedSinceClone(updatedCount),
            ),
          _InfoRow(
            icon: Icons.folder_outlined,
            text: l10n.infoUpdateInPlace,
          ),
        ]),
        const SizedBox(height: 24),
        _ActionButton(
          onPressed: _isBusy
              ? null
              : () => _applyUpdate(uid, acquiredSetId, diff),
          isBusy: _isBusy,
          label: l10n.actionUpdateMyCopy,
          busyLabel: l10n.labelUpdating,
          icon: Icons.refresh,
        ),
        const SizedBox(height: 12),
        _CancelButton(enabled: !_isBusy),
      ],
    );
  }

  // Up to date section
  Widget _buildUpToDate() {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _InfoBox(children: [
          _InfoRow(
            icon: Icons.task_alt,
            text: l10n.infoUpToDate,
          ),
        ]),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.labelOk),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Shared sub-widgets
// ---------------------------------------------------------------------------

// Set name + color bar + creator/stats row + description + tags.
class _SetHeader extends StatelessWidget {
  final CardSet set;
  final String creator;
  const _SetHeader({required this.set, required this.creator});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final count = set.cardCount;
    final hasLanguage =
        set.targetLanguage != null && set.nativeLanguage != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Name + color bar
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
            Expanded(child: Text(set.name, style: textTheme.headlineSmall)),
          ],
        ),
        const SizedBox(height: 8),

        // Creator + card count + language pair
        Row(children: [
          Icon(Icons.person_outline, size: 14, color: scheme.onSurfaceVariant),
          const SizedBox(width: 4),
          Text(creator,
              style: textTheme.bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant)),
          const SizedBox(width: 16),
          Icon(Icons.style_outlined, size: 14, color: scheme.onSurfaceVariant),
          const SizedBox(width: 4),
          Text(context.l10n.labelCardCount(count),
              style: textTheme.bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant)),
          if (hasLanguage) ...[
            const SizedBox(width: 16),
            Text(
              '${set.targetLanguage!.toUpperCase()} → ${set.nativeLanguage!.toUpperCase()}',
              style: textTheme.bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ]),

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
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                    ))
                .toList(),
          ),
        ],
      ],
    );
  }

  Color _hexColor(String hex) {
    final h = hex.replaceFirst('#', '');
    return Color(int.parse('ff$h', radix: 16));
  }
}

// Rounded container used for informational bullet lists.
class _InfoBox extends StatelessWidget {
  final List<Widget> children;
  const _InfoBox({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

// Icon + text row used inside _InfoBox.
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
            child:
                Text(text, style: Theme.of(context).textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}

// Full-width filled button with an optional busy spinner.
class _ActionButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final bool isBusy;
  final String label;
  final String busyLabel;
  final IconData icon;
  const _ActionButton({
    required this.onPressed,
    required this.isBusy,
    required this.label,
    required this.busyLabel,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: onPressed,
        icon: isBusy
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              )
            : Icon(icon),
        label: Text(isBusy ? busyLabel : label),
      ),
    );
  }
}

// Full-width text "Cancel" button.
class _CancelButton extends StatelessWidget {
  final bool enabled;
  const _CancelButton({required this.enabled});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: TextButton(
        onPressed: enabled ? () => Navigator.of(context).pop() : null,
        child: Text(context.l10n.labelCancel),
      ),
    );
  }
}
