import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flash_me/models/card_set.dart';
import 'package:flash_me/models/workbook_card.dart';
import 'package:flash_me/providers/auth_provider.dart';
import 'package:flash_me/providers/language_provider.dart';
import 'package:flash_me/providers/tag_provider.dart';
import 'package:flash_me/providers/workbook_card_provider.dart';
import 'package:flash_me/utils/constants.dart';
import 'package:flash_me/utils/extensions.dart';
import 'package:flash_me/widgets/offline_banner.dart';
import 'package:flash_me/utils/helpers.dart';
import 'package:flash_me/widgets/language_picker.dart';
import 'package:flash_me/widgets/tag_input_field.dart';

// ---------------------------------------------------------------------------
// _QuestionState — mutable holder for one workbook question while the form
// is open.  Mirrors _FieldState in card_form_screen.dart.
//
// Holds controllers for every possible question type so that input survives
// the type-switcher (e.g. typing answers, switching type and back).
// ---------------------------------------------------------------------------
class _QuestionState {
  final String questionId;
  String type; // AppConstants.fieldType* or questionTypeWordOrder
  final TextEditingController promptController; // optional per-question label
  // text_input
  final TextEditingController answersController; // comma-separated
  final TextEditingController hintController;
  bool exactMatch;
  // multiple_choice
  final List<TextEditingController> optionControllers;
  int? correctIndex;
  MultipleChoiceDisplayMode displayMode;
  final TextEditingController explanationController;
  // word_order
  final List<String> wordBank;
  final List<String> correctOrder;
  final TextEditingController wordBankInputController;
  final TextEditingController correctOrderInputController;

  _QuestionState({
    required this.questionId,
    required this.type,
    required this.promptController,
    required this.answersController,
    required this.hintController,
    this.exactMatch = false,
    required this.optionControllers,
    this.correctIndex,
    this.displayMode = MultipleChoiceDisplayMode.list,
    required this.explanationController,
    required this.wordBank,
    required this.correctOrder,
    required this.wordBankInputController,
    required this.correctOrderInputController,
  });

  // Blank question defaulting to text_input type.
  factory _QuestionState.empty() => _QuestionState(
        questionId: CardQuestion.generateId(),
        type: AppConstants.fieldTypeTextInput,
        promptController: TextEditingController(),
        answersController: TextEditingController(),
        hintController: TextEditingController(),
        optionControllers: [TextEditingController(), TextEditingController()],
        explanationController: TextEditingController(),
        wordBank: [],
        correctOrder: [],
        wordBankInputController: TextEditingController(),
        correctOrderInputController: TextEditingController(),
      );

  // Populate controllers from an existing CardQuestion (edit mode).
  factory _QuestionState.fromQuestion(CardQuestion q) {
    switch (q) {
      case TextInputQuestion q:
        return _QuestionState(
          questionId: q.questionId,
          type: AppConstants.fieldTypeTextInput,
          promptController: TextEditingController(text: q.prompt ?? ''),
          answersController:
              TextEditingController(text: (q.correctAnswers ?? []).join(', ')),
          hintController: TextEditingController(text: q.hint ?? ''),
          exactMatch: q.exactMatch,
          optionControllers: [
            TextEditingController(),
            TextEditingController(),
          ],
          explanationController: TextEditingController(),
          wordBank: [],
          correctOrder: [],
          wordBankInputController: TextEditingController(),
          correctOrderInputController: TextEditingController(),
        );
      case MultipleChoiceQuestion q:
        final opts = q.options ?? [];
        final optCtls = opts.isEmpty
            ? [TextEditingController(), TextEditingController()]
            : opts.map((o) => TextEditingController(text: o)).toList();
        while (optCtls.length < 2) {
          optCtls.add(TextEditingController());
        }
        return _QuestionState(
          questionId: q.questionId,
          type: AppConstants.fieldTypeMultipleChoice,
          promptController: TextEditingController(text: q.prompt ?? ''),
          answersController: TextEditingController(),
          hintController: TextEditingController(),
          optionControllers: optCtls,
          correctIndex: q.correctIndex,
          displayMode: q.displayMode,
          explanationController:
              TextEditingController(text: q.explanation ?? ''),
          wordBank: [],
          correctOrder: [],
          wordBankInputController: TextEditingController(),
          correctOrderInputController: TextEditingController(),
        );
      case WordOrderQuestion q:
        return _QuestionState(
          questionId: q.questionId,
          type: AppConstants.questionTypeWordOrder,
          promptController: TextEditingController(text: q.prompt ?? ''),
          answersController: TextEditingController(),
          hintController: TextEditingController(),
          optionControllers: [
            TextEditingController(),
            TextEditingController(),
          ],
          explanationController: TextEditingController(),
          wordBank: List.from(q.wordBank ?? []),
          correctOrder: List.from(q.correctOrder ?? []),
          wordBankInputController: TextEditingController(),
          correctOrderInputController: TextEditingController(),
        );
    }
  }

