import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flash_me/models/card_question.dart';
import 'package:flash_me/models/card_template.dart';
import 'package:flash_me/models/question_template.dart';
import 'package:flash_me/providers/auth_provider.dart';
import 'package:flash_me/providers/question_template_provider.dart';
import 'package:flash_me/providers/template_provider.dart';
import 'package:flash_me/utils/constants.dart';

// ---------------------------------------------------------------------------
// _TplQuestionState — mutable holder for one question while the template form
// is open.
//
// Templates store structure and config (options, hints, exactMatch) but not
// answers. Answer fields are therefore absent from this state object.
// ---------------------------------------------------------------------------
class _TplQuestionState {
  final String questionId;
  String type;
  final TextEditingController promptController;
  // text_input: optional hint shown to the user during study
  final TextEditingController textHintController;
  bool exactMatch;
  // multiple_choice: options CAN be pre-filled in a template
  final List<TextEditingController> optionControllers;

  _TplQuestionState({
    required this.questionId,
    required this.type,
    required this.promptController,
    required this.textHintController,
    this.exactMatch = false,
    required this.optionControllers,
  });

  factory _TplQuestionState.empty() => _TplQuestionState(
        questionId: CardQuestion.generateId(),
        type: AppConstants.fieldTypeTextInput,
        promptController: TextEditingController(),
        textHintController: TextEditingController(),
        optionControllers: [TextEditingController(), TextEditingController()],
      );

  // Initialise from an existing CardQuestion — works for both template questions
  // and card questions (answers are intentionally ignored; only config is read).
  factory _TplQuestionState.fromQuestion(CardQuestion q) {
    String textHint = '';
    bool exactMatch = false;
    final List<TextEditingController> optionControllers = [];

    switch (q) {
      case TextInputQuestion q:
        textHint = q.hint ?? '';
        exactMatch = q.exactMatch;
      case MultipleChoiceQuestion q:
        for (final opt in q.options ?? []) {
          optionControllers.add(TextEditingController(text: opt));
        }
      case WordOrderQuestion _:
        break; // word_order not yet supported in template form
    }

    while (optionControllers.length < 2) {
      optionControllers.add(TextEditingController());
    }

    return _TplQuestionState(
      questionId: q.questionId,
      type: switch (q) {
        TextInputQuestion _ => AppConstants.fieldTypeTextInput,
        MultipleChoiceQuestion _ => AppConstants.fieldTypeMultipleChoice,
        WordOrderQuestion _ => AppConstants.fieldTypeTextInput, // fallback
      },
      promptController: TextEditingController(text: q.prompt ?? ''),
      textHintController: TextEditingController(text: textHint),
      exactMatch: exactMatch,
      optionControllers: optionControllers,
    );
  }

  // Build a CardQuestion with null answers — correct for template storage.
  CardQuestion toQuestion() {
    final prompt = promptController.text.trim().isEmpty
        ? null
        : promptController.text.trim();
    if (type == AppConstants.fieldTypeTextInput) {
      return TextInputQuestion(
        questionId: questionId,
        prompt: prompt,
        correctAnswers: null,
        hint: textHintController.text.trim().isEmpty
            ? null
            : textHintController.text.trim(),
        exactMatch: exactMatch,
      );
    } else {
      // multiple_choice
      return MultipleChoiceQuestion(
        questionId: questionId,
        prompt: prompt,
        options: optionControllers.map((c) => c.text.trim()).toList(),
        correctIndex: null,
      );
    }
  }

  void dispose() {
    promptController.dispose();
    textHintController.dispose();
    for (final c in optionControllers) {
      c.dispose();
    }
  }
}

