import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flash_me/models/card_question.dart';
import 'package:flash_me/models/card_set.dart';
import 'package:flash_me/models/card_template.dart';
import 'package:flash_me/models/flash_card.dart';
import 'package:flash_me/providers/auth_provider.dart';
import 'package:flash_me/providers/card_provider.dart';
import 'package:flash_me/providers/tag_provider.dart';
import 'package:flash_me/utils/helpers.dart';
import 'package:flash_me/providers/language_provider.dart';
import 'package:flash_me/providers/storage_provider.dart';
import 'package:flash_me/providers/question_template_provider.dart';
import 'package:flash_me/providers/template_provider.dart';
import 'package:flash_me/models/question_template.dart';
import 'package:flash_me/utils/constants.dart';
import 'package:flash_me/screens/templates/template_form_screen.dart';
import 'package:flash_me/widgets/language_picker.dart';

// ---------------------------------------------------------------------------
// _TemplatePickerSheet — two-tab bottom sheet.
// Tab 0: Card Templates — returns a CardTemplate (replaces all questions).
// Tab 1: Question Templates — returns a QuestionTemplate (appends one question).
// ---------------------------------------------------------------------------
class _TemplatePickerSheet extends ConsumerStatefulWidget {
  final List<CardTemplate> cardTemplates;
  const _TemplatePickerSheet({required this.cardTemplates});

  @override
  ConsumerState<_TemplatePickerSheet> createState() =>
      _TemplatePickerSheetState();
}

class _TemplatePickerSheetState extends ConsumerState<_TemplatePickerSheet>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final questionTemplates =
        ref.watch(userQuestionTemplatesProvider).asData?.value ?? [];

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.55,
      minChildSize: 0.35,
      maxChildSize: 0.9,
      builder: (ctx, _) => Column(
        children: [
          // Drag handle.
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
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Text('Use Template',
                style: Theme.of(context).textTheme.titleMedium),
          ),
          TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: 'Card Templates'),
              Tab(text: 'Question Templates'),
            ],
          ),
          const Divider(height: 1),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Card templates — selecting one replaces all questions.
                _buildList(
                  context,
                  items: widget.cardTemplates,
                  icon: Icons.copy_all_outlined,
                  emptyMessage: 'No card templates yet.',
                  title: (t) => t.name,
                  subtitle: (t) {
                    final n = t.questions.length;
                    final s = '$n question${n == 1 ? '' : 's'}';
                    return t.description != null
                        ? '${t.description}  ·  $s'
                        : s;
                  },
                  onTap: (t) => Navigator.of(ctx).pop(t),
                ),
                // Question templates — selecting one appends a single question.
                _buildList(
                  context,
                  items: questionTemplates,
                  icon: Icons.quiz_outlined,
                  emptyMessage: 'No question templates yet.',
                  title: (t) => t.name,
                  subtitle: (t) => t.description ?? _questionTypeLabel(t),
                  onTap: (t) => Navigator.of(ctx).pop(t),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Generic list builder used for both tabs.
  Widget _buildList<T>(
    BuildContext context, {
    required List<T> items,
    required IconData icon,
    required String emptyMessage,
    required String Function(T) title,
    required String Function(T) subtitle,
    required void Function(T) onTap,
  }) {
    if (items.isEmpty) {
      return Center(
        child: Text(emptyMessage,
            style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant)),
      );
    }
    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (_, i) {
        final item = items[i];
        return ListTile(
          leading: Icon(icon),
          title: Text(title(item)),
          subtitle: Text(subtitle(item),
              maxLines: 1, overflow: TextOverflow.ellipsis),
          onTap: () => onTap(item),
        );
      },
    );
  }

  String _questionTypeLabel(QuestionTemplate t) => switch (t.question) {
        TextInputQuestion _ => 'Text input',
        MultipleChoiceQuestion _ => 'Multiple choice',
        WordOrderQuestion _ => 'Word order',
      };
}