  // Build a CardQuestion from the current state of all controllers.
  CardQuestion toQuestion() {
    final promptText = promptController.text.trim();
    final prompt = promptText.isEmpty ? null : promptText;

    if (type == AppConstants.fieldTypeTextInput) {
      return TextInputQuestion(
        questionId: questionId,
        prompt: prompt,
        correctAnswers: answersController.text
            .split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList(),
        hint: hintController.text.trim().isEmpty
            ? null
            : hintController.text.trim(),
        exactMatch: exactMatch,
      );
    } else if (type == AppConstants.fieldTypeMultipleChoice) {
      return MultipleChoiceQuestion(
        questionId: questionId,
        prompt: prompt,
        options: optionControllers.map((c) => c.text.trim()).toList(),
        correctIndex: correctIndex ?? 0,
        displayMode: displayMode,
        explanation: explanationController.text.trim().isEmpty
            ? null
            : explanationController.text.trim(),
      );
    } else {
      // word_order
      return WordOrderQuestion(
        questionId: questionId,
        prompt: prompt,
        wordBank: List.from(wordBank),
        correctOrder: List.from(correctOrder),
      );
    }
  }

  void dispose() {
    promptController.dispose();
    answersController.dispose();
    hintController.dispose();
    for (final c in optionControllers) {
      c.dispose();
    }
    explanationController.dispose();
    wordBankInputController.dispose();
    correctOrderInputController.dispose();
  }
}

// ---------------------------------------------------------------------------
// WorkbookCardFormScreen — create or edit a WorkbookCard.
// Pass [card] to pre-populate in edit mode; omit for create mode.
// Pass [parentSet] when creating from inside a set — its language pair is
// used as the default.
// ---------------------------------------------------------------------------
class WorkbookCardFormScreen extends ConsumerStatefulWidget {
  final WorkbookCard? card;
  final CardSet? parentSet;
  const WorkbookCardFormScreen({super.key, this.card, this.parentSet});

  @override
  ConsumerState<WorkbookCardFormScreen> createState() =>
      _WorkbookCardFormScreenState();
}

