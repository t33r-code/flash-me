import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flash_me/models/card_set.dart';
import 'package:flash_me/providers/auth_provider.dart';
import 'package:flash_me/providers/card_set_provider.dart';
import 'package:flash_me/providers/export_provider.dart';
import 'package:flash_me/providers/question_template_provider.dart';
import 'package:flash_me/providers/tag_provider.dart';
import 'package:flash_me/providers/template_provider.dart';
import 'package:flash_me/screens/sets/set_form_screen.dart';
import 'package:flash_me/screens/study/study_setup_screen.dart';
import 'package:flash_me/utils/extensions.dart';
import 'package:flash_me/utils/helpers.dart';
import 'package:flash_me/widgets/keyboard_actions.dart';

// ---------------------------------------------------------------------------
// Set-management actions (delete/export/market/study/edit) shared by
// SetDetailScreen's toolbar and any other entry point that needs to act on a
// CardSet without opening it first — namely the Sets-tab context menu (#237).
// Extracted so both call sites do the exact same delete/export/publish flow.
// ---------------------------------------------------------------------------

// Confirms and deletes [set]. Returns true if it was deleted, false if the
// user cancelled or the delete failed (an error snackbar is shown either way
// the caller doesn't need to). Callers that need to react to a successful
// delete (e.g. clearing a pane selection) should await the result.
Future<bool> deleteSetWithConfirm(
  BuildContext context,
  WidgetRef ref,
  CardSet set,
) async {
  final l10n = context.l10n;
  final confirmed = await showDialog<bool>(
    context: context,
    // Enter confirms the primary action (#235); Esc / tap-away cancels.
    builder: (ctx) => KeyboardActions(
      onConfirm: () => Navigator.of(ctx).pop(true),
      child: AlertDialog(
        title: Text(l10n.titleDeleteSet),
        content: Text(l10n.messageDeleteSetConfirm(set.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.labelCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: Text(l10n.labelDelete),
          ),
        ],
      ),
    ),
  );
  if (confirmed != true || !context.mounted) return false;

  try {
    final uid = ref.read(authStateProvider).asData?.value ?? '';
    final tagsToDecrement = set.tags
        .map(AppHelpers.normalizeTag)
        .where((t) => t.isNotEmpty)
        .toList();
    final tagRepo = ref.read(tagRepositoryProvider);
    await ref.read(cardSetRepositoryProvider).deleteSet(set.id, uid);
    for (final norm in tagsToDecrement) {
      tagRepo.decrementTag(norm);
    }
    return true;
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.errorFailedDeleteSet)));
    }
    return false;
  }
}

// Exports [set] as a self-contained ZIP archive behind a progress dialog.
Future<void> exportSetWithProgress(
  BuildContext context,
  WidgetRef ref,
  CardSet set,
) async {
  final l10n = context.l10n;
  final uid = ref.read(authStateProvider).asData?.value ?? '';
  final cards = ref.read(cardsInSetProvider(set.id)).asData?.value ?? [];
  // Fetch templates directly from repositories — don't rely on cached stream
  // state, which may be AsyncLoading if the Templates tab hasn't been opened.
  final cardTemplates = await ref
      .read(templateRepositoryProvider)
      .watchUserTemplates(uid)
      .first;
  final questionTemplates = await ref
      .read(questionTemplateRepositoryProvider)
      .getUserTemplates(uid);

  if (!context.mounted) return;
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      content: Row(
        children: [
          const CircularProgressIndicator(),
          const SizedBox(width: 20),
          Text(ctx.l10n.messagePreparingExport),
        ],
      ),
    ),
  );

  try {
    final savedPath = await ref
        .read(exportServiceProvider)
        .exportSet(
          set,
          cards,
          cardTemplates: cardTemplates,
          questionTemplates: questionTemplates,
        );
    if (context.mounted) {
      Navigator.of(context).pop(); // dismiss progress dialog
      if (savedPath != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.messageSavedTo(savedPath))));
      }
    }
  } catch (_) {
    if (context.mounted) {
      Navigator.of(context).pop(); // dismiss progress dialog
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.errorExportFailed)));
    }
  }
}

// Toggles [set]'s market-publish state: offers the "Offer in Market" sheet
// when going public, or an unpublish confirmation (with an acquisition-count
// guard) when going private.
Future<void> toggleMarketPublish(
  BuildContext context,
  WidgetRef ref,
  CardSet set,
) async {
  final l10n = context.l10n;
  if (set.isPublic) {
    final count = set.acquisitionCount;
    final confirmed = await showDialog<bool>(
      context: context,
      // Enter confirms the primary action (#235); Esc / tap-away cancels.
      builder: (ctx) => KeyboardActions(
        onConfirm: () => Navigator.of(ctx).pop(true),
        child: AlertDialog(
          title: Text(l10n.titleRemoveFromMarket),
          content: Text(
            count > 0
                ? l10n.messageRemoveFromMarketAcquired(set.name, count)
                : l10n.messageRemoveFromMarketNoAcquisitions(set.name),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(l10n.labelCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(ctx).colorScheme.error,
              ),
              child: Text(l10n.labelDelete),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await ref
          .read(cardSetRepositoryProvider)
          .updateSet(set.copyWith(isPublic: false));
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.errorFailedRemoveFromMarket)),
        );
      }
    }
  } else {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => MarketPublishSheet(cardSet: set),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await ref
          .read(cardSetRepositoryProvider)
          .updateSet(set.copyWith(isPublic: true));
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.errorFailedPublish)));
      }
    }
  }
}

void openEditSet(BuildContext context, CardSet set) {
  Navigator.of(
    context,
  ).push(MaterialPageRoute(builder: (_) => SetFormScreen(cardSet: set)));
}

// Navigates to study setup, preferring the live set (a just-edited language
// pair, etc.) over the possibly-stale [set] passed in.
void openStudySetup(BuildContext context, WidgetRef ref, CardSet set) {
  final currentSet = ref.read(setByIdProvider(set.id)) ?? set;
  Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => StudySetupScreen(cardSet: currentSet)),
  );
}

// ---------------------------------------------------------------------------
// "Offer in Market" bottom sheet — confirms the set's acquisition options
// before publishing. Pops `true` to proceed, `false`/dismissed to cancel.
// ---------------------------------------------------------------------------
class MarketPublishSheet extends StatefulWidget {
  final CardSet cardSet;
  const MarketPublishSheet({super.key, required this.cardSet});

  @override
  State<MarketPublishSheet> createState() => _MarketPublishSheetState();
}

class _MarketPublishSheetState extends State<MarketPublishSheet> {
  // Allow Clone is the only option in this phase — on and not yet toggleable.
  // Kept as state so future options can be wired in without restructuring.
  final bool _allowClone = true;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar.
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            Text(l10n.titleOfferInMarket, style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              l10n.messageOfferInMarketDescription(widget.cardSet.name),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),

            // Options — each future acquisition type appears here as a tile.
            Text(l10n.titleOptions, style: theme.textTheme.titleSmall),
            const SizedBox(height: 4),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.labelAllowClone),
              subtitle: Text(l10n.messageAllowCloneSubtitle),
              value: _allowClone,
              // Not yet user-toggleable — the only supported type in this phase.
              onChanged: null,
            ),

            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: Text(l10n.labelCancel),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    icon: const Icon(Icons.storefront_outlined),
                    label: Text(l10n.actionOfferInMarket),
                    onPressed: () => Navigator.of(context).pop(true),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
