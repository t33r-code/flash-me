import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flash_me/models/card_field.dart';
import 'package:flash_me/models/card_template.dart';
import 'package:flash_me/providers/auth_provider.dart';
import 'package:flash_me/providers/template_provider.dart';
import 'package:flash_me/utils/constants.dart';

// ---------------------------------------------------------------------------
// _TplFieldState — mutable holder for one field while the template form is open.
//
// Mirrors _FieldState in card_form_screen but deliberately omits answer fields:
// templates store configuration (options, hints) but not answers.
// ---------------------------------------------------------------------------
class _TplFieldState {
  final String fieldId;
  String type;
  final TextEditingController nameController;
  // text_input: optional hint shown to the user during study
  final TextEditingController textHintController;
  bool exactMatch;
  // multiple_choice: options CAN be pre-filled in a template
  final List<TextEditingController> optionControllers;

  _TplFieldState({
    required this.fieldId,
    required this.type,
    required this.nameController,
    required this.textHintController,
    this.exactMatch = false,
    required this.optionControllers,
  });

  factory _TplFieldState.empty() => _TplFieldState(
        fieldId: CardField.generateId(),
        type: AppConstants.fieldTypeReveal,
        nameController: TextEditingController(),
        textHintController: TextEditingController(),
        optionControllers: [TextEditingController(), TextEditingController()],
      );

  // Initialise from an existing CardField — works for both template fields and
  // card fields (answers are intentionally ignored; only config is read).
  factory _TplFieldState.fromCardField(CardField field) {
    String textHint = '';
    bool exactMatch = false;
    final List<TextEditingController> optionControllers = [];

    switch (field.content) {
      case RevealContent _:
        break; // reveal has no config to carry over
      case TextInputContent c:
        textHint = c.hint ?? '';
        exactMatch = c.exactMatch;
      case MultipleChoiceContent c:
        for (final opt in c.options ?? []) {
          optionControllers.add(TextEditingController(text: opt));
        }
    }

    while (optionControllers.length < 2) {
      optionControllers.add(TextEditingController());
    }

    return _TplFieldState(
      fieldId: field.fieldId,
      type: field.type,
      nameController: TextEditingController(text: field.name),
      textHintController: TextEditingController(text: textHint),
      exactMatch: exactMatch,
      optionControllers: optionControllers,
    );
  }

  // Build a CardField with null answers — correct for template storage.
  CardField toCardField() {
    final CardFieldContent content;
    if (type == AppConstants.fieldTypeReveal) {
      content = const RevealContent(answer: null);
    } else if (type == AppConstants.fieldTypeTextInput) {
      content = TextInputContent(
        correctAnswers: null,
        hint: textHintController.text.trim().isEmpty
            ? null
            : textHintController.text.trim(),
        exactMatch: exactMatch,
      );
    } else {
      // multiple_choice
      content = MultipleChoiceContent(
        options: optionControllers.map((c) => c.text.trim()).toList(),
        correctIndex: null,
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
    textHintController.dispose();
    for (final c in optionControllers) {
      c.dispose();
    }
  }
}

// ---------------------------------------------------------------------------
// TemplateFormScreen — create or edit a CardTemplate.
//
// Three entry points:
//   TemplateFormScreen()                    — blank create from scratch
//   TemplateFormScreen(template: t)         — edit existing template
//   TemplateFormScreen(initialFields: f)    — create from card fields
//     (fields come pre-converted with answers nulled out by the caller)
// ---------------------------------------------------------------------------
class TemplateFormScreen extends ConsumerStatefulWidget {
  final CardTemplate? template;
  final List<CardField>? initialFields; // pre-populated from a card's fields

  const TemplateFormScreen({super.key, this.template, this.initialFields});

  @override
  ConsumerState<TemplateFormScreen> createState() => _TemplateFormScreenState();
}

class _TemplateFormScreenState extends ConsumerState<TemplateFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _descController;
  final List<_TplFieldState> _fields = [];
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
      _fields.addAll(t.fields.map(_TplFieldState.fromCardField));
    } else if (widget.initialFields != null) {
      _fields.addAll(widget.initialFields!.map(_TplFieldState.fromCardField));
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    for (final f in _fields) {
      f.dispose();
    }
    super.dispose();
  }

  void _addField() => setState(() => _fields.add(_TplFieldState.empty()));

  void _removeField(int index) {
    setState(() {
      _fields[index].dispose();
      _fields.removeAt(index);
    });
  }

  void _addOption(int fieldIndex) {
    setState(() =>
        _fields[fieldIndex].optionControllers.add(TextEditingController()));
  }

  void _removeOption(int fieldIndex, int optionIndex) {
    final field = _fields[fieldIndex];
    if (field.optionControllers.length <= 2) return;
    setState(() {
      field.optionControllers[optionIndex].dispose();
      field.optionControllers.removeAt(optionIndex);
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _isSaving = true);
    try {
      final uid = ref.read(authStateProvider).asData?.value ?? '';
      final fields = _fields.map((f) => f.toCardField()).toList();

      if (!_isEditing) {
        await ref.read(templateRepositoryProvider).createTemplate(
              CardTemplate(
                id: '',
                createdBy: uid,
                name: _nameController.text.trim(),
                description: _descController.text.trim().isEmpty
                    ? null
                    : _descController.text.trim(),
                fields: fields,
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
                fields: fields,
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
          'Cards created from it keep their fields; this cannot be undone.',
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

  // --- field content builders -----------------------------------------------

  // Reveal fields have no configurable content in a template.
  Widget _buildRevealContent() {
    return Text(
      'Answer is filled in per card.',
      style: Theme.of(context)
          .textTheme
          .bodySmall
          ?.copyWith(color: Theme.of(context).colorScheme.outline),
    );
  }

  Widget _buildTextInputContent(_TplFieldState field) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: field.textHintController,
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
          value: field.exactMatch,
          onChanged: (v) => setState(() => field.exactMatch = v),
          contentPadding: EdgeInsets.zero,
          dense: true,
        ),
      ],
    );
  }

  Widget _buildMultipleChoiceContent(_TplFieldState field, int fieldIndex) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Options (pre-filled for all cards using this template)',
            style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 8),
        ...List.generate(field.optionControllers.length, (optIdx) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
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
                    child: Text('Reveal on click')),
                DropdownMenuItem(
                    value: AppConstants.fieldTypeTextInput,
                    child: Text('Text input')),
                DropdownMenuItem(
                    value: AppConstants.fieldTypeMultipleChoice,
                    child: Text('Multiple choice')),
              ],
              onChanged: (v) {
                if (v != null) setState(() => field.type = v);
              },
            ),
            const SizedBox(height: 12),
            if (field.type == AppConstants.fieldTypeReveal)
              _buildRevealContent(),
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

              // --- Fields ---
              const SizedBox(height: 24),
              Text('Fields', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(
                'Define the structure. Answers are filled in per card.',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Theme.of(context).colorScheme.outline),
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