class _WorkbookCardFormScreenState
    extends ConsumerState<WorkbookCardFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _promptController;

  List<String> _tags = [];
  final List<_QuestionState> _questions = [];
  String? _nativeLanguage;
  String? _targetLanguage;
  bool _isSaving = false;

  bool get _isEditing => widget.card != null;

  @override
  void initState() {
    super.initState();
    final card = widget.card;
    _promptController = TextEditingController(text: card?.prompt ?? '');
    _tags = List.from(card?.tags ?? []);
    if (card != null) {
      _questions.addAll(card.questions.map(_QuestionState.fromQuestion));
      _nativeLanguage = card.nativeLanguage;
      _targetLanguage = card.targetLanguage;
    } else if (widget.parentSet != null) {
      _nativeLanguage = widget.parentSet!.nativeLanguage;
      _targetLanguage = widget.parentSet!.targetLanguage;
    } else {
      final last = ref.read(lastUsedLanguagesProvider);
      _nativeLanguage = last?.native;
      _targetLanguage = last?.target;
    }
  }

  @override
  void dispose() {
    _promptController.dispose();
    for (final q in _questions) {
      q.dispose();
    }
    super.dispose();
  }

  void _addQuestion() => setState(() => _questions.add(_QuestionState.empty()));

  void _removeQuestion(int index) {
    setState(() {
      _questions[index].dispose();
      _questions.removeAt(index);
    });
  }

  // Swap the question at [from] with the adjacent one at [to].
  void _moveQuestion(int from, int to) {
    if (to < 0 || to >= _questions.length) return;
    setState(() {
      final q = _questions.removeAt(from);
      _questions.insert(to, q);
    });
  }

  // --- Multiple choice option management ------------------------------------

  void _addOption(int qIdx) => setState(
      () => _questions[qIdx].optionControllers.add(TextEditingController()));

  void _removeOption(int qIdx, int optIdx) {
    final q = _questions[qIdx];
    if (q.optionControllers.length <= 2) return;
    setState(() {
      q.optionControllers[optIdx].dispose();
      q.optionControllers.removeAt(optIdx);
      if (q.correctIndex == optIdx) {
        q.correctIndex = null;
      } else if (q.correctIndex != null && q.correctIndex! > optIdx) {
        q.correctIndex = q.correctIndex! - 1;
      }
    });
  }

  // --- Word order management ------------------------------------------------

  void _addWordBankTile(int qIdx, String word) {
    final w = word.trim();
    if (w.isEmpty) return;
    setState(() => _questions[qIdx].wordBank.add(w));
    _questions[qIdx].wordBankInputController.clear();
  }

  void _removeWordBankTile(int qIdx, int tileIdx) {
    setState(() {
      final q = _questions[qIdx];
      final removed = q.wordBank[tileIdx];
      q.wordBank.removeAt(tileIdx);
      q.correctOrder.remove(removed);
    });
  }

  void _removeCorrectOrderWord(int qIdx, int idx) =>
      setState(() => _questions[qIdx].correctOrder.removeAt(idx));

  // Returns word bank tiles not yet consumed by the current correct order,
  // preserving multiplicity so the same word can appear multiple times.
  List<String> _availableForCorrectOrder(int qIdx) {
    final q = _questions[qIdx];
    final remaining = List<String>.from(q.wordBank);
    for (final word in q.correctOrder) {
      remaining.remove(word); // removes first occurrence — multiset semantics
    }
    return remaining;
  }

  void _placeCorrectOrderWord(int qIdx, String word) =>
      setState(() => _questions[qIdx].correctOrder.add(word));

  // --- Save / Delete --------------------------------------------------------

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final l10n = context.l10n;

    // Check that every MC question has a correct option selected.
    for (int i = 0; i < _questions.length; i++) {
      final q = _questions[i];
      if (q.type == AppConstants.fieldTypeMultipleChoice &&
          q.correctIndex == null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(l10n.messageSelectCorrectOptionNumber(i + 1)),
        ));
        return;
      }
    }

    // Validate word order questions.
    for (int i = 0; i < _questions.length; i++) {
      final q = _questions[i];
      if (q.type == AppConstants.questionTypeWordOrder) {
        if (q.wordBank.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(l10n.messageWordOrderNeedWordBank(i + 1)),
          ));
          return;
        }
        if (q.correctOrder.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(l10n.messageWordOrderNeedCorrectOrder(i + 1)),
          ));
          return;
        }
        for (final word in q.correctOrder) {
          if (!q.wordBank.contains(word)) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(l10n.messageWordOrderWordNotInBank(i + 1, word)),
            ));
            return;
          }
        }
      }
    }

    FocusScope.of(context).unfocus();
    setState(() => _isSaving = true);
    try {
      final uid = ref.read(authStateProvider).asData?.value ?? '';
      final tagRepo = ref.read(tagRepositoryProvider);
      final questions = _questions.map((q) => q.toQuestion()).toList();

      // Normalise tags so stored values match tags/{normalizedName} doc IDs.
      final normalizedTags = _tags
          .map(AppHelpers.normalizeTag)
          .where((t) => t.isNotEmpty)
          .toList();

      if (!_isEditing) {
        final now = DateTime.now();
        await ref.read(workbookCardRepositoryProvider).createCard(
              WorkbookCard(
                id: '',
                prompt: _promptController.text.trim(),
                questions: questions,
                tags: normalizedTags,
                nativeLanguage: _nativeLanguage,
                targetLanguage: _targetLanguage,
                createdAt: now,
                updatedAt: now,
                createdBy: uid,
              ),
            );
        ref.read(lastUsedLanguagesProvider.notifier).set(
              (native: _nativeLanguage, target: _targetLanguage),
            );
        // Fire-and-forget tag upserts so a count failure never blocks save.
        for (final tag in normalizedTags) { tagRepo.upsertTag(tag, uid); }
      } else {
        final (toUpsert, toDecrement) =
            AppHelpers.diffTags(widget.card!.tags, normalizedTags);
        await ref.read(workbookCardRepositoryProvider).updateCard(
              widget.card!.copyWith(
                prompt: _promptController.text.trim(),
                questions: questions,
                tags: normalizedTags,
                nativeLanguage: _nativeLanguage,
                targetLanguage: _targetLanguage,
              ),
            );
        for (final tag in toUpsert) { tagRepo.upsertTag(tag, uid); }
        for (final norm in toDecrement) { tagRepo.decrementTag(norm); }
      }
      if (mounted) {
        setState(() => _isSaving = false);
        Navigator.of(context).pop();
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.errorFailedSaveCard)),
        );
      }
    }
  }

  Future<void> _confirmDelete() async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.titleDeleteWorkbookCard),
        content: Text(l10n.messageDeleteWorkbookCardConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.labelCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(ctx).colorScheme.error),
            child: Text(l10n.labelDelete),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _isSaving = true);
    try {
      final tagsToDecrement = widget.card!.tags
          .map(AppHelpers.normalizeTag)
          .where((t) => t.isNotEmpty)
          .toList();
      final tagRepo = ref.read(tagRepositoryProvider);
      await ref
          .read(workbookCardRepositoryProvider)
          .deleteCard(widget.card!.id);
      for (final norm in tagsToDecrement) { tagRepo.decrementTag(norm); }
      if (mounted) {
        setState(() => _isSaving = false);
        Navigator.of(context).pop();
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.errorFailedDeleteCard)),
        );
      }
    }
  }

  // --- Question content builders --------------------------------------------

  Widget _buildTextInputContent(_QuestionState q) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: q.answersController,
          decoration: InputDecoration(
            labelText: l10n.labelCorrectAnswersRequired,
            hintText: l10n.hintCorrectAnswersExample,
            border: const OutlineInputBorder(),
          ),
          validator: (v) {
            final answers = (v ?? '')
                .split(',')
                .map((s) => s.trim())
                .where((s) => s.isNotEmpty)
                .toList();
            return answers.isEmpty ? l10n.validatorAtLeastOneAnswer : null;
          },
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: q.hintController,
          decoration: InputDecoration(
            labelText: l10n.labelHintOptional,
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 4),
        SwitchListTile(
          title: Text(l10n.labelExactMatch),
          subtitle: Text(l10n.messageExactMatchSubtitle),
          value: q.exactMatch,
          onChanged: (v) => setState(() => q.exactMatch = v),
          contentPadding: EdgeInsets.zero,
          dense: true,
        ),
      ],
    );
  }

  Widget _buildMultipleChoiceContent(_QuestionState q, int qIdx) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Display mode chip selector.
        Row(
          children: [
            Text(l10n.labelDisplay,
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(width: 8),
            ChoiceChip(
              label: Text(l10n.labelDisplayList),
              selected: q.displayMode == MultipleChoiceDisplayMode.list,
              onSelected: (_) => setState(
                  () => q.displayMode = MultipleChoiceDisplayMode.list),
              visualDensity: VisualDensity.compact,
            ),
            const SizedBox(width: 4),
            ChoiceChip(
              label: Text(l10n.labelDisplayChips),
              selected: q.displayMode == MultipleChoiceDisplayMode.chips,
              onSelected: (_) => setState(
                  () => q.displayMode = MultipleChoiceDisplayMode.chips),
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(l10n.labelOptionsRequired,
            style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 8),
        // RadioGroup groups all Radio children around a shared value.
        RadioGroup<int>(
          groupValue: q.correctIndex,
          onChanged: (v) => setState(() => q.correctIndex = v),
          child: Column(
            children: List.generate(q.optionControllers.length, (optIdx) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Radio<int>(value: optIdx),
                    Expanded(
                      child: TextFormField(
                        controller: q.optionControllers[optIdx],
                        decoration: InputDecoration(
                          labelText: l10n.labelOptionNumber(optIdx + 1),
                          border: const OutlineInputBorder(),
                        ),
                        validator: (v) => v?.trim().isEmpty ?? true
                            ? l10n.validatorOptionTextRequired
                            : null,
                      ),
                    ),
                    if (q.optionControllers.length > 2)
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline),
                        color: Theme.of(context).colorScheme.error,
                        onPressed: () => _removeOption(qIdx, optIdx),
                      ),
                  ],
                ),
              );
            }),
          ),
        ),
        TextButton.icon(
          onPressed: () => _addOption(qIdx),
          icon: const Icon(Icons.add),
          label: Text(l10n.actionAddOption),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: q.explanationController,
          decoration: InputDecoration(
            labelText: l10n.labelExplanationOptional,
            hintText: l10n.hintExplanationShownAfterAnswer,
            border: const OutlineInputBorder(),
          ),
        ),
      ],
    );
  }

  Widget _buildWordOrderContent(_QuestionState q, int qIdx) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final muted = Theme.of(context)
        .textTheme
        .bodySmall
        ?.copyWith(color: scheme.onSurfaceVariant);
    final available = _availableForCorrectOrder(qIdx);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // -- Word Bank -------------------------------------------------
        Text(l10n.labelWordBankRequired,
            style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 2),
        Text(l10n.messageWordBankHelp, style: muted),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: q.wordBankInputController,
                decoration: InputDecoration(
                  hintText: l10n.hintAddWordTile,
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
                textInputAction: TextInputAction.done,
                onSubmitted: (v) => _addWordBankTile(qIdx, v),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: () =>
                  _addWordBankTile(qIdx, q.wordBankInputController.text),
              child: Text(l10n.actionAdd),
            ),
          ],
        ),
        if (q.wordBank.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: q.wordBank
                .asMap()
                .entries
                .map((e) => Chip(
                      label: Text(e.value),
                      onDeleted: () => _removeWordBankTile(qIdx, e.key),
                      visualDensity: VisualDensity.compact,
                    ))
                .toList(),
          ),
        ],
        const SizedBox(height: 20),

        // -- Correct Order (tap tiles to build sequence) ---------------
        Row(
          children: [
            Text(l10n.labelCorrectOrderRequired,
                style: Theme.of(context).textTheme.bodySmall),
            const Spacer(),
            if (q.correctOrder.isNotEmpty)
              TextButton(
                onPressed: () => setState(() => q.correctOrder.clear()),
                style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact),
                child: Text(l10n.actionClear),
              ),
          ],
        ),
        const SizedBox(height: 2),
        Text(l10n.messageCorrectOrderHelp, style: muted),
        const SizedBox(height: 8),

        // Answer sequence — placed tiles with sequence numbers.
        // Tap the × to return a tile to the available pool.
        Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            border: Border.all(color: scheme.outlineVariant),
            borderRadius: BorderRadius.circular(8),
          ),
          child: q.correctOrder.isEmpty
              ? Text(
                  q.wordBank.isEmpty
                      ? l10n.messageAddTilesToWordBankFirst
                      : l10n.messageTapTilesBelow,
                  style: muted,
                )
              : Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: q.correctOrder.asMap().entries.map((e) {
                    return Chip(
                      label: Text('${e.key + 1}. ${e.value}'),
                      onDeleted: () => _removeCorrectOrderWord(qIdx, e.key),
                      visualDensity: VisualDensity.compact,
                    );
                  }).toList(),
                ),
        ),
        const SizedBox(height: 8),

        // Available tiles — derived from word bank minus already placed.
        if (available.isNotEmpty)
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: available
                .map((word) => ActionChip(
                      label: Text(word),
                      onPressed: () => _placeCorrectOrderWord(qIdx, word),
                      visualDensity: VisualDensity.compact,
                      avatar: const Icon(Icons.add, size: 16),
                    ))
                .toList(),
          )
        else if (q.wordBank.isNotEmpty)
          Text(l10n.labelAllTilesPlaced, style: muted),
      ],
    );
  }

  Widget _buildQuestionCard(int index) {
    final l10n = context.l10n;
    final q = _questions[index];
    return Card(
      key: ValueKey(q.questionId),
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: label + reorder + delete.
            Row(
              children: [
                Text(l10n.labelQuestionNumber(index + 1),
                    style: Theme.of(context).textTheme.titleSmall),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.arrow_upward),
                  iconSize: 20,
                  tooltip: l10n.tooltipMoveUp,
                  onPressed:
                      index > 0 ? () => _moveQuestion(index, index - 1) : null,
                ),
                IconButton(
                  icon: const Icon(Icons.arrow_downward),
                  iconSize: 20,
                  tooltip: l10n.tooltipMoveDown,
                  onPressed: index < _questions.length - 1
                      ? () => _moveQuestion(index, index + 1)
                      : null,
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  iconSize: 20,
                  color: Theme.of(context).colorScheme.error,
                  tooltip: l10n.tooltipRemoveQuestion,
                  onPressed: () => _removeQuestion(index),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Optional per-question label.
            TextFormField(
              controller: q.promptController,
              decoration: InputDecoration(
                labelText: l10n.labelQuestionLabelFullOptional,
                hintText: l10n.hintQuestionLabelWorkbookExample,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),

            // Type selector.
            DropdownButtonFormField<String>(
              initialValue: q.type,
              decoration: InputDecoration(
                labelText: l10n.labelQuestionType,
                border: const OutlineInputBorder(),
              ),
              items: [
                DropdownMenuItem(
                  value: AppConstants.fieldTypeTextInput,
                  child: Text(l10n.labelQuestionTypeTextInput),
                ),
                DropdownMenuItem(
                  value: AppConstants.fieldTypeMultipleChoice,
                  child: Text(l10n.labelQuestionTypeMultipleChoice),
                ),
                DropdownMenuItem(
                  value: AppConstants.questionTypeWordOrder,
                  child: Text(l10n.labelQuestionTypeWordOrder),
                ),
              ],
              onChanged: (v) {
                if (v != null) setState(() => q.type = v);
              },
            ),
            const SizedBox(height: 12),

            // Type-specific content.
            if (q.type == AppConstants.fieldTypeTextInput)
              _buildTextInputContent(q),
            if (q.type == AppConstants.fieldTypeMultipleChoice)
              _buildMultipleChoiceContent(q, index),
            if (q.type == AppConstants.questionTypeWordOrder)
              _buildWordOrderContent(q, index),
          ],
        ),
      ),
    );
  }

  // --- Main build -----------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? l10n.titleEditWorkbookCard : l10n.titleNewWorkbookCard),
        actions: [
          if (_isEditing)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: l10n.tooltipDeleteCard,
              onPressed: _isSaving ? null : _confirmDelete,
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: IgnorePointer(
          ignoring: _isSaving,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const OfflineBanner(),
                // --- Prompt -----------------------------------------------
                Text(l10n.titlePromptSection,
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(
                  l10n.messagePromptSectionHelp,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color:
                          Theme.of(context).colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _promptController,
                  decoration: InputDecoration(
                    labelText: l10n.labelPromptRequired,
                    hintText: l10n.hintPromptExample,
                    border: const OutlineInputBorder(),
                  ),
                  maxLines: 3,
                  textCapitalization: TextCapitalization.sentences,
                  validator: (v) =>
                      v?.trim().isEmpty ?? true ? l10n.validatorPromptRequired : null,
                ),

                // --- Languages --------------------------------------------
                const SizedBox(height: 24),
                Text(l10n.titleLanguagesSection,
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                LanguagePicker(
                  label: l10n.labelTargetLanguage,
                  value: _targetLanguage,
                  onChanged: (v) => setState(() => _targetLanguage = v),
                ),
                const SizedBox(height: 12),
                LanguagePicker(
                  label: l10n.labelNativeLanguage,
                  value: _nativeLanguage,
                  onChanged: (v) => setState(() => _nativeLanguage = v),
                ),

                // --- Tags -------------------------------------------------
                const SizedBox(height: 24),
                Text(l10n.titleTagsSection,
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                TagInputField(
                  tags: _tags,
                  enabled: !_isSaving,
                  onChanged: (updated) => setState(() => _tags = updated),
                ),

                // --- Questions --------------------------------------------
                const SizedBox(height: 24),
                Text(l10n.titleQuestionsSection,
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                ..._questions.asMap().entries.map((e) => _buildQuestionCard(e.key)),
                OutlinedButton.icon(
                  onPressed: _addQuestion,
                  icon: const Icon(Icons.add),
                  label: Text(l10n.actionAddQuestion),
                ),

                // --- Save / Cancel ----------------------------------------
                const SizedBox(height: 32),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isSaving
                            ? null
                            : () => Navigator.of(context).pop(),
                        child: Text(l10n.labelCancel),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: _isSaving ? null : _save,
                        child: _isSaving
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : Text(_isEditing
                                ? l10n.actionSaveChanges
                                : l10n.actionCreateCard),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
