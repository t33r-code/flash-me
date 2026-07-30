import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flash_me/models/flash_card.dart';
import 'package:flash_me/models/workbook_card.dart';
import 'package:flash_me/providers/card_provider.dart';
import 'package:flash_me/providers/card_set_provider.dart';
import 'package:flash_me/providers/workbook_card_provider.dart';
import 'package:flash_me/utils/constants.dart';
import 'package:flash_me/utils/extensions.dart';
import 'package:flash_me/utils/helpers.dart';
import 'package:flash_me/widgets/keyboard_actions.dart';

// Three-way result for the "set language?" dialog.
enum _LangChoice { setAndAdd, addOnly, cancel }

// Runs the language-consistency dialog(s) for [idToType] against the set, then
// performs the batched add (one addCardsToSet per card type). Returns true if
// cards were added, false if the user cancelled. Shared by every add-to-set
// entry point — the set builder's library sheet/drawer and drag-drop (#210,
// #234) and the card library's bulk Add to set (#238) — so they all honour the
// same checks and batched semantics.
Future<bool> addCardsWithLanguageCheck(
  BuildContext context,
  WidgetRef ref, {
  required String setId,
  required String userId,
  required String? setTarget,
  required String? setNative,
  required Map<String, String> idToType, // cardId -> cardType
}) async {
  if (idToType.isEmpty) return false;
  final l10n = context.l10n;
  final ids = idToType.keys.toSet();

  final allFlash = ref.read(userCardsProvider).asData?.value ?? <FlashCard>[];
  final allWorkbook =
      ref.read(userWorkbookCardsProvider).asData?.value ?? <WorkbookCard>[];

  // Distinct language pairs among the cards being added; neutral = no language.
  final selectedPairs = <(String, String)>{};
  var neutralCount = 0;
  for (final c in allFlash) {
    if (ids.contains(c.id)) {
      if (c.targetLanguage != null && c.nativeLanguage != null) {
        selectedPairs.add((c.targetLanguage!, c.nativeLanguage!));
      } else {
        neutralCount++;
      }
    }
  }
  for (final c in allWorkbook) {
    if (ids.contains(c.id)) {
      if (c.targetLanguage != null && c.nativeLanguage != null) {
        selectedPairs.add((c.targetLanguage!, c.nativeLanguage!));
      } else {
        neutralCount++;
      }
    }
  }

  Future<bool> commit() async {
    final repo = ref.read(cardSetRepositoryProvider);
    final flashIds = ids
        .where((id) => idToType[id] == AppConstants.cardTypeFlashcard)
        .toList();
    final workbookIds = ids
        .where((id) => idToType[id] == AppConstants.cardTypeWorkbook)
        .toList();
    if (flashIds.isNotEmpty) {
      await repo.addCardsToSet(
        setId: setId,
        cardIds: flashIds,
        userId: userId,
        cardType: AppConstants.cardTypeFlashcard,
      );
    }
    if (workbookIds.isNotEmpty) {
      await repo.addCardsToSet(
        setId: setId,
        cardIds: workbookIds,
        userId: userId,
        cardType: AppConstants.cardTypeWorkbook,
      );
    }
    return true;
  }

  // No language metadata on any card being added — nothing to check.
  if (selectedPairs.isEmpty) return commit();

  final (String, String)? setLang = (setTarget != null && setNative != null)
      ? (setTarget, setNative)
      : null;

  if (setLang == null) {
    if (selectedPairs.length == 1) {
      // All share one pair — offer to adopt it as the set's language.
      final pair = selectedPairs.first;
      final label = AppHelpers.formatLanguagePair(pair.$1, pair.$2);
      final choice = await showDialog<_LangChoice>(
        context: context,
        // Enter confirms the primary action (#235); Esc / tap-away cancels.
        builder: (ctx) => KeyboardActions(
          onConfirm: () => Navigator.of(ctx).pop(_LangChoice.setAndAdd),
          child: AlertDialog(
            title: Text(l10n.titleSetLanguage),
            content: Text(l10n.messageSetLanguagePrompt(neutralCount, label)),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(_LangChoice.cancel),
                child: Text(l10n.labelCancel),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(_LangChoice.addOnly),
                child: Text(l10n.actionAddOnly),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(_LangChoice.setAndAdd),
                child: Text(l10n.actionSetLanguageAndAdd),
              ),
            ],
          ),
        ),
      );
      if (!context.mounted || choice == null || choice == _LangChoice.cancel) {
        return false;
      }
      if (choice == _LangChoice.setAndAdd) {
        final currentSet = ref.read(setByIdProvider(setId));
        if (currentSet != null) {
          await ref
              .read(cardSetRepositoryProvider)
              .updateSet(
                currentSet.copyWith(
                  targetLanguage: pair.$1,
                  nativeLanguage: pair.$2,
                ),
              );
        }
      }
    } else {
      // Spans multiple pairs — warn.
      final proceed = await showDialog<bool>(
        context: context,
        // Enter confirms the primary action (#235); Esc / tap-away cancels.
        builder: (ctx) => KeyboardActions(
          onConfirm: () => Navigator.of(ctx).pop(true),
          child: AlertDialog(
            title: Text(l10n.titleMixedLanguages),
            content: Text(l10n.messageMixedLanguages),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: Text(l10n.labelCancel),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: Text(l10n.actionAddAnyway),
              ),
            ],
          ),
        ),
      );
      if (!context.mounted || proceed != true) return false;
    }
  } else {
    // Set has a language — warn on conflict.
    final hasConflict = selectedPairs.any((p) => p != setLang);
    if (hasConflict) {
      final setLabel = AppHelpers.formatLanguagePair(setLang.$1, setLang.$2);
      final proceed = await showDialog<bool>(
        context: context,
        // Enter confirms the primary action (#235); Esc / tap-away cancels.
        builder: (ctx) => KeyboardActions(
          onConfirm: () => Navigator.of(ctx).pop(true),
          child: AlertDialog(
            title: Text(l10n.titleDifferentLanguage),
            content: Text(l10n.messageDifferentLanguage(setLabel)),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: Text(l10n.labelCancel),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: Text(l10n.actionAddAnyway),
              ),
            ],
          ),
        ),
      );
      if (!context.mounted || proceed != true) return false;
    }
  }

  return commit();
}
