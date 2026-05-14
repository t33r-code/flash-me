import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flash_me/models/card_template.dart';
import 'package:flash_me/providers/template_provider.dart';
import 'package:flash_me/screens/templates/template_form_screen.dart';

class TemplatesScreen extends ConsumerWidget {
  const TemplatesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final templatesAsync = ref.watch(userTemplatesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Templates')),
      body: templatesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) =>
            const Center(child: Text('Failed to load templates.')),
        data: (templates) => templates.isEmpty
            ? const _EmptyState()
            : ListView.builder(
                padding: const EdgeInsets.all(8),
                itemCount: templates.length,
                itemBuilder: (ctx, i) => _TemplateTile(template: templates[i]),
              ),
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: null,
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const TemplateFormScreen()),
        ),
        tooltip: 'Create template',
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final onSurfaceVariant = Theme.of(context).colorScheme.onSurfaceVariant;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.copy_all_outlined, size: 80, color: onSurfaceVariant),
            const SizedBox(height: 16),
            Text('No templates yet',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              'Tap + to create a template from scratch, or use '
              '"Save as Template" from any card.',
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
}

class _TemplateTile extends StatelessWidget {
  final CardTemplate template;
  const _TemplateTile({required this.template});

  @override
  Widget build(BuildContext context) {
    final fieldCount = template.fields.length;
    final fieldLabel = '$fieldCount field${fieldCount == 1 ? '' : 's'}';
    // Subtitle: description when available, otherwise fall back to field count.
    // Field count is not shown in trailing to avoid duplication when no description.
    final subtitle = template.description != null
        ? '${template.description}  ·  $fieldLabel'
        : fieldLabel;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        leading: const Icon(Icons.copy_all_outlined),
        title: Text(template.name),
        subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: Icon(
          Icons.chevron_right,
          size: 20,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => TemplateFormScreen(template: template),
          ),
        ),
      ),
    );
  }
}
