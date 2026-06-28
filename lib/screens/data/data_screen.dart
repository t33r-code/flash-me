import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flash_me/widgets/help_menu_button.dart';

import 'package:flash_me/models/card_set.dart';
import 'package:flash_me/models/import_diff.dart';
import 'package:flash_me/providers/auth_provider.dart';
import 'package:flash_me/providers/card_provider.dart';
import 'package:flash_me/providers/card_set_provider.dart';
import 'package:flash_me/providers/export_provider.dart';
import 'package:flash_me/providers/import_provider.dart';
import 'package:flash_me/providers/question_template_provider.dart';
import 'package:flash_me/providers/tag_provider.dart';
import 'package:flash_me/providers/template_provider.dart';
import 'package:flash_me/utils/exceptions.dart';
import 'package:flash_me/utils/extensions.dart';

// ---------------------------------------------------------------------------
// DataScreen — account-level import & bulk export.
// ---------------------------------------------------------------------------
class DataScreen extends ConsumerStatefulWidget {
  const DataScreen({super.key});

  @override
  ConsumerState<DataScreen> createState() => _DataScreenState();
}

class _DataScreenState extends ConsumerState<DataScreen> {
  // Export state.
  final Set<String> _selectedSetIds = {};
  bool _exporting = false;
  // True while a picked ZIP is being parsed and diffed.
  bool _analyzing = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final setsAsync = ref.watch(userSetsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.titleImportExport),
        actions: const [HelpMenuButton(HelpContext.importExport)],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Import ──────────────────────────────────────────────────────
          _SectionHeader(title: context.l10n.titleImport, icon: Icons.upload_file_outlined),
          const SizedBox(height: 8),
          Text(
            context.l10n.messageImportDescription,
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            icon: _analyzing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.folder_open_outlined),
            label: Text(context.l10n.actionChooseZipFile),
            onPressed: _analyzing ? null : () => _pickAndAnalyze(context),
          ),

          // ── Export ──────────────────────────────────────────────────────
          const SizedBox(height: 32),
          const Divider(),
          const SizedBox(height: 16),
          _SectionHeader(title: context.l10n.titleExport, icon: Icons.download_outlined),
          const SizedBox(height: 8),
          Text(
            context.l10n.messageExportDescription,
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          ...setsAsync.when(
            loading: () =>
                [const Center(child: CircularProgressIndicator())],
            error: (_, _) =>
                [Text(context.l10n.errorFailedLoadSets)],
            data: (sets) => _buildExportSection(sets, theme),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildExportSection(List<CardSet> sets, ThemeData theme) {
    final l10n = context.l10n;

    if (sets.isEmpty) {
      return [
        Text(
          l10n.messageNoSetsYetExport,
          style: theme.textTheme.bodyMedium
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      ];
    }

    final allSelected = _selectedSetIds.length == sets.length;

    return [
      // Select-all toggle + count label.
      Row(
        children: [
          TextButton(
            onPressed: _exporting
                ? null
                : () => setState(() {
                      if (allSelected) {
                        _selectedSetIds.clear();
                      } else {
                        _selectedSetIds.addAll(sets.map((s) => s.id));
                      }
                    }),
            child: Text(allSelected ? l10n.actionDeselectAll : l10n.actionSelectAll),
          ),
          Text(
            _selectedSetIds.isEmpty
                ? l10n.labelNoneSelected
                : l10n.labelNOfMSelected(_selectedSetIds.length, sets.length),
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),

      // One checkbox row per set.
      ...sets.map(
        (s) => CheckboxListTile(
          dense: true,
          value: _selectedSetIds.contains(s.id),
          onChanged: _exporting
              ? null
              : (checked) => setState(() {
                    if (checked == true) {
                      _selectedSetIds.add(s.id);
                    } else {
                      _selectedSetIds.remove(s.id);
                    }
                  }),
          secondary: const Icon(Icons.library_books_outlined),
          title: Text(s.name, overflow: TextOverflow.ellipsis),
          subtitle: Text(l10n.labelCardCount(s.cardCount)),
          controlAffinity: ListTileControlAffinity.leading,
        ),
      ),

      const SizedBox(height: 16),
      FilledButton.icon(
        icon: _exporting
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              )
            : const Icon(Icons.download_outlined),
        label: Text(l10n.actionExportN(_selectedSetIds.length)),
        onPressed:
            (_selectedSetIds.isEmpty || _exporting) ? null : _runExport,
      ),
    ];
  }

  Future<void> _runExport() async {
    setState(() => _exporting = true);
    final l10n = context.l10n;

    final allSets = ref.read(userSetsProvider).asData?.value ?? [];
    final selected =
        allSets.where((s) => _selectedSetIds.contains(s.id)).toList();
    final uid = ref.read(authStateProvider).asData?.value ?? '';

    if (!mounted) return;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        content: Row(children: [
          const CircularProgressIndicator(),
          const SizedBox(width: 20),
          Text(l10n.messageExporting),
        ]),
      ),
    );

    try {
      // Fetch templates directly from repositories — don't rely on cached
      // stream state, which may be AsyncLoading if the Templates tab hasn't
      // been opened yet.
      final cardTemplates = await ref
          .read(templateRepositoryProvider)
          .watchUserTemplates(uid)
          .first;
      final questionTemplates = await ref
          .read(questionTemplateRepositoryProvider)
          .getUserTemplates(uid);

      final path = await ref.read(exportServiceProvider).exportSets(
            sets: selected,
            userId: uid,
            cardSetRepo: ref.read(cardSetRepositoryProvider),
            cardTemplates: cardTemplates,
            questionTemplates: questionTemplates,
          );

      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            path != null ? l10n.messageExportSavedTo(path) : l10n.messageExportReady),
      ));
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.errorExportFailed)));
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _pickAndAnalyze(BuildContext context) async {
    setState(() => _analyzing = true);
    final l10n = context.l10n;
    try {
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
        builder: (_) => AlertDialog(
          content: Row(children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 20),
            Text(l10n.messageAnalysingArchive),
          ]),
        ),
      );

      final uid = ref.read(authStateProvider).asData?.value ?? '';
      final analysis = await ref.read(importServiceProvider).analyze(
            zipBytes: bytes,
            userId: uid,
            cardSetRepo: ref.read(cardSetRepositoryProvider),
            cardRepo: ref.read(cardRepositoryProvider),
            questionTemplateRepo:
                ref.read(questionTemplateRepositoryProvider),
            templateRepo: ref.read(templateRepositoryProvider),
          );

      if (!context.mounted) return;
      Navigator.of(context).pop(); // dismiss progress

      // Show preview dialog; returns a summary when the user confirms import.
      final summary = await showDialog<_ImportSummaryData>(
        context: context,
        builder: (_) => _ImportPreviewDialog(
          analysis: analysis,
          userId: uid,
          ref: ref,
        ),
      );

      if (!context.mounted || summary == null) return;
      await showDialog<void>(
        context: context,
        builder: (_) => _ImportSummaryDialog(summary: summary),
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
        SnackBar(content: Text(l10n.errorFailedReadArchive)),
      );
    } finally {
      if (mounted) setState(() => _analyzing = false);
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
            templateRepo: widget.ref.read(templateRepositoryProvider),
            questionTemplateRepo:
                widget.ref.read(questionTemplateRepositoryProvider),
            tagRepo: widget.ref.read(tagRepositoryProvider),
          );
      // Force all cardsInSetProvider streams to re-subscribe so updated card
      // data (questions, correctIndex, etc.) is reflected immediately.
      // Without this, the stream only re-fires when set membership changes,
      // not when individual card documents are updated.
      widget.ref.invalidate(cardsInSetProvider);
      widget.ref.invalidate(userTemplatesProvider);
      widget.ref.invalidate(userQuestionTemplatesProvider);
      if (mounted) {
        Navigator.of(context).pop(_ImportSummaryData(
          totalSets: widget.analysis.setDiffs.length,
          newSets: widget.analysis.setDiffs.where((d) => d.isNewSet).length,
          cardsAdded: widget.analysis.totalNewCards,
          cardsLinked: widget.analysis.totalLibraryLinkCards,
          cardsUpdated: _skipUpdates ? 0 : widget.analysis.totalUpdatedCards,
          cardsRemoved:
              _deleteNotInImport ? widget.analysis.totalDeletableCards : 0,
          cardTemplatesCreated: widget.analysis.totalNewCardTemplates,
          questionTemplatesCreated: widget.analysis.totalNewQuestionTemplates,
        ));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _importing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.errorImportFailed)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final diffs = widget.analysis.setDiffs;

    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.titleImportPreview),
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
                    title: Text(l10n.labelSkipCardUpdates),
                    subtitle: Text(l10n.messageSkipCardUpdatesSubtitle),
                    value: _skipUpdates,
                    onChanged:
                        _importing ? null : (v) => setState(() => _skipUpdates = v),
                  ),
                  SwitchListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(l10n.labelRemoveCardsNotInImport),
                    subtitle: Text(l10n.messageRemoveCardsNotInImportSubtitle),
                    value: _deleteNotInImport,
                    onChanged: _importing
                        ? null
                        : (v) => setState(() => _deleteNotInImport = v),
                  ),
                ],
              ),
            ),
            const Divider(),

            // Templates + per-set diffs in one scrollable list.
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  if (widget.analysis.totalNewCardTemplates > 0 ||
                      widget.analysis.totalNewQuestionTemplates > 0)
                    _TemplateDiffSection(analysis: widget.analysis),
                  for (final diff in diffs)
                    _SetDiffTile(
                      diff: diff,
                      showDeletable: _deleteNotInImport,
                      skipUpdates: _skipUpdates,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _importing ? null : () => Navigator.of(context).pop(),
          child: Text(l10n.labelCancel),
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
              : Text(l10n.actionImport),
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
  bool _libraryExpanded = false;
  bool _updatedExpanded = false;
  bool _deletedExpanded = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final diff = widget.diff;
    final theme = Theme.of(context);
    final successColor = context.appColors.statusSuccess;
    final warningColor = context.appColors.statusWarning;

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
                label: Text(diff.isNewSet ? l10n.labelNewSet : l10n.labelExistingSet),
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
              color: successColor,
              label: l10n.labelNNew(diff.newCards.length),
              expanded: _newExpanded,
              onTap: () => setState(() => _newExpanded = !_newExpanded),
              children: diff.newCards
                  .map((e) => _CardSummaryTile(
                        primary: e.data.primaryWord,
                        secondary: e.data.translation,
                      ))
                  .toList(),
            ),

          // Library link row — card exists elsewhere in the library.
          if (diff.libraryLinkCards.isNotEmpty)
            _ExpandableCountRow(
              icon: Icons.link,
              color: theme.colorScheme.secondary,
              label: l10n.labelNFromLibrary(diff.libraryLinkCards.length),
              expanded: _libraryExpanded,
              onTap: () =>
                  setState(() => _libraryExpanded = !_libraryExpanded),
              children: diff.libraryLinkCards
                  .map((e) => _CardSummaryTile(
                        primary: e.existingCard.primaryWord,
                        secondary: e.existingCard.translation,
                      ))
                  .toList(),
            ),

          // Updated cards row (greyed label when skip is on).
          if (diff.updatedCards.isNotEmpty)
            _ExpandableCountRow(
              icon: Icons.edit_outlined,
              color: widget.skipUpdates
                  ? theme.disabledColor
                  : warningColor,
              label: widget.skipUpdates
                  ? l10n.labelNUpdatedSkipped(diff.updatedCards.length)
                  : l10n.labelNUpdated(diff.updatedCards.length),
              expanded: _updatedExpanded,
              onTap: () =>
                  setState(() => _updatedExpanded = !_updatedExpanded),
              children: diff.updatedCards
                  .map((e) => _UpdatedCardTile(
                        entry: e,
                        currentSetName: diff.setName,
                      ))
                  .toList(),
            ),

          // Deletable cards row — only shown when option is on.
          if (widget.showDeletable && diff.deletableCards.isNotEmpty)
            _ExpandableCountRow(
              icon: Icons.remove_circle_outline,
              color: theme.colorScheme.error,
              label: l10n.labelNToRemove(diff.deletableCards.length),
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
            Text(l10n.labelNoChanges, style: theme.textTheme.bodySmall),

          const Divider(),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Templates section in the preview dialog — new Card and Question Templates.
// ---------------------------------------------------------------------------
class _TemplateDiffSection extends StatefulWidget {
  final ImportAnalysis analysis;
  const _TemplateDiffSection({required this.analysis});

  @override
  State<_TemplateDiffSection> createState() => _TemplateDiffSectionState();
}

class _TemplateDiffSectionState extends State<_TemplateDiffSection> {
  bool _cardTplExpanded = false;
  bool _questionTplExpanded = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final successColor = context.appColors.statusSuccess;
    final cts = widget.analysis.newCardTemplates;
    final qts = widget.analysis.newQuestionTemplates;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.copy_all_outlined, size: 18),
              const SizedBox(width: 6),
              Text(l10n.titleTemplates, style: theme.textTheme.titleSmall),
            ],
          ),
          const SizedBox(height: 6),

          if (cts.isNotEmpty)
            _ExpandableCountRow(
              icon: Icons.add_circle_outline,
              color: successColor,
              label: l10n.labelNNewCardTemplates(cts.length),
              expanded: _cardTplExpanded,
              onTap: () =>
                  setState(() => _cardTplExpanded = !_cardTplExpanded),
              children: cts.map((t) {
                final name = t['name'] as String? ?? '';
                final qs = (t['questions'] as List?)?.length ?? 0;
                final desc = t['description'] as String?;
                return _CardSummaryTile(
                  primary: name,
                  secondary: desc ?? l10n.labelQuestionCount(qs),
                );
              }).toList(),
            ),

          if (qts.isNotEmpty)
            _ExpandableCountRow(
              icon: Icons.add_circle_outline,
              color: successColor,
              label: l10n.labelNNewQuestionTemplates(qts.length),
              expanded: _questionTplExpanded,
              onTap: () => setState(
                  () => _questionTplExpanded = !_questionTplExpanded),
              children: qts.map((t) {
                final name = t['name'] as String? ?? '';
                final importId = t['templateId'] as String?;
                final q = t['question'] as Map<String, dynamic>? ?? {};
                final typeLabel = switch (q['type'] as String? ?? '') {
                  'text_input' => l10n.labelQuestionTypeTextInput,
                  'multiple_choice' => l10n.labelQuestionTypeMultipleChoice,
                  'word_order' => l10n.labelQuestionTypeWordOrder,
                  'fill_in_blanks' => l10n.labelQuestionTypeFillInBlanks,
                  'grid' => l10n.labelQuestionTypeGrid,
                  _ => l10n.labelQuestion,
                };
                final secondary = importId != null
                    ? '##$importId  ·  $typeLabel'
                    : typeLabel;
                return _CardSummaryTile(primary: name, secondary: secondary);
              }).toList(),
            ),

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
// Expanded row for an updated card — shows each old→new field change and
// lists any other sets that also contain this card (so the user knows the
// update will affect them too).
// ---------------------------------------------------------------------------
class _UpdatedCardTile extends StatelessWidget {
  final UpdatedCardEntry entry;
  final String currentSetName;