// ---------------------------------------------------------------------------
// _QuestionState — mutable holder for one question while the form is open.
//
// Holds controllers for every question type so the user's input survives
// type-switcher changes (e.g. typing answers, switching type and back).
// ---------------------------------------------------------------------------
class _QuestionState {
  final String questionId;
  String type; // AppConstants.fieldType*
  final TextEditingController promptController; // optional label shown above the question
  // text_input
  final TextEditingController textAnswersController; // comma-separated answers
  final TextEditingController textHintController;
  bool exactMatch;
  // multiple_choice
  final List<TextEditingController> optionControllers;
  int? correctOptionIndex;

  _QuestionState({
    required this.questionId,
    required this.type,
    required this.promptController,
    required this.textAnswersController,
    required this.textHintController,
    this.exactMatch = false,
    required this.optionControllers,
    this.correctOptionIndex,
  });

  // Blank question defaulting to text-input type with 2 empty MC options pre-allocated.
  factory _QuestionState.empty() => _QuestionState(
        questionId: CardQuestion.generateId(),
        type: AppConstants.fieldTypeTextInput,
        promptController: TextEditingController(),
        textAnswersController: TextEditingController(),
        textHintController: TextEditingController(),
        optionControllers: [TextEditingController(), TextEditingController()],
      );

  // Populate controllers from an existing CardQuestion (edit mode or template apply).
  factory _QuestionState.fromQuestion(CardQuestion q) {
    String textAnswers = '';
    String textHint = '';
    bool exactMatch = false;
    final List<TextEditingController> optionControllers = [];
    int? correctIndex;

    switch (q) {
      case TextInputQuestion q:
        textAnswers = q.correctAnswers?.join(', ') ?? '';
        textHint = q.hint ?? '';
        exactMatch = q.exactMatch;
      case MultipleChoiceQuestion q:
        for (final opt in q.options ?? []) {
          optionControllers.add(TextEditingController(text: opt));
        }
        correctIndex = q.correctIndex;
      case WordOrderQuestion _:
        break; // word_order editing not yet implemented in this form (Step 3)
    }

    while (optionControllers.length < 2) {
      optionControllers.add(TextEditingController());
    }

    return _QuestionState(
      questionId: q.questionId,
      type: switch (q) {
        TextInputQuestion _ => AppConstants.fieldTypeTextInput,
        MultipleChoiceQuestion _ => AppConstants.fieldTypeMultipleChoice,
        WordOrderQuestion _ => AppConstants.fieldTypeTextInput, // fallback until Step 3
      },
      promptController: TextEditingController(text: q.prompt ?? ''),
      textAnswersController: TextEditingController(text: textAnswers),
      textHintController: TextEditingController(text: textHint),
      exactMatch: exactMatch,
      optionControllers: optionControllers,
      correctOptionIndex: correctIndex,
    );
  }

  // Build a CardQuestion from the current state of all controllers.
  CardQuestion toQuestion() {
    final prompt = promptController.text.trim().isEmpty
        ? null
        : promptController.text.trim();
    if (type == AppConstants.fieldTypeTextInput) {
      final answers = textAnswersController.text
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
      return TextInputQuestion(
        questionId: questionId,
        prompt: prompt,
        correctAnswers: answers,
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
        correctIndex: correctOptionIndex,
      );
    }
  }

