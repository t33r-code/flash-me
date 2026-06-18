import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flash_me/models/card_set.dart';
import 'package:flash_me/providers/auth_provider.dart';
import 'package:flash_me/providers/card_set_provider.dart';
import 'package:flash_me/providers/tag_provider.dart';
import 'package:flash_me/utils/extensions.dart';
import 'package:flash_me/utils/helpers.dart';
import 'package:flash_me/widgets/tag_input_field.dart';
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
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _isSaving = true);
    try {
      final uid = ref.read(authStateProvider).asData?.value ?? '';
      final repo = ref.read(cardSetRepositoryProvider);
      final tagRepo = ref.read(tagRepositoryProvider);

      final normalizedTags = _tags
          .map(AppHelpers.normalizeTag)
          .where((t) => t.isNotEmpty)
          .toList();

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
          tags: normalizedTags,
          color: _selectedColor,
          nativeLanguage: _nativeLanguage,
          targetLanguage: _targetLanguage,
        ));
        for (final tag in normalizedTags) { tagRepo.upsertTag(tag, uid); }
      } else {
        final (toUpsert, toDecrement) =
            AppHelpers.diffTags(widget.cardSet!.tags, normalizedTags);
        await repo.updateSet(widget.cardSet!.copyWith(
          name: _nameController.text.trim(),
          description: _descController.text.trim().isEmpty
              ? null
              : _descController.text.trim(),
          tags: normalizedTags,
          color: _selectedColor,
          nativeLanguage: _nativeLanguage,
          targetLanguage: _targetLanguage,
        ));
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
          SnackBar(content: Text(context.l10n.errorFailedSaveSet)),
        );
      }
    }
  }

  // Parse a '#RRGGBB' hex string to a Flutter Color.
  Color _hexColor(String hex) {
    final h = hex.replaceFirst('#', '');
    return Color(int.parse('ff$h', radix: 16));
  }

  Widget _buildColorPicker() {
    final l10n = context.l10n;
    // Map each hex to its localized accessibility label.
    final colorLabels = <String?, String>{
      null: l10n.semanticsColorNone,
      '#EF5350': l10n.semanticsColorRed,
      '#FF7043': l10n.semanticsColorDeepOrange,
      '#FFCA28': l10n.semanticsColorAmber,
      '#66BB6A': l10n.semanticsColorGreen,
      '#26A69A': l10n.semanticsColorTeal,
      '#42A5F5': l10n.semanticsColorBlue,
      '#5C6BC0': l10n.semanticsColorIndigo,
      '#AB47BC': l10n.semanticsColorPurple,
      '#EC407A': l10n.semanticsColorPink,
    };
    return Wrap(
      spacing: 0,
      runSpacing: 0,
      children: _colorPalette.map((hex) {
        final selected = _selectedColor == hex;
        final itemColor =
            hex == null ? Colors.transparent : _hexColor(hex);
        final colorLabel = colorLabels[hex] ?? hex ?? '';
        // Semantics label announces colour name and selection state.
        // SizedBox expands the hit area to 48dp without changing the 36dp visual.
        return Semantics(
          label: selected ? l10n.semanticsColorSelected(colorLabel) : colorLabel,
          button: true,
          child: GestureDetector(
            onTap: _isSaving ? null : () => setState(() => _selectedColor = hex),
            child: SizedBox(
              width: 48,
              height: 48,
              child: Center(
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
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? l10n.titleEditSet : l10n.titleNewSet),
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
                enabled: !_isSaving,
                decoration: InputDecoration(
                  labelText: l10n.labelSetNameRequired,
                  hintText: l10n.hintSetNameExample,
                  border: const OutlineInputBorder(),
                ),
                validator: (v) =>
                    v?.trim().isEmpty ?? true ? l10n.validatorSetNameRequired : null,
              ),
              const SizedBox(height: 12),

              // --- Description ---
              TextFormField(
                controller: _descController,
                enabled: !_isSaving,
                decoration: InputDecoration(
                  labelText: l10n.labelDescriptionOptional,
                  border: const OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 24),

              // --- Languages ---
              Text(l10n.titleLanguagesSection,
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              LanguagePicker(
                label: l10n.labelTargetLanguage,
                value: _targetLanguage,
                enabled: !_isSaving,
                onChanged: (v) => setState(() => _targetLanguage = v),
              ),
              const SizedBox(height: 12),
              LanguagePicker(
                label: l10n.labelNativeLanguage,
                value: _nativeLanguage,
                enabled: !_isSaving,
                onChanged: (v) => setState(() => _nativeLanguage = v),
              ),
              const SizedBox(height: 24),

              // --- Colour ---
              Text(l10n.titleColorSection,
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              _buildColorPicker(),
              const SizedBox(height: 24),

              // --- Tags ---
              Text(l10n.titleTagsSection,
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              TagInputField(
                tags: _tags,
                enabled: !_isSaving,
                onChanged: (updated) => setState(() => _tags = updated),
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
                          : Text(
                              _isEditing ? l10n.actionSaveChanges : l10n.actionCreateSet),
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
