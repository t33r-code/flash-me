import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flash_me/models/card_set.dart';
import 'package:flash_me/models/workbook_card.dart';
import 'package:flash_me/providers/auth_provider.dart';
import 'package:flash_me/providers/language_provider.dart';
import 'package:flash_me/providers/workbook_card_provider.dart';
import 'package:flash_me/utils/constants.dart';
import 'package:flash_me/widgets/language_picker.dart';

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
  final _tagInputController = TextEditingController();

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
    _tagInputController.dispose();
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

  void _addTag(String input) {
    final parts =
        input.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty);
    setState(() {
      for (final tag in parts) {
        if (!_tags.contains(tag)) _tags.add(tag);
      }
    });
    _tagInputController.clear();
  }

  void _removeTag(String tag) => setState(() => _tags.remove(tag));

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

    // Check that every MC question has a correct option selected.
    for (int i = 0; i < _questions.length; i++) {
      final q = _questions[i];
      if (q.type == AppConstants.fieldTypeMultipleChoice &&
          q.correctIndex == null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Question ${i + 1}: select the correct option.'),
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
            content: Text(
                'Question ${i + 1}: add at least one tile to the word bank.'),
          ));
          return;
        }
        if (q.correctOrder.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Question ${i + 1}: set the correct word order.'),
          ));
          return;
        }
        for (final word in q.correctOrder) {
          if (!q.wordBank.contains(word)) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(
                  'Question ${i + 1}: "$word" in correct order is not in the word bank.'),
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
      final questions = _questions.map((q) => q.toQuestion()).toList();

      if (!_isEditing) {
        final now = DateTime.now();
        await ref.read(workbookCardRepositoryProvider).createCard(
              WorkbookCard(
                id: '',
                prompt: _promptController.text.trim(),
                questions: questions,
                tags: _tags,
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
      } else {
        await ref.read(workbookCardRepositoryProvider).updateCard(
              widget.card!.copyWith(
                prompt: _promptController.text.trim(),
                questions: questions,
                tags: _tags,
                nativeLanguage: _nativeLanguage,
                targetLanguage: _targetLanguage,
              ),
            );
      }
      if (mounted) {
        setState(() => _isSaving = false);
        Navigator.of(context).pop();
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Failed to save card. Please try again.')),
        );
      }
    }
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Workbook Card'),
        content: const Text(
          'Delete this card? It will be removed from all sets and cannot be undone.',
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
    setState(() => _isSaving = true);
    try {
      await ref
          .read(workbookCardRepositoryProvider)
          .deleteCard(widget.card!.id);
      if (mounted) {
        setState(() => _isSaving = false);
        Navigator.of(context).pop();
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Failed to delete card. Please try again.')),
        );
      }
    }
  }

  // --- Question content builders --------------------------------------------

  Widget _buildTextInputContent(_QuestionState q) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: q.answersController,
          decoration: const InputDecoration(
            labelText: 'Correct answers * (comma-separated)',
            hintText: 'e.g. hablo, Hablo',
            border: OutlineInputBorder(),
          ),
          validator: (v) {
            final answers = (v ?? '')
                .split(',')
                .map((s) => s.trim())
                .where((s) => s.isNotEmpty)
                .toList();
            return answers.isEmpty ? 'At least one answer is required' : null;
          },
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: q.hintController,
          decoration: const InputDecoration(
            labelText: 'Hint (optional)',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 4),
        SwitchListTile(
          title: const Text('Exact match'),
          subtitle: const Text('Case-sensitive answer check'),
          value: q.exactMatch,
          onChanged: (v) => setState(() => q.exactMatch = v),
          contentPadding: EdgeInsets.zero,
          dense: true,
        ),
      ],
    );
  }

  Widget _buildMultipleChoiceContent(_QuestionState q, int qIdx) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Display mode chip selector.
        Row(
          children: [
            Text('Display:',
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(width: 8),
            ChoiceChip(
              label: const Text('List'),
              selected: q.displayMode == MultipleChoiceDisplayMode.list,
              onSelected: (_) => setState(
                  () => q.displayMode = MultipleChoiceDisplayMode.list),
              visualDensity: VisualDensity.compact,
            ),
            const SizedBox(width: 4),
            ChoiceChip(
              label: const Text('Chips'),
              selected: q.displayMode == MultipleChoiceDisplayMode.chips,
              onSelected: (_) => setState(
                  () => q.displayMode = MultipleChoiceDisplayMode.chips),
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text('Options * (select the correct one)',
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
                          labelText: 'Option ${optIdx + 1}',
                          border: const OutlineInputBorder(),
                        ),
                        validator: (v) => v?.trim().isEmpty ?? true
                            ? 'Option text required'
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
          label: const Text('Add option'),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: q.explanationController,
          decoration: const InputDecoration(
            labelText: 'Explanation (optional)',
            hintText: 'Shown after the user answers',
            border: OutlineInputBorder(),
          ),
        ),
      ],
    );
  }

  Widget _buildWordOrderContent(_QuestionState q, int qIdx) {
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
        Text('Word Bank *', style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 2),
        Text('Add all tiles — correct words plus any distractors', style: muted),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: q.wordBankInputController,
                decoration: const InputDecoration(
                  hintText: 'Add a word tile',
                  border: OutlineInputBorder(),
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
              child: const Text('Add'),
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
            Text('Correct Order *',
                style: Theme.of(context).textTheme.bodySmall),
            const Spacer(),
            if (q.correctOrder.isNotEmpty)
              TextButton(
                onPressed: () => setState(() => q.correctOrder.clear()),
                style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact),
                child: const Text('Clear'),
              ),
          ],
        ),
        const SizedBox(height: 2),
        Text('Tap tiles from the word bank to build the answer in order',
            style: muted),
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
                      ? 'Add tiles to the word bank first'
                      : 'Tap tiles below to set the answer order',
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
          Text('All tiles placed', style: muted),
      ],
    );
  }

  Widget _buildQuestionCard(int index) {
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
                Text('Question ${index + 1}',
                    style: Theme.of(context).textTheme.titleSmall),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.arrow_upward),
                  iconSize: 20,
                  tooltip: 'Move up',
                  onPressed:
                      index > 0 ? () => _moveQuestion(index, index - 1) : null,
                ),
                IconButton(
                  icon: const Icon(Icons.arrow_downward),
                  iconSize: 20,
                  tooltip: 'Move down',
                  onPressed: index < _questions.length - 1
                      ? () => _moveQuestion(index, index + 1)
                      : null,
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  iconSize: 20,
                  color: Theme.of(context).colorScheme.error,
                  tooltip: 'Remove question',
                  onPressed: () => _removeQuestion(index),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Optional per-question label.
            TextFormField(
              controller: q.promptController,
              decoration: const InputDecoration(
                labelText: 'Question label (optional)',
                hintText: 'e.g. Choose the correct gender',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),

            // Type selector.
            DropdownButtonFormField<String>(
              initialValue: q.type,
              decoration: const InputDecoration(
                labelText: 'Question type',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(
                  value: AppConstants.fieldTypeTextInput,
                  child: Text('Text input'),
                ),
                DropdownMenuItem(
                  value: AppConstants.fieldTypeMultipleChoice,
                  child: Text('Multiple choice'),
                ),
                DropdownMenuItem(
                  value: AppConstants.questionTypeWordOrder,
                  child: Text('Word order'),
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
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Workbook Card' : 'New Workbook Card'),
        actions: [
          if (_isEditing)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Delete card',
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
                // --- Prompt -----------------------------------------------
                Text('Prompt',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(
                  'Task description shown before questions are revealed',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color:
                          Theme.of(context).colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _promptController,
                  decoration: const InputDecoration(
                    labelText: 'Prompt *',
                    hintText: 'e.g. Read the sentence and answer below.',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                  textCapitalization: TextCapitalization.sentences,
                  validator: (v) =>
                      v?.trim().isEmpty ?? true ? 'Prompt is required' : null,
                ),

                // --- Languages --------------------------------------------
                const SizedBox(height: 24),
                Text('Languages',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                LanguagePicker(
                  label: 'Target language (being studied)',
                  value: _targetLanguage,
                  onChanged: (v) => setState(() => _targetLanguage = v),
                ),
                const SizedBox(height: 12),
                LanguagePicker(
                  label: 'Native language',
                  value: _nativeLanguage,
                  onChanged: (v) => setState(() => _nativeLanguage = v),
                ),

                // --- Tags -------------------------------------------------
                const SizedBox(height: 24),
                Text('Tags',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                if (_tags.isNotEmpty) ...[
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: _tags
                        .map((tag) => Chip(
                              label: Text(tag),
                              onDeleted: () => _removeTag(tag),
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: 8),
                ],
                TextField(
                  controller: _tagInputController,
                  decoration: InputDecoration(
                    hintText: 'Type a tag and press Enter',
                    prefixIcon: const Icon(Icons.label_outline),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.add),
                      onPressed: () => _addTag(_tagInputController.text),
                    ),
                  ),
                  textInputAction: TextInputAction.done,
                  onSubmitted: _addTag,
                ),

                // --- Questions --------------------------------------------
                const SizedBox(height: 24),
                Text('Questions',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                ..._questions.asMap().entries.map((e) => _buildQuestionCard(e.key)),
                OutlinedButton.icon(
                  onPressed: _addQuestion,
                  icon: const Icon(Icons.add),
                  label: const Text('Add Question'),
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
                        child: const Text('Cancel'),
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
                                ? 'Save Changes'
                                : 'Create Card'),
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
