import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flash_me/models/card_set.dart';
import 'package:flash_me/providers/auth_provider.dart';
import 'package:flash_me/providers/card_set_provider.dart';
import 'package:flash_me/widgets/language_picker.dart';

// ---------------------------------------------------------------------------
// SetFormScreen — create or edit a CardSet.
// Pass [cardSet] to pre-populate in edit mode; omit for create mode.
// ---------------------------------------------------------------------------
class SetFormScreen extends ConsumerStatefulWidget {
  final CardSet? cardSet;
  const SetFormScreen({super.key, this.cardSet});

  @override
  ConsumerState<SetFormScreen> createState() => _SetFormScreenState();
}

class _SetFormScreenState extends ConsumerState<SetFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _descController;
  final _tagInputController = TextEditingController();

  List<String> _tags = [];
  String? _selectedColor;
  String? _nativeLanguage;
  String? _targetLanguage;
  bool _isSaving = false;

  bool get _isEditing => widget.cardSet != null;

  // Predefined colour palette; null means no colour assigned.
  static const List<String?> _colorPalette = [
    null,
    '#EF5350', // red
    '#FF7043', // deep orange
    '#FFCA28', // amber
    '#66BB6A', // green
    '#26A69A', // teal
    '#42A5F5', // blue
    '#5C6BC0', // indigo
    '#AB47BC', // purple
    '#EC407A', // pink
  ];

  @override
  void initState() {
    super.initState();
    final s = widget.cardSet;
    _nameController = TextEditingController(text: s?.name ?? '');
    _descController = TextEditingController(text: s?.description ?? '');
    _tags = List.from(s?.tags ?? []);
    _selectedColor = s?.color;
    _nativeLanguage = s?.nativeLanguage;
    _targetLanguage = s?.targetLanguage;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _tagInputController.dispose();
    super.dispose();
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

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      final uid = ref.read(authStateProvider).asData?.value ?? '';
      final repo = ref.read(cardSetRepositoryProvider);

      if (!_isEditing) {
        await repo.createSet(CardSet(
          id: '',
          userId: uid,
          name: _nameController.text.trim(),
          description: _descController.text.trim().isEmpty
              ? null
              : _descController.text.trim(),
          cardCount: 0,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          tags: _tags,
          color: _selectedColor,
          nativeLanguage: _nativeLanguage,
          targetLanguage: _targetLanguage,
        ));
      } else {
        await repo.updateSet(widget.cardSet!.copyWith(
          name: _nameController.text.trim(),
          description: _descController.text.trim().isEmpty
              ? null
              : _descController.text.trim(),
          tags: _tags,
          color: _selectedColor,
          nativeLanguage: _nativeLanguage,
          targetLanguage: _targetLanguage,
        ));
      }
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Failed to save set. Please try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // Parse a '#RRGGBB' hex string to a Flutter Color.
  Color _hexColor(String hex) {
    final h = hex.replaceFirst('#', '');
    return Color(int.parse('ff$h', radix: 16));
  }

  Widget _buildColorPicker() {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: _colorPalette.map((hex) {
        final selected = _selectedColor == hex;
        final itemColor =
            hex == null ? Colors.transparent : _hexColor(hex);
        return GestureDetector(
          onTap: () => setState(() => _selectedColor = hex),
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: itemColor,
              border: Border.all(
                color: hex == null
                    ? Theme.of(context).colorScheme.outline
                    : itemColor,
                width: selected ? 3 : 1,
              ),
            ),
            child: selected
                ? Icon(
                    Icons.check,
                    size: 20,
                    color: hex == null
                        ? Theme.of(context).colorScheme.onSurface
                        : Colors.white,
                  )
                // "None" option shows a slash icon when unselected.
                : hex == null
                    ? Icon(Icons.block,
                        size: 18,
                        color: Theme.of(context).colorScheme.outline)
                    : null,
          ),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Set' : 'New Set'),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // --- Name ---
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Set name *',
                  hintText: 'e.g. Spanish Verbs',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    v?.trim().isEmpty ?? true ? 'Name is required' : null,
              ),
              const SizedBox(height: 12),

              // --- Description ---
              TextFormField(
                controller: _descController,
                decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 24),

              // --- Languages ---
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
              const SizedBox(height: 24),

              // --- Colour ---
              Text('Colour', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              _buildColorPicker(),
              const SizedBox(height: 24),

              // --- Tags ---
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
                          : Text(
                              _isEditing ? 'Save Changes' : 'Create Set'),
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
