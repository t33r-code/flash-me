import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flash_me/models/import_diff.dart';
import 'package:flash_me/providers/auth_provider.dart';
import 'package:flash_me/providers/card_provider.dart';
import 'package:flash_me/providers/card_set_provider.dart';
import 'package:flash_me/providers/import_provider.dart';
import 'package:flash_me/utils/exceptions.dart';

// ---------------------------------------------------------------------------
// DataScreen — account-level import (and future bulk-export) entry point.
// ---------------------------------------------------------------------------
class DataScreen extends ConsumerWidget {
  const DataScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Import & Export')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SectionHeader(title: 'Import', icon: Icons.upload_file_outlined),
          const SizedBox(height: 8),
          Text(
            'Import a ZIP archive exported from Flash Me. '
            'New sets are created automatically; existing sets are '
            'matched by name.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            icon: const Icon(Icons.folder_open_outlined),
            label: const Text('Choose ZIP file…'),
            onPressed: () => _pickAndAnalyze(context, ref),
          ),
        ],
      ),
    );
  }

  Future<void> _pickAndAnalyze(BuildContext context, WidgetRef ref) async {
    // Pick the file.
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['zip'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final bytes = result.files.first.bytes;
    if (bytes == null) return;

    if (!context.mounted) return;

    // Show progress while analyzing.
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Row(children: [
          CircularProgressIndicator(),
          SizedBox(width: 20),
          Text('Analysing archive…'),
        ]),
      ),
    );

    try {
      final uid = ref.read(authStateProvider).asData?.value ?? '';
      final analysis = await ref.read(importServiceProvider).analyze(
            zipBytes: bytes,
            userId: uid,
            cardSetRepo: ref.read(cardSetRepositoryProvider),
            cardRepo: ref.read(cardRepositoryProvider),
          );

      if (!context.mounted) return;
      Navigator.of(context).pop(); // dismiss progress

      // Show preview dialog.
      await showDialog<void>(
        context: context,
        builder: (_) => _ImportPreviewDialog(
          analysis: analysis,
          userId: uid,
          ref: ref,
        ),
      );
    } on AppException catch (e) {
      if (!context.mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (e) {
      if (!context.mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Import failed: $e')),
      );
    }
  }
}

// ---------------------------------------------------------------------------
// Preview dialog — shows the diff and options before the user commits.
// ---------------------------------------------------------------------------
class _ImportPreviewDialog extends StatefulWidget {
  final ImportAnalysis analysis;
  final String userId;
  final WidgetRef ref;

  const _ImportPreviewDialog({
    required this.analysis,
    required this.userId,
    required this.ref,
  });

  @override
  State<_ImportPreviewDialog> createState() => _ImportPreviewDialogState();
}

class _ImportPreviewDialogState extends State<_ImportPreviewDialog> {
  bool _deleteNotInImport = false;
  bool _skipUpdates = false;
  bool _importing = false;