  // Build a CardQuestion with answers nulled out for template storage.
  CardQuestion toTemplateQuestion() {
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
// Pass [parentSet] when creating from inside a set — its language pair is used as default.
// ---------------------------------------------------------------------------
class CardFormScreen extends ConsumerStatefulWidget {
  final FlashCard? card;
  final CardSet? parentSet; // non-null when creating from a set's "add card" flow
  const CardFormScreen({super.key, this.card, this.parentSet});

  @override
  ConsumerState<CardFormScreen> createState() => _CardFormScreenState();
}

class _CardFormScreenState extends ConsumerState<CardFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _primaryWordController;
  late final TextEditingController _translationController;
  final _tagInputController = TextEditingController();

  List<String> _tags = [];
  final List<_QuestionState> _questions = [];
  String? _nativeLanguage;
  String? _targetLanguage;
  bool _primaryWordHidden = false;
  bool _isSaving = false;

  // Pre-generated Firestore ID used as the Storage path prefix for new cards.
  late final String _pendingCardId;

  // Pending media picked but not yet uploaded.
  Uint8List? _pendingImageBytes;
  String? _pendingImageExt;
  Uint8List? _pendingAudioBytes;
  String? _pendingAudioExt;

  // True when the user has tapped the clear button for existing media.
  bool _clearImage = false;
  bool _clearAudio = false;

  bool get _isEditing => widget.card != null;

  @override
  void initState() {
    super.initState();
    final card = widget.card;
    // Pre-generate a Firestore ID so Storage paths can be set before the doc exists.
    _pendingCardId = card?.id.isNotEmpty == true
        ? card!.id
        : ref.read(cardRepositoryProvider).generateId();
    _primaryWordController =
        TextEditingController(text: card?.primaryWord ?? '');
    _translationController =
        TextEditingController(text: card?.translation ?? '');
    _tags = List.from(card?.tags ?? []);
    if (card != null) {
      _questions.addAll(card.questions.map(_QuestionState.fromQuestion));
      _nativeLanguage = card.nativeLanguage;
      _targetLanguage = card.targetLanguage;
      _primaryWordHidden = card.primaryWordHidden;
    } else if (widget.parentSet != null) {
      // Creating inside a set: inherit the set's language pair.
      _nativeLanguage = widget.parentSet!.nativeLanguage;
      _targetLanguage = widget.parentSet!.targetLanguage;
    } else {
      // Creating in the Cards section: inherit from the last card this session.
      final last = ref.read(lastUsedLanguagesProvider);
      _nativeLanguage = last?.native;
      _targetLanguage = last?.target;
    }
  }

  @override
  void dispose() {
    _primaryWordController.dispose();
    _translationController.dispose();
    _tagInputController.dispose();
    for (final q in _questions) {
      q.dispose();
    }
    super.dispose();
  }

  void _addQuestion() {
    setState(() => _questions.add(_QuestionState.empty()));
  }

  // Disposes existing questions, then populates from the template's question structure.
  // Answers are left blank; config (options, hints, exactMatch) is carried over.
  void _applyTemplate(CardTemplate template) {
    setState(() {
      for (final q in _questions) {
        q.dispose();
      }
      _questions.clear();
      _questions.addAll(template.questions.map(_QuestionState.fromQuestion));
    });
  }

  // Opens the two-tab template picker.
  // CardTemplate result → replaces all questions (with confirmation if any exist).
  // QuestionTemplate result → appends a single question.
  Future<void> _showTemplatePicker() async {
    final cardTemplates =
        ref.read(userTemplatesProvider).asData?.value ?? [];

    final result = await showModalBottomSheet<Object>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _TemplatePickerSheet(cardTemplates: cardTemplates),
    );
    if (result == null || !mounted) return;

    if (result is CardTemplate) {
      if (_questions.isNotEmpty) {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Replace questions?'),
            content: Text(
              'Apply "${result.name}"? '
              'Your current questions will be replaced.',
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
      _applyTemplate(result);
    } else if (result is QuestionTemplate) {
      _appendQuestionFromTemplate(result);
    }
  }

  // Appends a question from a QuestionTemplate with a fresh questionId.
  void _appendQuestionFromTemplate(QuestionTemplate qt) {
    final freshQuestion = switch (qt.question) {
      TextInputQuestion q =>
        q.copyWith(questionId: CardQuestion.generateId()),
      MultipleChoiceQuestion q =>
        q.copyWith(questionId: CardQuestion.generateId()),
      WordOrderQuestion q =>
        q.copyWith(questionId: CardQuestion.generateId()),
    };
    setState(() => _questions.add(_QuestionState.fromQuestion(freshQuestion)));
  }

  void _removeQuestion(int index) {
    setState(() {
      _questions[index].dispose();
      _questions.removeAt(index);
    });
  }

  void _addOption(int qIndex) {
    setState(() => _questions[qIndex].optionControllers
        .add(TextEditingController()));
  }

  // Keeps minimum 2 options; adjusts correctOptionIndex when an option is removed.
  void _removeOption(int qIndex, int optionIndex) {
    final q = _questions[qIndex];
    if (q.optionControllers.length <= 2) return;
    setState(() {
      q.optionControllers[optionIndex].dispose();
      q.optionControllers.removeAt(optionIndex);
      if (q.correctOptionIndex == optionIndex) {
        q.correctOptionIndex = null;
      } else if (q.correctOptionIndex != null &&
          q.correctOptionIndex! > optionIndex) {
        q.correctOptionIndex = q.correctOptionIndex! - 1;
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

  // Returns the MIME type string for a file extension.
  String _mimeForExt(String ext) => switch (ext.toLowerCase()) {
        'jpg' || 'jpeg' => 'image/jpeg',
        'png' => 'image/png',
        'webp' => 'image/webp',
        'gif' => 'image/gif',
        'mp3' => 'audio/mpeg',
        'm4a' => 'audio/mp4',
        'aac' => 'audio/aac',
        'wav' => 'audio/wav',
        'ogg' => 'audio/ogg',
        _ => 'application/octet-stream',
      };

  Future<void> _pickImage() async {
    final result = await FilePicker.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null) return;
    final ext = (file.extension ?? 'jpg').toLowerCase();
    setState(() {
      _pendingImageBytes = bytes;
      _pendingImageExt = ext;
      _clearImage = false;
    });
  }

  void _removeImageMedia() {
    setState(() {
      _pendingImageBytes = null;
      _pendingImageExt = null;
      _clearImage = true;
    });
  }

  Future<void> _pickAudio() async {
    final result = await FilePicker.pickFiles(
      type: FileType.audio,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null) return;
    final ext = (file.extension ?? 'mp3').toLowerCase();
    setState(() {
      _pendingAudioBytes = bytes;
      _pendingAudioExt = ext;
      _clearAudio = false;
    });
  }

  void _removeAudioMedia() {
    setState(() {
      _pendingAudioBytes = null;
      _pendingAudioExt = null;
      _clearAudio = true;
    });
  }

  // Uploads pending media and deletes removed media; returns the final URLs.
  Future<({String? imageUrl, String? audioUrl})> _resolveMediaUrls() async {
    final storage = ref.read(storageRepositoryProvider);
    final uid = ref.read(authStateProvider).asData?.value ?? '';
    final cardId = _pendingCardId;

    String? imageUrl = widget.card?.primaryImageUrl;
    if (_clearImage) {
      if (imageUrl != null) await storage.deleteFileByUrl(imageUrl);
      imageUrl = null;
    } else if (_pendingImageBytes != null) {
      if (imageUrl != null) await storage.deleteFileByUrl(imageUrl);
      imageUrl = await storage.uploadFile(
        path: 'users/$uid/cards/$cardId/image.$_pendingImageExt',
        bytes: _pendingImageBytes!,
        contentType: _mimeForExt(_pendingImageExt!),
      );
    }

    String? audioUrl = widget.card?.primaryAudioUrl;
    if (_clearAudio) {
      if (audioUrl != null) await storage.deleteFileByUrl(audioUrl);
      audioUrl = null;
    } else if (_pendingAudioBytes != null) {
      if (audioUrl != null) await storage.deleteFileByUrl(audioUrl);
      audioUrl = await storage.uploadFile(
        path: 'users/$uid/cards/$cardId/audio.$_pendingAudioExt',
        bytes: _pendingAudioBytes!,
        contentType: _mimeForExt(_pendingAudioExt!),
      );
    }

    return (imageUrl: imageUrl, audioUrl: audioUrl);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    // Check that every multiple-choice question has a correct option selected.
    for (int i = 0; i < _questions.length; i++) {
      final q = _questions[i];
      if (q.type == AppConstants.fieldTypeMultipleChoice &&
          q.correctOptionIndex == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Question "${q.promptController.text.trim().isEmpty ? i + 1 : q.promptController.text.trim()}": '
              'select the correct option.',
            ),
          ),
        );
        return;
      }
    }

    FocusScope.of(context).unfocus();
    setState(() => _isSaving = true);
    try {
      final uid = ref.read(authStateProvider).asData?.value ?? '';
      final tagRepo = ref.read(tagRepositoryProvider);
      final questions = _questions.map((q) => q.toQuestion()).toList();
      final media = await _resolveMediaUrls();

      // Normalise tags before writing to Firestore so the stored value
      // matches the global tags/{normalizedName} document ID.
      final normalizedTags = _tags
          .map(AppHelpers.normalizeTag)
          .where((t) => t.isNotEmpty)
          .toList();

      if (!_isEditing) {
        await ref.read(cardRepositoryProvider).createCard(
              FlashCard(
                id: _pendingCardId,
                primaryWord: _primaryWordController.text.trim(),
                translation: _translationController.text.trim(),
                primaryImageUrl: media.imageUrl,
                primaryAudioUrl: media.audioUrl,
                primaryWordHidden: _primaryWordHidden,
                questions: questions,
                tags: normalizedTags,
                nativeLanguage: _nativeLanguage,
                targetLanguage: _targetLanguage,
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
                createdBy: uid,
              ),
            );
        // Remember the language pair for the next card created this session.
        ref.read(lastUsedLanguagesProvider.notifier).set(
              (native: _nativeLanguage, target: _targetLanguage),
            );
        // Upsert all tags — fire-and-forget so a count failure never
        // blocks the card save.
        for (final tag in normalizedTags) {
          tagRepo.upsertTag(tag, uid);
        }
      } else {
        final (toUpsert, toDecrement) =
            AppHelpers.diffTags(widget.card!.tags, normalizedTags);
        await ref.read(cardRepositoryProvider).updateCard(
              widget.card!.copyWith(
                primaryWord: _primaryWordController.text.trim(),
                translation: _translationController.text.trim(),
                primaryImageUrl: media.imageUrl,
                primaryAudioUrl: media.audioUrl,
                primaryWordHidden: _primaryWordHidden,
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
          const SnackBar(
              content: Text('Failed to save card. Please try again.')),
        );
      }
    }
  }

  // Null out answer fields from the current card's questions so the template
  // stores structure and config (options, hints) but not answers.
  void _saveAsTemplate() {
    final templateQuestions =
        _questions.map((q) => q.toTemplateQuestion()).toList();

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TemplateFormScreen(initialQuestions: templateQuestions),
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
      // Capture tags before deleting — decrement fire-and-forget after.
      final tagsToDecrement = widget.card!.tags
          .map(AppHelpers.normalizeTag)
          .where((t) => t.isNotEmpty)
          .toList();
      final tagRepo = ref.read(tagRepositoryProvider);
      await ref
          .read(cardRepositoryProvider)
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
          const SnackBar(
              content: Text('Failed to delete card. Please try again.')),
        );
      }
    }
  }

