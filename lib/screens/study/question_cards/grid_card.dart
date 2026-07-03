part of '../study_session_screen.dart';

// ---------------------------------------------------------------------------
// _GridCard — complete-the-grid question (#167), pill tap-to-fill.
//
// The table is rendered with optional row/column headers; `emptyCount` cells
// are randomly hidden as tappable slots.  A pool below holds the hidden cell
// values.  Tap a slot to select it, then tap a pool word to drop it in (tap a
// filled slot to return its word).  Check grades each slot by exact match —
// pool words are the exact cell values, so identity match is correct.  Cells
// are addressed by a linear index (row * columnCount + col).  In text-input
// mode each hidden cell is a small inline field instead.
// ---------------------------------------------------------------------------
class _GridCard extends StatefulWidget {
  final GridQuestion question;
  final void Function(bool correct)? onResult;
  // Resolved display label ("Question N") from the parent; falls back to the
  // question's own prompt when null.
  final String? labelOverride;
  const _GridCard(
      {required this.question, this.onResult, this.labelOverride});

  @override
  State<_GridCard> createState() => _GridCardState();
}

class _GridCardState extends State<_GridCard> {
  late List<List<String>> _cells;
  late int _cols;
  late List<int> _hiddenOrder; // hidden linear indices, reading order
  late Set<int> _hiddenSet;
  late List<String> _pool;
  final Map<int, int> _placement = {}; // hidden linear index -> pool index
  int? _selectedCell;
  AnswerResult? _result;
  // Text-input mode: one controller per hidden linear cell index.
  final Map<int, TextEditingController> _textControllers = {};

  @override
  void initState() {
    super.initState();
    _cells = widget.question.cells ?? const [];
    _cols = widget.question.columnCount;
    _setupRound();
  }

  @override
  void dispose() {
    for (final c in _textControllers.values) { c.dispose(); }
    super.dispose();
  }

  // Randomly choose which cells to hide, then build the shuffled pool.
  void _setupRound() {
    final total = _cells.length * _cols;
    final all = List<int>.generate(total, (i) => i)..shuffle();
    final count = widget.question.emptyCount.clamp(0, total);
    _hiddenOrder = all.take(count).toList()..sort();
    _hiddenSet = _hiddenOrder.toSet();
    _pool = [
      ..._hiddenOrder.map((idx) => _cells[idx ~/ _cols][idx % _cols]),
      ...widget.question.extraWords,
    ]..shuffle();
    _placement.clear();
    _selectedCell = _hiddenOrder.isNotEmpty ? _hiddenOrder.first : null;
    _result = null;
    // Text-input mode: create one controller per hidden cell; dispose previous.
    for (final c in _textControllers.values) { c.dispose(); }
    _textControllers.clear();
    if (widget.question.completionMode == CompletionMode.textInput) {
      for (final idx in _hiddenOrder) {
        _textControllers[idx] = TextEditingController();
      }
    }
  }

  Set<int> get _usedPoolIds => _placement.values.toSet();
  bool get _allFilled => _placement.length == _hiddenOrder.length;
  bool get _allTextFilled => _hiddenOrder.every(
      (i) => (_textControllers[i]?.text ?? '').trim().isNotEmpty);

  int? _firstEmptyCell() {
    for (final c in _hiddenOrder) {
      if (!_placement.containsKey(c)) return c;
    }
    return null;
  }

  void _onPoolTap(int poolId) {
    if (_result != null || _usedPoolIds.contains(poolId)) return;
    final sel = _selectedCell;
    final target =
        (sel != null && !_placement.containsKey(sel)) ? sel : _firstEmptyCell();
    if (target == null) return;
    setState(() {
      _placement[target] = poolId;
      _selectedCell = _firstEmptyCell();
    });
  }

  void _onCellTap(int linearIndex) {
    if (_result != null) return;
    setState(() {
      _placement.remove(linearIndex);
      _selectedCell = linearIndex;
    });
  }

