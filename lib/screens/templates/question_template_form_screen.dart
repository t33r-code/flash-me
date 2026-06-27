import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flash_me/models/card_question.dart';
import 'package:flash_me/models/question_template.dart';
import 'package:flash_me/providers/auth_provider.dart';
import 'package:flash_me/providers/question_template_provider.dart';
import 'package:flash_me/utils/constants.dart';
import 'package:flash_me/utils/extensions.dart';
// Characters that are valid in a templateId (alphanumeric, hyphen, underscore).
final _templateIdPattern = RegExp(r'^[a-zA-Z0-9_-]+$');

// ---------------------------------------------------------------------------
// _QuestionState — mutable holder for the single question while the form
// is open. Mirrors _TplQuestionState in template_form_screen.dart.
// ---------------------------------------------------------------------------
class _QuestionState {
  String type;
  final TextEditingController promptController;
  final TextEditingController textHintController;
  bool exactMatch;
  final List<TextEditingController> optionControllers;

  _QuestionState({
    required this.type,
    required this.promptController,
    required this.textHintController,
    this.exactMatch = false,
    required this.optionControllers,
  });

  factory _QuestionState.empty() => _QuestionState(
        type: AppConstants.fieldTypeTextInput,
        promptController: TextEditingController(),
        textHintController: TextEditingController(),
        optionControllers: [TextEditingController(), TextEditingController()],
      );

  // Initialise from an existing CardQuestion (answers are ignored).
  factory _QuestionState.fromQuestion(CardQuestion q) {
    String hint = '';
    bool exact = false;
    final List<TextEditingController> options = [];

    switch (q) {
      case TextInputQuestion q:
        hint = q.hint ?? '';
        exact = q.exactMatch;
      case MultipleChoiceQuestion q:
        for (final opt in q.options ?? []) {
          options.add(TextEditingController(text: opt));
        }
      case WordOrderQuestion _:
        break;
      case FillInTheBlanksQuestion _:
        break; // fill_in_blanks not yet supported in question template form (#170)
    }

    while (options.length < 2) {
      options.add(TextEditingController());
    }

    return _QuestionState(
      type: switch (q) {
        TextInputQuestion _ => AppConstants.fieldTypeTextInput,
        MultipleChoiceQuestion _ => AppConstants.fieldTypeMultipleChoice,
        WordOrderQuestion _ => AppConstants.questionTypeWordOrder,
        FillInTheBlanksQuestion _ => AppConstants.questionTypeFillInBlanks,
      },
      promptController: TextEditingController(text: q.prompt ?? ''),
      textHintController: TextEditingController(text: hint),
      exactMatch: exact,
      optionControllers: options,
    );
  }

