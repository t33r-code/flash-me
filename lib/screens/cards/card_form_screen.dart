import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flash_me/models/card_field.dart';
import 'package:flash_me/models/card_template.dart';
import 'package:flash_me/models/flash_card.dart';
import 'package:flash_me/providers/auth_provider.dart';
import 'package:flash_me/providers/card_provider.dart';
import 'package:flash_me/providers/template_provider.dart';
import 'package:flash_me/utils/constants.dart';
import 'package:flash_me/screens/templates/template_form_screen.dart';

// ---------------------------------------------------------------------------
// _TemplatePickerSheet — bottom sheet listing the user's templates.
// Returns the selected CardTemplate via Navigator.pop.
// ---------------------------------------------------------------------------
class _TemplatePickerSheet extends StatelessWidget {
  final List<CardTemplate> templates;
  const _TemplatePickerSheet({required this.templates});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text('Choose a template',
              style: Theme.of(context).textTheme.titleMedium),
        ),
        const Divider(height: 1),
        Flexible(
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: templates.length,
            itemBuilder: (ctx, i) {
              final t = templates[i];
              final fieldCount = t.fields.length;
              return ListTile(
                leading: const Icon(Icons.copy_all_outlined),
                title: Text(t.name),
                subtitle: Text(
                  t.description ??
                      '$fieldCount field${fieldCount == 1 ? '' : 's'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: () => Navigator.of(ctx).pop(t),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// _FieldState — mutable holder for one additional field while the form is open.
//
// Holds a TextEditingController for every possible content type so that the
// user's input survives type-switcher changes (e.g. typing a reveal answer,
// switching to text-input and back, the reveal answer is still there).
// ---------------------------------------------------------------------------
class _FieldState {
  final String fieldId;
  String type; // AppConstants.fieldType*
  final TextEditingController nameController;
  // reveal
  final TextEditingController revealAnswerController;
  // text_input
  final TextEditingController textAnswersController; // comma-separated answers
  final TextEditingController textHintController;
  bool exactMatch;
  // multiple_choice
  final List<TextEditingController> optionControllers;
  int? correctOptionIndex;

  _FieldState({
    required this.fieldId,
    required this.type,
    required this.nameController,
    required this.revealAnswerController,
    required this.textAnswersController,
    required this.textHintController,
    this.exactMatch = false,
    required this.optionControllers,
    this.correctOptionIndex,
  });

  // Blank field defaulting to Reveal type with 2 empty MC options pre-allocated.
  factory _FieldState.empty() => _FieldState(
        fieldId: CardField.generateId(),
        type: AppConstants.fieldTypeReveal,
        nameController: TextEditingController(),
        revealAnswerController: TextEditingController(),
        textAnswersController: TextEditingController(),
        textHintController: TextEditingController(),
        optionControllers: [TextEditingController(), TextEditingController()],
      );

  // Populate controllers from an existing CardField (edit mode).
  factory _FieldState.fromCardField(CardField field) {
    String revealAnswer = '';
    String textAnswers = '';
    String textHint = '';
    bool exactMatch = false;
    final List<TextEditingController> optionControllers = [];
    int? correctIndex;

    switch (field.content) {
      case RevealContent c:
        revealAnswer = c.answer ?? '';
      case TextInputContent c:
        textAnswers = c.correctAnswers?.join(', ') ?? '';
        textHint = c.hint ?? '';
        exactMatch = c.exactMatch;
      case MultipleChoiceContent c:
        for (final opt in c.options ?? []) {
          optionControllers.add(TextEditingController(text: opt));
        }
        correctIndex = c.correctIndex;
    }

    // Multiple choice needs at least 2 option slots.
    while (optionControllers.length < 2) {
      optionControllers.add(TextEditingController());
    }

    return _FieldState(
      fieldId: field.fieldId,
      type: field.type,
      nameController: TextEditingController(text: field.name),
      revealAnswerController: TextEditingController(text: revealAnswer),
      textAnswersController: TextEditingController(text: textAnswers),
      textHintController: TextEditingController(text: textHint),
      exactMatch: exactMatch,
      optionControllers: optionControllers,
      correctOptionIndex: correctIndex,
    );
  }

  // Build the CardField from the current state of all controllers.
  CardField toCardField() {
    final CardFieldContent content;
    if (type == AppConstants.fieldTypeReveal) {
      content = RevealContent(answer: revealAnswerController.text.trim());
    } else if (type == AppConstants.fieldTypeTextInput) {
      final answers = textAnswersController.text
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
      content = TextInputContent(
        correctAnswers: answers,
        hint: textHintController.text.trim().isEmpty
            ? null
            : textHintController.text.trim(),
        exactMatch: exactMatch,
      );
    } else {
      // multiple_choice
      content = MultipleChoiceContent(
        options: optionControllers.map((c) => c.text.trim()).toList(),
        correctIndex: correctOptionIndex,
      );
    }
    return CardField(
      fieldId: fieldId,
      name: nameController.text.trim(),
      type: type,
      content: content,
    );
  }

  void dispose() {
    nameController.dispose();
    revealAnswerController.dispose();
    textAnswersController.dispose();
    textHintController.dispose();
    for (final c in optionControllers) {
      c.dispose();
    }
  }
}

// ---------------------------------------------------------------------------
// CardFormScreen — create or edit a FlashCard.
// Pass [card] to pre-populate the form in edit mode; omit for create mode.
// ---------------------------------------------------------------------------
class CardFormScreen extends ConsumerStatefulWidget {
  final FlashCard? card;
  const CardFormScreen({super.key, this.card});

  @override
  ConsumerState<CardFormScreen> createState() => _CardFormScreenState();
}

class _CardFormScreenState extends ConsumerState<CardFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _primaryWordController;
  late final TextEditingController _translationController;
  final _tagInputController = TextEditingController();

  List<String> _tags = [];
  final List<_FieldState> _fields = [];
  bool _isSaving = false;

  bool get _isEditing => widget.card != null;

  @override
  void initState() {
    super.initState();
    final card = widget.card;
    _primaryWordController =
        TextEditingController(text: card?.primaryWord ?? '');
    _translationController =
        TextEditingController(text: card?.translation ?? '');
    _tags = List.from(card?.tags ?? []);
    if (card != null) {
      _fields.addAll(card.fields.map(_FieldState.fromCardField));
    }
  }

  @override
  void dispose() {
    _primaryWordController.dispose();
    _translationController.dispose();
    _tagInputController.dispose();
    for (final f in _fields) {
      f.dispose();
    }
    super.dispose();
  }

  void _addField() {
    setState(() => _fields.add(_FieldState.empty()));
  }

  // Disposes existing fields, then populates from the template's field structure.
  // Answers are left blank; config (options, hints, exactMatch) is carried over.
  void _applyTemplate(CardTemplate template) {
    setState(() {
      for (final f in _fields) {
        f.dispose();
      }
      _fields.clear();
      _fields.addAll(template.fields.map(_FieldState.fromCardField));
    });
  }

  // Shows a bottom sheet listing the user's templates.
  // Asks for confirmation if fields are already present before replacing.
  Future<void> _showTemplatePicker() async {
    final templates = ref.read(userTemplatesProvider).asData?.value ?? [];
    if (templates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'No templates yet. Create one from the Templates tab.'),
        ),
      );
      return;
    }

    final selected = await showModalBottomSheet<CardTemplate>(
      context: context,
      builder: (_) => _TemplatePickerSheet(templates: templates),
    );
    if (selected == null || !mounted) return;

    if (_fields.isNotEmpty) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Replace fields?'),
          content: Text(
            'Apply "${selected.name}"? '
            'Your current fields will be replaced.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Replace'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }

    _applyTemplate(selected);
  }

  void _removeField(int index) {
    setState(() {
      _fields[index].dispose();
      _fields.removeAt(index);
    });
  }

  void _addOption(int fieldIndex) {
    setState(() => _fields[fieldIndex].optionControllers
        .add(TextEditingController()));
  }

  // Keeps minimum 2 options; adjusts correctOptionIndex when an option is removed.
  void _removeOption(int fieldIndex, int optionIndex) {
    final field = _fields[fieldIndex];
    if (field.optionControllers.length <= 2) return;
    setState(() {
      field.optionControllers[optionIndex].dispose();
      field.optionControllers.removeAt(optionIndex);
      if (field.correctOptionIndex == optionIndex) {
        field.correctOptionIndex = null;
      } else if (field.correctOptionIndex != null &&
          field.correctOptionIndex! > optionIndex) {
        field.correctOptionIndex = field.correctOptionIndex! - 1;
      }
    });
  }

  void _addTag(String input) {
    // Allow multi-tag paste (comma-separated) or single-tag Enter.
    final parts = input.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty);
    setState(() {
      for (final tag in parts) {
        if (!_tags.contains(tag)) _tags.add(tag);
      }
    });
    _tagInputController.clear();
  }

  void _removeTag(String tag) => setState(() => _tags.remove(tag));

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    // Check that every multiple-choice field has a correct option selected.
    for (int i = 0; i < _fields.length; i++) {
      final f = _fields[i];
      if (f.type == AppConstants.fieldTypeMultipleChoice &&
          f.correctOptionIndex == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Field "${f.nameController.text.trim().isEmpty ? i + 1 : f.nameController.text.trim()}": '
              'select the correct option.',
            ),
          ),
        );
        return;
      }
    }

    setState(() => _isSaving = true);
    try {
      final uid = ref.read(authStateProvider).asData?.value ?? '';
      final fields = _fields.map((f) => f.toCardField()).toList();

      if (!_isEditing) {
        await ref.read(cardRepositoryProvider).createCard(
              FlashCard(
                id: '',
                primaryWord: _primaryWordController.text.trim(),
                translation: _translationController.text.trim(),
                fields: fields,
                tags: _tags,
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
                createdBy: uid,
              ),
            );
      } else {
        await ref.read(cardRepositoryProvider).updateCard(
              widget.card!.copyWith(
                primaryWord: _primaryWordController.text.trim(),
                translation: _translationController.text.trim(),
                fields: fields,
                tags: _tags,
              ),
            );
      }
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Failed to save card. Please try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // Null out answer fields from the current card's fields so the template
  // stores structure and config (options, hints) but not answers.
  void _saveAsTemplate() {
    final templateFields = _fields.map((f) {
      final field = f.toCardField();
      final content = switch (field.content) {
        RevealContent _ => const RevealContent(answer: null),
        TextInputContent c => TextInputContent(
            correctAnswers: null,
            hint: c.hint,
            exactMatch: c.exactMatch,
          ),
        MultipleChoiceContent c => MultipleChoiceContent(
            options: c.options,
            correctIndex: null,
          ),
      };
      return field.copyWith(content: content);
    }).toList();

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TemplateFormScreen(initialFields: templateFields),
      ),
    );
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Card'),
        content: Text(
          'Delete "${widget.card!.primaryWord}"? '
          'It will be removed from all sets and cannot be undone.',
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
          .read(cardRepositoryProvider)
          .deleteCard(widget.card!.id);
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Failed to delete card. Please try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // --- field content builders -----------------------------------------------

  Widget _buildRevealContent(_FieldState field) {
    return TextFormField(
      controller: field.revealAnswerController,
      decoration: const InputDecoration(
        labelText: 'Answer *',
        border: OutlineInputBorder(),
      ),
      validator: (v) => v?.trim().isEmpty ?? true ? 'Answer is required' : null,
    );
  }

  Widget _buildTextInputContent(_FieldState field) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: field.textAnswersController,
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
          controller: field.textHintController,
          decoration: const InputDecoration(
            labelText: 'Hint (optional)',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 4),
        SwitchListTile(
          title: const Text('Exact match'),
          subtitle: const Text('Case-sensitive answer check'),
          value: field.exactMatch,
          onChanged: (v) => setState(() => field.exactMatch = v),
          contentPadding: EdgeInsets.zero,
          dense: true,
        ),
      ],
    );
  }

  Widget _buildMultipleChoiceContent(_FieldState field, int fieldIndex) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Options * (select the correct one)',
            style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 8),
        // RadioGroup manages the selected index for all Radio children.
        RadioGroup<int>(
          groupValue: field.correctOptionIndex,
          onChanged: (v) => setState(() => field.correctOptionIndex = v),
          child: Column(
            children: List.generate(field.optionControllers.length, (optIdx) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Radio<int>(value: optIdx),
                    Expanded(
                      child: TextFormField(
                        controller: field.optionControllers[optIdx],
                        decoration: InputDecoration(
                          labelText: 'Option ${optIdx + 1}',
                          border: const OutlineInputBorder(),
                        ),
                        validator: (v) => v?.trim().isEmpty ?? true
                            ? 'Option text required'
                            : null,
                      ),
                    ),
                    // Remove only allowed when more than 2 options exist.
                    if (field.optionControllers.length > 2)
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline),
                        color: Theme.of(context).colorScheme.error,
                        onPressed: () => _removeOption(fieldIndex, optIdx),
                      ),
                  ],
                ),
              );
            }),
          ),
        ),
        TextButton.icon(
          onPressed: () => _addOption(fieldIndex),
          icon: const Icon(Icons.add),
          label: const Text('Add option'),
        ),
      ],
    );
  }

  Widget _buildFieldCard(int index) {
    final field = _fields[index];
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
                    controller: field.nameController,
                    decoration: const InputDecoration(
                      labelText: 'Field name *',
                      hintText: 'e.g. Gender, Conjugation',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => v?.trim().isEmpty ?? true
                        ? 'Field name is required'
                        : null,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  color: Theme.of(context).colorScheme.error,
                  tooltip: 'Remove field',
                  onPressed: () => _removeField(index),
                ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: field.type,
              decoration: const InputDecoration(
                labelText: 'Field type',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(
                  value: AppConstants.fieldTypeReveal,
                  child: Text('Reveal on click'),
                ),
                DropdownMenuItem(
                  value: AppConstants.fieldTypeTextInput,
                  child: Text('Text input'),
                ),
                DropdownMenuItem(
                  value: AppConstants.fieldTypeMultipleChoice,
                  child: Text('Multiple choice'),
                ),
              ],
              onChanged: (v) {
                if (v != null) setState(() => field.type = v);
              },
            ),
            const SizedBox(height: 12),
            if (field.type == AppConstants.fieldTypeReveal)
              _buildRevealContent(field),
            if (field.type == AppConstants.fieldTypeTextInput)
              _buildTextInputContent(field),
            if (field.type == AppConstants.fieldTypeMultipleChoice)
              _buildMultipleChoiceContent(field, index),
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
        title: Text(_isEditing ? 'Edit Card' : 'New Card'),
        actions: [
          if (_isEditing)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Delete card',
              onPressed: _isSaving ? null : _confirmDelete,
            ),
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'save_as_template') _saveAsTemplate();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'save_as_template',
                child: ListTile(
                  leading: Icon(Icons.copy_all_outlined),
                  title: Text('Save as Template'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // --- Primary field ----
              Text('Primary Field',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              TextFormField(
                controller: _primaryWordController,
                decoration: const InputDecoration(
                  labelText: 'Foreign word *',
                  hintText: 'e.g. hablar',
                  border: OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.none,
                validator: (v) => v?.trim().isEmpty ?? true
                    ? 'Foreign word is required'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _translationController,
                decoration: const InputDecoration(
                  labelText: 'Translation *',
                  hintText: 'e.g. to speak',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => v?.trim().isEmpty ?? true
                    ? 'Translation is required'
                    : null,
              ),

              // --- Tags ---
              const SizedBox(height: 24),
              Text('Tags', style: Theme.of(context).textTheme.titleMedium),
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

              // --- Additional fields ---
              const SizedBox(height: 24),
              // "Use Template" button sits alongside the section header.
              Row(
                children: [
                  Text('Additional Fields',
                      style: Theme.of(context).textTheme.titleMedium),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: _showTemplatePicker,
                    icon: const Icon(Icons.copy_all_outlined, size: 18),
                    label: const Text('Use Template'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ..._fields.asMap().entries.map((e) => _buildFieldCard(e.key)),
              OutlinedButton.icon(
                onPressed: _addField,
                icon: const Icon(Icons.add),
                label: const Text('Add Field'),
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
                          : Text(_isEditing ? 'Save Changes' : 'Create Card'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
