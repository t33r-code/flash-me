import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flash_me/models/card_question.dart';
import 'package:flash_me/models/card_template.dart';
import 'package:flash_me/models/question_template.dart';
import 'package:flash_me/providers/template_provider.dart';
import 'package:flash_me/providers/question_template_provider.dart';
import 'package:flash_me/screens/templates/template_form_screen.dart';
import 'package:flash_me/screens/templates/question_template_form_screen.dart';

// Top-level Templates screen with two tabs: Card Templates and Question Templates.
class TemplatesScreen extends ConsumerWidget {
  const TemplatesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Templates'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Card Templates'),
              Tab(text: 'Question Templates'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _CardTemplatesTab(),
            _QuestionTemplatesTab(),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Card Templates tab
// ---------------------------------------------------------------------------
class _CardTemplatesTab extends ConsumerWidget {
  const _CardTemplatesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final templatesAsync = ref.watch(userTemplatesProvider);
    return Scaffold(
      body: templatesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) =>
            const Center(child: Text('Failed to load templates.')),
        data: (templates) => templates.isEmpty
            ? _emptyState(
                context,
                icon: Icons.copy_all_outlined,
                message: 'No card templates yet.\n'
                    'Tap + to create one, or use "Save as Template" from any card.',
              )
            : ListView.builder(
                padding: const EdgeInsets.all(8),
                itemCount: templates.length,
                itemBuilder: (ctx, i) => _CardTemplateTile(template: templates[i]),
              ),
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'add_card_template',
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const TemplateFormScreen()),
        ),
        tooltip: 'Create card template',
        child: const Icon(Icons.add),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Question Templates tab
// ---------------------------------------------------------------------------
class _QuestionTemplatesTab extends ConsumerWidget {
  const _QuestionTemplatesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final templatesAsync = ref.watch(userQuestionTemplatesProvider);
    return Scaffold(
      body: templatesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) =>
            const Center(child: Text('Failed to load question templates.')),
        data: (templates) => templates.isEmpty
            ? _emptyState(
                context,
                icon: Icons.quiz_outlined,
                message: 'No question templates yet.\n'
                    'Tap + to create a reusable question.',
              )
            : ListView.builder(
                padding: const EdgeInsets.all(8),
                itemCount: templates.length,
                itemBuilder: (ctx, i) =>
                    _QuestionTemplateTile(template: templates[i]),
              ),
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'add_question_template',
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(
              builder: (_) => const QuestionTemplateFormScreen()),
        ),
        tooltip: 'Create question template',
        child: const Icon(Icons.add),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared empty state helper
// ---------------------------------------------------------------------------
Widget _emptyState(BuildContext context,
    {required IconData icon, required String message}) {
  final onSurfaceVariant = Theme.of(context).colorScheme.onSurfaceVariant;
  return Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 80, color: onSurfaceVariant),
          const SizedBox(height: 16),
          Text(
            message,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Card template tile
// ---------------------------------------------------------------------------
class _CardTemplateTile extends StatelessWidget {
  final CardTemplate template;
  const _CardTemplateTile({required this.template});

  @override
  Widget build(BuildContext context) {
    final count = template.questions.length;
    final subtitle = template.description != null
        ? '${template.description}  ·  $count question${count == 1 ? '' : 's'}'
        : '$count question${count == 1 ? '' : 's'}';
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        leading: const Icon(Icons.copy_all_outlined),
        title: Text(template.name),
        subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: Icon(Icons.chevron_right,
            size: 20,
            color: Theme.of(context).colorScheme.onSurfaceVariant),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => TemplateFormScreen(template: template),
        )),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Question template tile
// ---------------------------------------------------------------------------
class _QuestionTemplateTile extends StatelessWidget {
  final QuestionTemplate template;
  const _QuestionTemplateTile({required this.template});

  @override
  Widget build(BuildContext context) {
    final typeLabel = _typeLabel(template.question);
    final subtitle = template.description != null
        ? '${template.description}  ·  $typeLabel'
        : typeLabel;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        leading: const Icon(Icons.quiz_outlined),
        title: Text(template.name),
        subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: Icon(Icons.chevron_right,
            size: 20,
            color: Theme.of(context).colorScheme.onSurfaceVariant),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => QuestionTemplateFormScreen(template: template),
        )),
      ),
    );
  }

  String _typeLabel(CardQuestion q) => switch (q) {
        TextInputQuestion _ => 'Text input',
        MultipleChoiceQuestion _ => 'Multiple choice',
        WordOrderQuestion _ => 'Word order',
      };
}