  // --- question content builders --------------------------------------------

  Widget _buildTextInputContent(_QuestionState q) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: q.textAnswersController,
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
          controller: q.textHintController,
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

  Widget _buildMultipleChoiceContent(_QuestionState q, int qIndex) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Options * (select the correct one)',
            style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 8),
        // RadioGroup manages the selected index for all Radio children.
        RadioGroup<int>(
          groupValue: q.correctOptionIndex,
          onChanged: (v) => setState(() => q.correctOptionIndex = v),
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
                    // Remove only allowed when more than 2 options exist.
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
          ),
        ),
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
                  child: Text('Text input'),
                ),
                DropdownMenuItem(
                  value: AppConstants.fieldTypeMultipleChoice,
                  child: Text('Multiple choice'),
                ),
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

  // --- media pickers --------------------------------------------------------

  Widget _buildImagePicker(BuildContext context) {
    final existingUrl = widget.card?.primaryImageUrl;
    final hasImage = _pendingImageBytes != null ||
        (existingUrl != null && !_clearImage);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Thumbnail or empty-state tap target.
        GestureDetector(
          onTap: _isSaving ? null : _pickImage,
          child: Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              border: Border.all(color: Theme.of(context).colorScheme.outline),
              borderRadius: BorderRadius.circular(8),
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
            ),
            clipBehavior: Clip.antiAlias,
            child: hasImage
                ? (_pendingImageBytes != null
                    ? Image.memory(_pendingImageBytes!, fit: BoxFit.cover)
                    : Image.network(existingUrl!, fit: BoxFit.cover,
                        errorBuilder: (_, _, _) =>
                            const Icon(Icons.broken_image_outlined)))
                : const Icon(Icons.image_outlined, size: 36),
          ),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextButton.icon(
              onPressed: _isSaving ? null : _pickImage,
              icon: const Icon(Icons.upload_outlined),
              label: Text(hasImage ? 'Replace image' : 'Add image'),
            ),
            if (hasImage)
              TextButton.icon(
                onPressed: _isSaving ? null : _removeImageMedia,
                icon: const Icon(Icons.delete_outline),
                label: const Text('Remove'),
                style: TextButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.error),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildAudioPicker(BuildContext context) {
    final existingUrl = widget.card?.primaryAudioUrl;
    final hasAudio = _pendingAudioBytes != null ||
        (existingUrl != null && !_clearAudio);
    final label = _pendingAudioBytes != null
        ? 'New audio clip selected'
        : (hasAudio ? 'Audio clip attached' : null);

    return Row(
      children: [
        Icon(
          hasAudio ? Icons.audio_file : Icons.audio_file_outlined,
          color: hasAudio
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.outline,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label ?? 'No audio clip',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
        TextButton(
          onPressed: _isSaving ? null : _pickAudio,
          child: Text(hasAudio ? 'Replace' : 'Add audio'),
        ),
        if (hasAudio)
          IconButton(
            icon: const Icon(Icons.delete_outline),
            color: Theme.of(context).colorScheme.error,
            tooltip: 'Remove audio',
            onPressed: _isSaving ? null : _removeAudioMedia,
          ),
      ],
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
        child: IgnorePointer(
          ignoring: _isSaving,
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
              const SizedBox(height: 4),
              SwitchListTile(
                title: const Text('Hide hint word during study'),
                subtitle: const Text(
                    'Show only the image/audio at first; reveal the text hint on demand'),
                value: _primaryWordHidden,
                onChanged: (v) => setState(() => _primaryWordHidden = v),
                contentPadding: EdgeInsets.zero,
                dense: true,
              ),

              // --- Media ---
              const SizedBox(height: 24),
              Text('Media', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              Text('Optional image and audio for the primary field.',
                  style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 12),
              _buildImagePicker(context),
              const SizedBox(height: 12),
              _buildAudioPicker(context),

              // --- Languages ---
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

              // --- Additional questions ---
              const SizedBox(height: 24),
              // "Use Template" button sits alongside the section header.
              Row(
                children: [
                  Text('Additional Questions',
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
              ..._questions.asMap().entries.map((e) => _buildQuestionCard(e.key)),
              OutlinedButton.icon(
                onPressed: _addQuestion,
                icon: const Icon(Icons.add),
                label: const Text('Add Question'),
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
      ),
    );
  }
}