  // Build a CardQuestion with null answers — correct for template storage.
  CardQuestion toQuestion() {
    final prompt = promptController.text.trim().isEmpty
        ? null
        : promptController.text.trim();
    if (type == AppConstants.fieldTypeTextInput) {
      return TextInputQuestion(
        questionId: CardQuestion.generateId(),
        prompt: prompt,
        hint: textHintController.text.trim().isEmpty
            ? null
            : textHintController.text.trim(),
        exactMatch: exactMatch,
      );
    } else if (type == AppConstants.fieldTypeMultipleChoice) {
      return MultipleChoiceQuestion(
        questionId: CardQuestion.generateId(),
        prompt: prompt,
        options: optionControllers.map((c) => c.text.trim()).toList(),
      );
    } else {
      // word_order
      return WordOrderQuestion(
        questionId: CardQuestion.generateId(),
        prompt: prompt,
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
// QuestionTemplateFormScreen — create or edit a QuestionTemplate.
// ---------------------------------------------------------------------------
class QuestionTemplateFormScreen extends ConsumerStatefulWidget {
  final QuestionTemplate? template;

  const QuestionTemplateFormScreen({super.key, this.template});

  @override
  ConsumerState<QuestionTemplateFormScreen> createState() =>
      _QuestionTemplateFormScreenState();
}

class _QuestionTemplateFormScreenState
    extends ConsumerState<QuestionTemplateFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _descController;
  late final TextEditingController _templateIdController;
  late _QuestionState _question;
  bool _isSaving = false;

  bool get _isEditing => widget.template != null;

  @override
  void initState() {
    super.initState();
    final t = widget.template;
    _nameController = TextEditingController(text: t?.name ?? '');
    _descController = TextEditingController(text: t?.description ?? '');
    _templateIdController = TextEditingController(text: t?.templateId ?? '');
    _question = t != null
        ? _QuestionState.fromQuestion(t.question)
        : _QuestionState.empty();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _templateIdController.dispose();
    _question.dispose();
    super.dispose();
  }

  void _addOption() {
    setState(() => _question.optionControllers.add(TextEditingController()));
  }

  void _removeOption(int index) {
    if (_question.optionControllers.length <= 2) return;
    setState(() {
      _question.optionControllers[index].dispose();
      _question.optionControllers.removeAt(index);
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _isSaving = true);
    try {
      final uid = ref.read(authStateProvider).asData?.value ?? '';
      final question = _question.toQuestion();
      final repo = ref.read(questionTemplateRepositoryProvider);
      final newTemplateId = _templateIdController.text.trim().isEmpty
          ? null
          : _templateIdController.text.trim();

      // Uniqueness check: no other template owned by this user may share the same templateId.
      if (newTemplateId != null) {
        final existing =
            ref.read(userQuestionTemplatesProvider).asData?.value ?? [];
        final conflict = existing.any((t) =>
            t.templateId == newTemplateId &&
            t.id != (widget.template?.id ?? ''));
        if (conflict) {
          setState(() => _isSaving = false);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(context.l10n.messageImportIdConflict(newTemplateId)),
          ));
          return;
        }
      }

      if (!_isEditing) {
        await repo.createTemplate(QuestionTemplate(
          id: '',
          createdBy: uid,
          name: _nameController.text.trim(),
          description: _descController.text.trim().isEmpty
              ? null
              : _descController.text.trim(),
          question: question,
          templateId: newTemplateId,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ));
      } else {
        await repo.updateTemplate(widget.template!.copyWith(
          name: _nameController.text.trim(),
          description: _descController.text.trim().isEmpty
              ? null
              : _descController.text.trim(),
          question: question,
          templateId: newTemplateId,
          updatedAt: DateTime.now(),
        ));
      }
      if (mounted) {
        setState(() => _isSaving = false);
        Navigator.of(context).pop();
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(context.l10n.errorFailedSaveTemplate)));
      }
    }
  }