  Future<void> _runImport() async {
    setState(() => _importing = true);
    try {
      await widget.ref.read(importServiceProvider).execute(
            analysis: widget.analysis,
            deleteNotInImport: _deleteNotInImport,
            skipUpdates: _skipUpdates,
            userId: widget.userId,
            cardSetRepo: widget.ref.read(cardSetRepositoryProvider),
            cardRepo: widget.ref.read(cardRepositoryProvider),
          );
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Import complete.')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _importing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final diffs = widget.analysis.setDiffs;

    return AlertDialog(
      title: const Text('Import Preview'),
      contentPadding: const EdgeInsets.fromLTRB(0, 16, 0, 0),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Options.
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  SwitchListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Skip card updates'),
                    subtitle: const Text(
                        'Only create new cards; leave existing cards unchanged.'),
                    value: _skipUpdates,
                    onChanged:
                        _importing ? null : (v) => setState(() => _skipUpdates = v),
                  ),
                  SwitchListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Remove cards not in import'),
                    subtitle: const Text(
                        'Cards absent from the file are removed from the set '
                        '(not deleted from your library).'),
                    value: _deleteNotInImport,
                    onChanged: _importing
                        ? null
                        : (v) => setState(() => _deleteNotInImport = v),
                  ),
                ],
              ),
            ),
            const Divider(),

            // Per-set diffs.
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: diffs.length,
                itemBuilder: (_, i) => _SetDiffTile(
                  diff: diffs[i],
                  showDeletable: _deleteNotInImport,
                  skipUpdates: _skipUpdates,
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _importing ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _importing ? null : _runImport,
          child: _importing
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : const Text('Import'),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Per-set section in the preview dialog.
// ---------------------------------------------------------------------------
class _SetDiffTile extends StatefulWidget {
  final ImportSetDiff diff;
  final bool showDeletable;
  final bool skipUpdates;

  const _SetDiffTile({
    required this.diff,
    required this.showDeletable,
    required this.skipUpdates,
  });

  @override
  State<_SetDiffTile> createState() => _SetDiffTileState();
}

class _SetDiffTileState extends State<_SetDiffTile> {
  bool _newExpanded = false;
  bool _updatedExpanded = false;
  bool _deletedExpanded = false;

  @override
  Widget build(BuildContext context) {
    final diff = widget.diff;
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Set name + new/existing badge.
          Row(
            children: [
              const Icon(Icons.library_books_outlined, size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Text(diff.setName,
                    style: theme.textTheme.titleSmall,
                    overflow: TextOverflow.ellipsis),
              ),
              Chip(
                label: Text(diff.isNewSet ? 'New set' : 'Existing'),
                visualDensity: VisualDensity.compact,
                backgroundColor: diff.isNewSet
                    ? theme.colorScheme.primaryContainer
                    : theme.colorScheme.secondaryContainer,
              ),
            ],
          ),
          const SizedBox(height: 6),

          // New cards row.
          if (diff.newCards.isNotEmpty)
            _ExpandableCountRow(
              icon: Icons.add_circle_outline,
              color: Colors.green,
              label: '${diff.newCards.length} new',
              expanded: _newExpanded,
              onTap: () => setState(() => _newExpanded = !_newExpanded),
              children: diff.newCards
                  .map((e) => _CardSummaryTile(
                        primary: e.data.primaryWord,
                        secondary: e.data.translation,
                      ))
                  .toList(),
            ),

          // Updated cards row (greyed label when skip is on).
          if (diff.updatedCards.isNotEmpty)
            _ExpandableCountRow(
              icon: Icons.edit_outlined,
              color: widget.skipUpdates
                  ? theme.disabledColor
                  : Colors.orange,
              label: widget.skipUpdates
                  ? '${diff.updatedCards.length} updated (skipped)'
                  : '${diff.updatedCards.length} updated',
              expanded: _updatedExpanded,
              onTap: () =>
                  setState(() => _updatedExpanded = !_updatedExpanded),
              children: diff.updatedCards
                  .map((e) => _CardSummaryTile(
                        primary: e.existing.primaryWord,
                        secondary: e.changedFields.join(', '),
                      ))
                  .toList(),
            ),

          // Deletable cards row — only shown when option is on.
          if (widget.showDeletable && diff.deletableCards.isNotEmpty)
            _ExpandableCountRow(
              icon: Icons.remove_circle_outline,
              color: theme.colorScheme.error,
              label: '${diff.deletableCards.length} to remove',
              expanded: _deletedExpanded,
              onTap: () =>
                  setState(() => _deletedExpanded = !_deletedExpanded),
              children: diff.deletableCards
                  .map((c) => _CardSummaryTile(
                        primary: c.primaryWord,
                        secondary: c.translation,
                      ))
                  .toList(),
            ),

          if (!diff.hasChanges)
            Text('No changes', style: theme.textTheme.bodySmall),

          const Divider(),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// A tappable count row that expands to show a card list.
// ---------------------------------------------------------------------------
class _ExpandableCountRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final bool expanded;
  final VoidCallback onTap;
  final List<Widget> children;

  const _ExpandableCountRow({
    required this.icon,
    required this.color,
    required this.label,
    required this.expanded,
    required this.onTap,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(4),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 6),
                Text(label,
                    style: TextStyle(color: color, fontSize: 13)),
                const Spacer(),
                Icon(
                  expanded
                      ? Icons.expand_less
                      : Icons.expand_more,
                  size: 16,
                ),
              ],
            ),
          ),
        ),
        if (expanded)
          Padding(
            padding: const EdgeInsets.only(left: 22),
            child: Column(children: children),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// One line in an expanded card list.
// ---------------------------------------------------------------------------
class _CardSummaryTile extends StatelessWidget {
  final String primary;
  final String secondary;

  const _CardSummaryTile({required this.primary, required this.secondary});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(primary,
                style: theme.textTheme.bodySmall,
                overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              secondary,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Simple section header with icon.
// ---------------------------------------------------------------------------
class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;

  const _SectionHeader({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20),
        const SizedBox(width: 8),
        Text(title, style: Theme.of(context).textTheme.titleMedium),
      ],
    );
  }
}