  void _check() {
    if (widget.question.completionMode == CompletionMode.textInput) {
      var result = AnswerResult.correct;
      for (final idx in _hiddenOrder) {
        final r = AppHelpers.checkAnswer(
            _textControllers[idx]?.text ?? '',
            [_cells[idx ~/ _cols][idx % _cols]]);
        if (r == AnswerResult.incorrect) { result = AnswerResult.incorrect; break; }
        if (r == AnswerResult.close) result = AnswerResult.close;
      }
      setState(() => _result = result);
      result != AnswerResult.incorrect ? _hapticCorrect() : _hapticIncorrect();
      widget.onResult?.call(result != AnswerResult.incorrect);
      return;
    }
    var allCorrect = true;
    for (final idx in _hiddenOrder) {
      final poolId = _placement[idx];
      final placed = poolId != null ? _pool[poolId] : null;
      if (placed != _cells[idx ~/ _cols][idx % _cols]) { allCorrect = false; break; }
    }
    final result = allCorrect ? AnswerResult.correct : AnswerResult.incorrect;
    setState(() => _result = result);
    allCorrect ? _hapticCorrect() : _hapticIncorrect();
    widget.onResult?.call(allCorrect);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final appColors = context.appColors;
    final answered = _result != null;
    final isAccepted = _result != AnswerResult.incorrect;
    final prompt = widget.labelOverride ?? widget.question.prompt;
    final q = widget.question;
    final hasRowHeaders = q.rowHeaders.isNotEmpty;
    final hasColHeaders = q.columnHeaders.isNotEmpty;

    // Build the table rows.
    final tableRows = <TableRow>[];
    if (hasColHeaders) {
      tableRows.add(TableRow(children: [
        if (hasRowHeaders)
          _headerCell(q.cornerLabel, scheme), // top-left corner label
        for (final h in q.columnHeaders) _headerCell(h, scheme),
      ]));
    }
    for (var r = 0; r < _cells.length; r++) {
      tableRows.add(TableRow(children: [
        if (hasRowHeaders)
          _headerCell(r < q.rowHeaders.length ? q.rowHeaders[r] : '', scheme),
        for (var c = 0; c < _cols; c++)
          _dataCell(r * _cols + c, scheme, appColors),
      ]));
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      color: _answeredCardColor(context,
          answered: answered, accepted: isAccepted),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (prompt != null) ...[
              _FieldLabel(name: prompt),
              const SizedBox(height: 12),
            ],

            // The grid — centred; IntrinsicWidth makes the Table shrink-wrap to
            // its content so Center can position it rather than filling width.
            Center(
              child: IntrinsicWidth(
                child: Table(
                  border: TableBorder.all(color: scheme.outlineVariant),
                  defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                  defaultColumnWidth: const IntrinsicColumnWidth(),
                  children: tableRows,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Word pool — pill mode only, hidden once answered.
            if (widget.question.completionMode == CompletionMode.pill &&
                !answered) ...[
              _WordBankChips(
                  pool: _pool, usedIds: _usedPoolIds, onTap: _onPoolTap),
              const SizedBox(height: 12),
            ],

            // Check / feedback row.
            if (!answered)
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  onPressed: (widget.question.completionMode ==
                              CompletionMode.textInput
                          ? _allTextFilled
                          : _allFilled)
                      ? _check
                      : null,
                  child: Text(context.l10n.actionCheck),
                ),
              )
            else
              _ResultBanner(
                accepted: isAccepted,
                message: FeedbackPhrases.forResult(_result!, context.l10n),
              ),
          ],
        ),
      ),
    );
  }

  // Header cells fill the row height (TableCellVerticalAlignment.fill) so the
  // grey background covers the whole cell — otherwise, when a sibling data cell
  // grows tall (a wrong entry stacked above its correct value), the card's
  // result tint would bleed through the gap. Data cells stay middle-aligned,
  // which gives the row its intrinsic height.
  Widget _headerCell(String text, ColorScheme scheme) => TableCell(
        verticalAlignment: TableCellVerticalAlignment.fill,
        child: Container(
          color: scheme.surfaceContainerHighest,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Text(text,
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(fontWeight: FontWeight.bold)),
        ),
      );

  // A grid data cell: fixed value when visible; pill slot or text field when
  // hidden, depending on completionMode.
  Widget _dataCell(int linearIndex, ColorScheme scheme, AppColors appColors) {
    final value = _cells[linearIndex ~/ _cols][linearIndex % _cols];

    if (!_hiddenSet.contains(linearIndex)) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Text(value,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium),
      );
    }

    final answered = _result != null;

    // ── Text-input mode ────────────────────────────────────────────────────
    if (widget.question.completionMode == CompletionMode.textInput) {
      if (answered) {
        final input = _textControllers[linearIndex]?.text ?? '';
        final inputTrim = input.trim();
        final correct = AppHelpers.isAnswerCorrect(inputTrim, [value]);
        // Exact typed vs accepted-via-tolerance (case / diacritic / typo).
        final exact = correct && inputTrim == value;
        // Show the user's entry above the canonical form whenever it differs —
        // struck through if wrong, neutral if a close acceptance.
        final showEntry = !exact;
        return Container(
          color: correct
              ? appColors.correctSurface
              : scheme.errorContainer.withValues(alpha: 0.6),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (showEntry)
                Text(inputTrim.isEmpty ? '—' : inputTrim,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: correct
                            ? scheme.onSurfaceVariant
                            : scheme.error,
                        fontWeight: FontWeight.w600,
                        decoration:
                            correct ? null : TextDecoration.lineThrough)),
              Text(value,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: appColors.onCorrectSurface,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        );
      }
      // Active text field measured to fit the cell's expected value.
      // maxWidth divides the screen across columns (+1 for a row-header slot)
      // so a long value can't push its column off-screen.
      final fieldStyle = Theme.of(context).textTheme.bodyMedium;
      final fieldWidth = _measuredInputWidth(
        context,
        value,
        fieldStyle,
        contentPadding: 6, // grid field uses horizontal:6 contentPadding
        maxWidth:
            (MediaQuery.sizeOf(context).width / (_cols + 1)).clamp(56.0, 160.0),
      );
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: SizedBox(
          width: fieldWidth,
          child: TextField(
            controller: _textControllers[linearIndex],
            textAlign: TextAlign.center,
            decoration: const InputDecoration(
              isDense: true,
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 6, vertical: 6),
              border: OutlineInputBorder(),
            ),
            style: fieldStyle,
            textInputAction: TextInputAction.done,
            onChanged: (_) => setState(() {}), // recheck _allTextFilled
          ),
        ),
      );
    }

    // ── Pill (tap-to-fill) mode ────────────────────────────────────────────
    final poolId = _placement[linearIndex];
    final placed = poolId != null ? _pool[poolId] : null;

    if (answered) {
      final correct = placed == value;
      return Container(
        color: correct
            ? appColors.correctSurface
            : scheme.errorContainer.withValues(alpha: 0.6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(placed ?? '—',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: correct ? appColors.onCorrectSurface : scheme.error,
                  fontWeight: FontWeight.w600,
                  decoration: correct ? null : TextDecoration.lineThrough,
                )),
            if (!correct)
              Text(value,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: appColors.onCorrectSurface,
                      fontWeight: FontWeight.w600)),
          ],
        ),
      );
    }

    final selected = _selectedCell == linearIndex;
    return GestureDetector(
      onTap: () => _onCellTap(linearIndex),
      child: Container(
        constraints: const BoxConstraints(minWidth: 56, minHeight: 36),
        alignment: Alignment.center,
        color: selected
            ? scheme.primaryContainer
            : (placed != null ? scheme.secondaryContainer : null),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Text(
          placed ?? '____',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: placed != null
                    ? scheme.onSecondaryContainer
                    : scheme.onSurfaceVariant,
              ),
        ),
      ),
    );
  }
}