  Future<void> _confirmDelete() async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.titleDeleteQuestionTemplate),
        content: Text(
          l10n.messageDeleteQuestionTemplateConfirm(widget.template!.name),
        ),
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
      await ref
          .read(questionTemplateRepositoryProvider)
          .deleteTemplate(widget.template!.id);
      if (mounted) {
        setState(() => _isSaving = false);
        Navigator.of(context).pop();
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(context.l10n.errorFailedDeleteTemplate)));
      }
    }
  }

  // --- question type content builders ---------------------------------------

  Widget _buildTextInputContent() {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: _question.textHintController,
          decoration: InputDecoration(
            labelText: l10n.labelHintOptional,
            hintText: l10n.hintHintShownDuringStudy,
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 4),
        SwitchListTile(
          title: Text(l10n.labelExactMatch),
          subtitle: Text(l10n.messageExactMatchSubtitle),
          value: _question.exactMatch,
          onChanged: (v) => setState(() => _question.exactMatch = v),
          contentPadding: EdgeInsets.zero,
          dense: true,
        ),
      ],
    );
  }

  Widget _buildMultipleChoiceContent() {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.labelOptionsPreFilled,
            style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 8),
        ...List.generate(_question.optionControllers.length, (i) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _question.optionControllers[i],
                    decoration: InputDecoration(
                      labelText: l10n.labelOptionNumber(i + 1),
                      border: const OutlineInputBorder(),
                    ),
                    validator: (v) =>
                        v?.trim().isEmpty ?? true ? l10n.validatorOptionTextRequired : null,
                  ),
                ),
                if (_question.optionControllers.length > 2)
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline),
                    color: Theme.of(context).colorScheme.error,
                    onPressed: () => _removeOption(i),
                  ),
              ],
            ),
          );
        }),
        TextButton.icon(
          onPressed: _addOption,
          icon: const Icon(Icons.add),
          label: Text(l10n.actionAddOption),
        ),
      ],
    );
  }

  // word_order templates store only the prompt; word bank is filled in per card.
  Widget _buildWordOrderContent() => Text(
        context.l10n.messageTplWordOrderNote,
        style: Theme.of(context)
            .textTheme
            .bodySmall
            ?.copyWith(color: Theme.of(context).colorScheme.outline),
      );

  // --- main build -----------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing
            ? l10n.titleEditQuestionTemplate
            : l10n.titleNewQuestionTemplate),
        actions: [
          if (_isEditing)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: l10n.tooltipDeleteTemplate,
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
                Text(l10n.titleTemplateDetails,
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: l10n.labelTemplateNameRequired,
                    hintText: l10n.hintTemplateNameQTExample,
                    border: const OutlineInputBorder(),
                  ),
                  validator: (v) =>
                      v?.trim().isEmpty ?? true ? l10n.validatorTemplateNameRequired : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _descController,
                  decoration: InputDecoration(
                    labelText: l10n.labelDescriptionOptional,
                    border: const OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _templateIdController,
                  decoration: InputDecoration(
                    labelText: l10n.labelImportIdOptional,
                    hintText: l10n.hintImportIdExample,
                    helperText: l10n.messageImportIdHelperText,
                    border: const OutlineInputBorder(),
                  ),
                  // Only alphanumeric, hyphens, underscores — no spaces or ##.
                  validator: (v) {
                    final s = v?.trim() ?? '';
                    if (s.isEmpty) return null;
                    if (!_templateIdPattern.hasMatch(s)) {
                      return l10n.validatorImportIdInvalid;
                    }
                    return null;
                  },
                ),

                // --- Question config ---
                const SizedBox(height: 24),
                Text(l10n.titleQuestionSection,
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextFormField(
                          controller: _question.promptController,
                          decoration: InputDecoration(
                            labelText: l10n.labelQuestionLabelOptional,
                            hintText: l10n.hintQuestionLabelExample,
                            border: const OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: _question.type,
                          decoration: InputDecoration(
                            labelText: l10n.labelQuestionType,
                            border: const OutlineInputBorder(),
                          ),
                          items: [
                            DropdownMenuItem(
                                value: AppConstants.fieldTypeTextInput,
                                child: Text(l10n.labelQuestionTypeTextInput)),
                            DropdownMenuItem(
                                value: AppConstants.fieldTypeMultipleChoice,
                                child: Text(l10n.labelQuestionTypeMultipleChoice)),
                            DropdownMenuItem(
                                value: AppConstants.questionTypeWordOrder,
                                child: Text(l10n.labelQuestionTypeWordOrder)),
                          ],
                          onChanged: (v) {
                            if (v != null) setState(() => _question.type = v);
                          },
                        ),
                        const SizedBox(height: 12),
                        if (_question.type == AppConstants.fieldTypeTextInput)
                          _buildTextInputContent(),
                        if (_question.type ==
                            AppConstants.fieldTypeMultipleChoice)
                          _buildMultipleChoiceContent(),
                        if (_question.type == AppConstants.questionTypeWordOrder)
                          _buildWordOrderContent(),
                      ],
                    ),
                  ),
                ),

                // --- Save / Cancel ---
                const SizedBox(height: 32),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed:
                            _isSaving ? null : () => Navigator.of(context).pop(),
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
                                : l10n.actionCreateTemplate),
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
