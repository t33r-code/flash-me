import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flash_me/l10n/app_localizations.dart';
import 'package:flash_me/models/card_question.dart';
import 'package:flash_me/models/card_template.dart';
import 'package:flash_me/models/question_template.dart';
import 'package:flash_me/providers/question_template_provider.dart';
import 'package:flash_me/providers/template_provider.dart';
import 'package:flash_me/utils/extensions.dart';

// ---------------------------------------------------------------------------
// Shared template picker used by both the flash-card and workbook-card forms.
//
// - showTemplatePicker(): opens the sheet and returns the user's choice.
//     • CardTemplate result  → caller replaces all questions.
//     • QuestionTemplate result → caller appends a single question.
//     • null → dismissed.
// - confirmReplaceQuestions(): the shared "replace existing questions?" dialog.
//
// The result-handling stays in each form because each owns its own mutable
// question-state type; this widget only surfaces the choice.
// ---------------------------------------------------------------------------

// Opens the two-tab template picker as a modal bottom sheet.
// Reads the user's card templates from the provider; the sheet reads question
// templates itself. Returns a CardTemplate, a QuestionTemplate, or null.
Future<Object?> showTemplatePicker(BuildContext context, WidgetRef ref) {
  final cardTemplates = ref.read(userTemplatesProvider).asData?.value ?? [];
  return showModalBottomSheet<Object>(
    context: context,
    isScrollControlled: true,
    builder: (_) => TemplatePickerSheet(cardTemplates: cardTemplates),
  );
}

// Confirmation shown before a CardTemplate replaces a card's existing questions.
Future<bool> confirmReplaceQuestions(
    BuildContext context, String templateName) async {
  final l10n = context.l10n;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(l10n.titleReplaceQuestions),
      content: Text(l10n.messageReplaceQuestionsConfirm(templateName)),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text(l10n.labelCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(l10n.actionReplace),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}

// ---------------------------------------------------------------------------
// TemplatePickerSheet — two-tab bottom sheet.
// Tab 0: Card Templates — pops a CardTemplate (caller replaces all questions).
// Tab 1: Question Templates — pops a QuestionTemplate (caller appends one).
// ---------------------------------------------------------------------------
class TemplatePickerSheet extends ConsumerStatefulWidget {
  final List<CardTemplate> cardTemplates;
  const TemplatePickerSheet({super.key, required this.cardTemplates});

  @override
  ConsumerState<TemplatePickerSheet> createState() =>
      _TemplatePickerSheetState();
}

class _TemplatePickerSheetState extends ConsumerState<TemplatePickerSheet>
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
    final l10n = context.l10n;
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
            child: Text(l10n.actionUseTemplate,
                style: Theme.of(context).textTheme.titleMedium),
          ),
          TabBar(
            controller: _tabController,
            tabs: [
              Tab(text: l10n.tabCardTemplates),
              Tab(text: l10n.tabQuestionTemplates),
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
                  emptyMessage: l10n.messageNoCardTemplatesYet,
                  title: (t) => t.name,
                  subtitle: (t) {
                    final n = t.questions.length;
                    final s = l10n.labelQuestionCount(n);
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
                  emptyMessage: l10n.messageNoQuestionTemplatesYet,
                  title: (t) => t.name,
                  subtitle: (t) => t.description ?? _questionTypeLabel(t, l10n),
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

  String _questionTypeLabel(QuestionTemplate t, AppLocalizations l10n) =>
      switch (t.question) {
        TextInputQuestion _ => l10n.labelQuestionTypeTextInput,
        MultipleChoiceQuestion _ => l10n.labelQuestionTypeMultipleChoice,
        WordOrderQuestion _ => l10n.labelQuestionTypeWordOrder,
        FillInTheBlanksQuestion _ => l10n.labelQuestionTypeFillInBlanks,
        GridQuestion _ => l10n.labelQuestionTypeGrid,
      };
}