// ---------------------------------------------------------------------------
// _QuestionTemplatePickerSheet — simple bottom sheet listing question templates.
// Returns the selected QuestionTemplate via Navigator.pop.
// ---------------------------------------------------------------------------
class _QuestionTemplatePickerSheet extends StatelessWidget {
  final List<QuestionTemplate> templates;
  const _QuestionTemplatePickerSheet({required this.templates});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.5,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      builder: (ctx, scrollController) => Column(
        children: [
          const SizedBox(height: 8),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Text('Choose a Question Template',
                style: Theme.of(context).textTheme.titleMedium),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              controller: scrollController,
              itemCount: templates.length,
              itemBuilder: (_, i) {
                final t = templates[i];
                final typeLabel = switch (t.question) {
                  TextInputQuestion _ => 'Text input',
                  MultipleChoiceQuestion _ => 'Multiple choice',
                  WordOrderQuestion _ => 'Word order',
                };
                return ListTile(
                  leading: const Icon(Icons.quiz_outlined),
                  title: Text(t.name),
                  subtitle: Text(
                    t.description ?? typeLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () => Navigator.of(ctx).pop(t),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// TemplateFormScreen — create or edit a CardTemplate.
//
// Three entry points:
//   TemplateFormScreen()                        — blank create from scratch
//   TemplateFormScreen(template: t)             — edit existing template
//   TemplateFormScreen(initialQuestions: qs)    — create from card questions
//     (questions come pre-converted with answers nulled by the caller)
// ---------------------------------------------------------------------------
class TemplateFormScreen extends ConsumerStatefulWidget {
  final CardTemplate? template;
  final List<CardQuestion>? initialQuestions; // pre-populated from a card's questions

  const TemplateFormScreen({super.key, this.template, this.initialQuestions});

  @override
  ConsumerState<TemplateFormScreen> createState() => _TemplateFormScreenState();
}

class _TemplateFormScreenState extends ConsumerState<TemplateFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _descController;
  final List<_TplQuestionState> _questions = [];
  bool _primaryWordHidden = false;
  bool _isSaving = false;

  bool get _isEditing => widget.template != null;

  @override
  void initState() {
    super.initState();
    final t = widget.template;
    _nameController = TextEditingController(text: t?.name ?? '');
    _descController = TextEditingController(text: t?.description ?? '');
    _primaryWordHidden = t?.primaryWordHidden ?? false;

    if (t != null) {
      _questions.addAll(t.questions.map(_TplQuestionState.fromQuestion));
    } else if (widget.initialQuestions != null) {
      _questions
          .addAll(widget.initialQuestions!.map(_TplQuestionState.fromQuestion));
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    for (final q in _questions) {
      q.dispose();
    }
    super.dispose();
  }

  void _addQuestion() => setState(() => _questions.add(_TplQuestionState.empty()));

  // Opens a picker showing the user's question templates; appends the selected
  // question (with a fresh ID) to this template's question list.
  Future<void> _showQuestionTemplatePicker() async {
    final qtemplates =
        ref.read(userQuestionTemplatesProvider).asData?.value ?? [];
    if (qtemplates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('No question templates yet. Create one from the Question Templates tab.')));
      return;
    }
    final selected = await showModalBottomSheet<QuestionTemplate>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _QuestionTemplatePickerSheet(templates: qtemplates),
    );
    if (selected == null || !mounted) return;
    final freshQuestion = switch (selected.question) {
      TextInputQuestion q =>
        q.copyWith(questionId: CardQuestion.generateId()),
      MultipleChoiceQuestion q =>
        q.copyWith(questionId: CardQuestion.generateId()),
      WordOrderQuestion q =>
        q.copyWith(questionId: CardQuestion.generateId()),
    };
    setState(() => _questions.add(_TplQuestionState.fromQuestion(freshQuestion)));
  }

  void _removeQuestion(int index) {
    setState(() {
      _questions[index].dispose();
      _questions.removeAt(index);
    });
  }

  void _addOption(int qIndex) {
    setState(() =>
        _questions[qIndex].optionControllers.add(TextEditingController()));
  }

  void _removeOption(int qIndex, int optionIndex) {
    final q = _questions[qIndex];
    if (q.optionControllers.length <= 2) return;
    setState(() {
      q.optionControllers[optionIndex].dispose();
      q.optionControllers.removeAt(optionIndex);
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _isSaving = true);
    try {
      final uid = ref.read(authStateProvider).asData?.value ?? '';
      final questions = _questions.map((q) => q.toQuestion()).toList();

      if (!_isEditing) {
        await ref.read(templateRepositoryProvider).createTemplate(
              CardTemplate(
                id: '',
                createdBy: uid,
                name: _nameController.text.trim(),
                description: _descController.text.trim().isEmpty
                    ? null
                    : _descController.text.trim(),
                questions: questions,
                primaryWordHidden: _primaryWordHidden,
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
              ),
            );
      } else {
        await ref.read(templateRepositoryProvider).updateTemplate(
              widget.template!.copyWith(
                name: _nameController.text.trim(),
                description: _descController.text.trim().isEmpty
                    ? null
                    : _descController.text.trim(),
                questions: questions,
                primaryWordHidden: _primaryWordHidden,
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
              content: Text('Failed to save template. Please try again.')),
        );
      }
    }
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Template'),
        content: Text(
          'Delete "${widget.template!.name}"? '
          'Cards created from it keep their questions; this cannot be undone.',
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
          .read(templateRepositoryProvider)
          .deleteTemplate(widget.template!.id);
      if (mounted) {
        setState(() => _isSaving = false);
        Navigator.of(context).pop();
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content:
                  Text('Failed to delete template. Please try again.')),
        );
      }
    }
  }

  // --- question content builders --------------------------------------------

  Widget _buildTextInputContent(_TplQuestionState q) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: q.textHintController,
          decoration: const InputDecoration(
            labelText: 'Hint (optional)',
            hintText: 'Shown to the user during study',
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

  Widget _buildMultipleChoiceContent(_TplQuestionState q, int qIndex) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Options (pre-filled for all cards using this template)',
            style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 8),
        ...List.generate(q.optionControllers.length, (optIdx) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
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
                    onPressed: () => _removeOption(qIndex, optIdx),
                  ),
              ],
            ),
          );
        }),
        TextButton.icon(
          onPressed: () => _addOption(qIndex),
          icon: const Icon(Icons.add),
          label: const Text('Add option'),
        ),
      ],
    );
  }

  Widget _buildQuestionCard(int index) {
    final q = _questions[index];
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: q.promptController,
                    decoration: const InputDecoration(
                      labelText: 'Label (optional)',
                      hintText: 'e.g. Gender, Conjugation',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  color: Theme.of(context).colorScheme.error,
                  tooltip: 'Remove question',
                  onPressed: () => _removeQuestion(index),
                ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: q.type,
              decoration: const InputDecoration(
                labelText: 'Question type',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(
                    value: AppConstants.fieldTypeTextInput,
                    child: Text('Text input')),
                DropdownMenuItem(
                    value: AppConstants.fieldTypeMultipleChoice,
                    child: Text('Multiple choice')),
              ],
              onChanged: (v) {
                if (v != null) setState(() => q.type = v);
              },
            ),
            const SizedBox(height: 12),
            if (q.type == AppConstants.fieldTypeTextInput)
              _buildTextInputContent(q),
            if (q.type == AppConstants.fieldTypeMultipleChoice)
              _buildMultipleChoiceContent(q, index),
          ],
        ),
      ),
    );
  }

  // --- main build -----------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Template' : 'New Template'),
        actions: [
          if (_isEditing)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Delete template',
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
              // --- Template metadata ---
              Text('Template Details',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Template name *',
                  hintText: 'e.g. Spanish Verb',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    v?.trim().isEmpty ?? true ? 'Name is required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descController,
                decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 8),
              // primaryWordHidden default for cards created from this template
              SwitchListTile(
                title: const Text('Hide primary word by default'),
                subtitle: const Text(
                    'Cards created from this template start with the word hidden'),
                value: _primaryWordHidden,
                onChanged: (v) => setState(() => _primaryWordHidden = v),
                contentPadding: EdgeInsets.zero,
                dense: true,
              ),

              // --- Questions ---
              const SizedBox(height: 24),
              Text('Questions', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(
                'Define the structure. Answers are filled in per card.',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Theme.of(context).colorScheme.outline),
              ),
              const SizedBox(height: 12),
              ..._questions.asMap().entries.map((e) => _buildQuestionCard(e.key)),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _addQuestion,
                      icon: const Icon(Icons.add),
                      label: const Text('Add Question'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _showQuestionTemplatePicker,
                      icon: const Icon(Icons.quiz_outlined),
                      label: const Text('Use Template'),
                    ),
                  ),
                ],
              ),

              // --- Save / Cancel ---
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
                              : 'Create Template'),
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