  const _UpdatedCardTile({required this.entry, required this.currentSetName});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final otherSets = entry.affectedSetNames
        .where((s) => s != currentSetName)
        .toList();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            entry.existing.primaryWord,
            style: theme.textTheme.bodySmall
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          ...entry.changes.map(
            (c) => Padding(
              padding: const EdgeInsets.only(left: 8, top: 1),
              child: Text(
                '${c.label}: ${c.oldValue} → ${c.newValue}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
          if (otherSets.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 8, top: 2),
              child: Text(
                context.l10n.messageAlsoIn(otherSets.join(', ')),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Data returned by _ImportPreviewDialog when the user confirms an import.
// ---------------------------------------------------------------------------
class _ImportSummaryData {
  final int totalSets;
  final int newSets;
  final int cardsAdded;
  final int cardsLinked;
  final int cardsUpdated;
  final int cardsRemoved;
  final int cardTemplatesCreated;
  final int questionTemplatesCreated;

  const _ImportSummaryData({
    required this.totalSets,
    required this.newSets,
    required this.cardsAdded,
    required this.cardsLinked,
    required this.cardsUpdated,
    required this.cardsRemoved,
    this.cardTemplatesCreated = 0,
    this.questionTemplatesCreated = 0,
  });
}

// ---------------------------------------------------------------------------
// Post-import summary dialog — confirms what was actually applied.
// ---------------------------------------------------------------------------
class _ImportSummaryDialog extends StatelessWidget {
  final _ImportSummaryData summary;

  const _ImportSummaryDialog({required this.summary});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final successColor = context.appColors.statusSuccess;
    final warningColor = context.appColors.statusWarning;
    final s = summary;
    final hasChanges = s.cardsAdded > 0 || s.cardsLinked > 0 ||
        s.cardsUpdated > 0 || s.cardsRemoved > 0 ||
        s.cardTemplatesCreated > 0 || s.questionTemplatesCreated > 0;

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.check_circle_outline, color: successColor),
          const SizedBox(width: 8),
          Text(l10n.titleImportComplete),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _summaryRow(
            theme,
            Icons.library_books_outlined,
            '${l10n.messageSetsProcessed(s.totalSets)}'
                '${s.newSets > 0 ? ' ${l10n.labelNewCount(s.newSets)}' : ''}',
          ),
          if (!hasChanges)
            _summaryRow(theme, Icons.info_outline, l10n.messageNoChangesApplied),
          if (s.cardsAdded > 0)
            _summaryRow(
              theme,
              Icons.add_circle_outline,
              l10n.messageCardsAdded(s.cardsAdded),
              color: successColor,
            ),
          if (s.cardsLinked > 0)
            _summaryRow(
              theme,
              Icons.link,
              l10n.messageCardsLinked(s.cardsLinked),
              color: theme.colorScheme.secondary,
            ),
          if (s.cardsUpdated > 0)
            _summaryRow(
              theme,
              Icons.edit_outlined,
              l10n.messageCardsUpdated(s.cardsUpdated),
              color: warningColor,
            ),
          if (s.cardsRemoved > 0)
            _summaryRow(
              theme,
              Icons.remove_circle_outline,
              l10n.messageCardsRemovedFromSets(s.cardsRemoved),
              color: theme.colorScheme.error,
            ),
          if (s.cardTemplatesCreated > 0)
            _summaryRow(
              theme,
              Icons.copy_all_outlined,
              l10n.messageCardTemplatesCreated(s.cardTemplatesCreated),
              color: successColor,
            ),
          if (s.questionTemplatesCreated > 0)
            _summaryRow(
              theme,
              Icons.quiz_outlined,
              l10n.messageQuestionTemplatesCreated(s.questionTemplatesCreated),
              color: successColor,
            ),
        ],
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.actionDone),
        ),
      ],
    );
  }

  Widget _summaryRow(ThemeData theme, IconData icon, String label,
      {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color ?? theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
            child: Text(label, style: theme.textTheme.bodyMedium),
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
