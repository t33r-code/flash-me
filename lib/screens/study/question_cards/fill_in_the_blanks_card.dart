part of '../study_session_screen.dart';

// ---------------------------------------------------------------------------
// _FillInTheBlanksCard — fill-in-the-blanks question (#170), pill tap-to-fill.
//
// The sentence is rendered inline with `blankCount` randomly-chosen eligible
// words replaced by tappable slots.  A word pool below holds the blanked words
// plus author distractors.  Tap a blank to select it, then tap a pool word to
// drop it in (tap a filled blank to return its word).  Check grades each slot
// by exact word match — pool words are the exact answers, so identity match is
// correct.  In text-input mode each blank is a small inline field instead.
// ---------------------------------------------------------------------------
class _FillInTheBlanksCard extends StatefulWidget {
  final FillInTheBlanksQuestion question;
  final void Function(bool correct)? onResult;
  const _FillInTheBlanksCard({required this.question, this.onResult});

  @override
  State<_FillInTheBlanksCard> createState() => _FillInTheBlanksCardState();
}

class _FillInTheBlanksCardState extends State<_FillInTheBlanksCard> {
  late List<FillBlankToken> _tokens;
  late List<int> _blankIndices; // token indices that are blanks (reading order)
  late Set<int> _blankSet;      // same, for fast lookup during render
  late List<String> _pool;      // pool words (blanked words + distractors)
  final Map<int, int> _placement = {}; // blankTokenIndex -> pool index
  int? _selectedBlank;          // blank currently selected to fill
  AnswerResult? _result;
  // Text-input mode: one controller per blank token index.
  final Map<int, TextEditingController> _textControllers = {};

  @override
  void initState() {
    super.initState();
    _tokens = widget.question.tokens ?? [];
    _setupRound();
  }

  @override
  void dispose() {
    for (final c in _textControllers.values) { c.dispose(); }
    super.dispose();
  }

  // Randomly pick which eligible words to blank, then build the shuffled pool.
  void _setupRound() {
    final eligible = <int>[];
    for (var i = 0; i < _tokens.length; i++) {
      if (_tokens[i].eligible) { eligible.add(i); }
    }
    eligible.shuffle();
    final count = widget.question.blankCount.clamp(0, eligible.length);
    _blankIndices = eligible.take(count).toList()..sort();
    _blankSet = _blankIndices.toSet();
    _pool = [
      ..._blankIndices.map((i) => _tokens[i].word),
      ...widget.question.extraWords,
    ]..shuffle();
    _placement.clear();
    _selectedBlank = _blankIndices.isNotEmpty ? _blankIndices.first : null;
    _result = null;
    // Text-input mode: create one controller per blank; dispose any previous.
    for (final c in _textControllers.values) { c.dispose(); }
    _textControllers.clear();
    if (widget.question.completionMode == CompletionMode.textInput) {
      for (final i in _blankIndices) {
        _textControllers[i] = TextEditingController();
      }
    }
  }

  Set<int> get _usedPoolIds => _placement.values.toSet();
  bool get _allFilled => _placement.length == _blankIndices.length;
  // Text-input mode: every blank has a non-empty entry.
  bool get _allTextFilled => _blankIndices.every(
      (i) => (_textControllers[i]?.text ?? '').trim().isNotEmpty);

  int? _firstEmptyBlank() {
    for (final b in _blankIndices) {
      if (!_placement.containsKey(b)) return b;
    }
    return null;
  }

  // Place a pool word into the selected (or next empty) blank.
  void _onPoolTap(int poolId) {
    if (_result != null || _usedPoolIds.contains(poolId)) return;
    final sel = _selectedBlank;
    final target =
        (sel != null && !_placement.containsKey(sel)) ? sel : _firstEmptyBlank();
    if (target == null) return;
    setState(() {
      _placement[target] = poolId;
      _selectedBlank = _firstEmptyBlank();
    });
  }

  // Tap a blank: return its word to the pool if filled, then select it.
  void _onBlankTap(int tokenIndex) {
    if (_result != null) return;
    setState(() {
      _placement.remove(tokenIndex);
      _selectedBlank = tokenIndex;
    });
  }

  void _check() {
    if (widget.question.completionMode == CompletionMode.textInput) {
      // Text-input mode: tri-state — any incorrect slot → incorrect;
      // all accepted with at least one close → close; all exact → correct.
      var result = AnswerResult.correct;
      for (final b in _blankIndices) {
        final r = AppHelpers.checkAnswer(
            _textControllers[b]?.text ?? '', [_tokens[b].word]);
        if (r == AnswerResult.incorrect) { result = AnswerResult.incorrect; break; }
        if (r == AnswerResult.close) result = AnswerResult.close;
      }
      setState(() => _result = result);
      result != AnswerResult.incorrect ? _hapticCorrect() : _hapticIncorrect();
      widget.onResult?.call(result != AnswerResult.incorrect);
      return;
    }
    // Pill mode: exact match of placed pool word — correct or incorrect only.
    var allCorrect = true;
    for (final b in _blankIndices) {
      final poolId = _placement[b];
      final placedWord = poolId != null ? _pool[poolId] : null;
      if (placedWord != _tokens[b].word) { allCorrect = false; break; }
    }
    final result = allCorrect ? AnswerResult.correct : AnswerResult.incorrect;
    setState(() => _result = result);
    allCorrect ? _hapticCorrect() : _hapticIncorrect();
    widget.onResult?.call(allCorrect);
  }

  void _tryAgain() {
    for (final c in _textControllers.values) { c.clear(); }
    setState(() {
      _placement.clear();
      _selectedBlank = _blankIndices.isNotEmpty ? _blankIndices.first : null;
      _result = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final appColors = context.appColors;
    final answered = _result != null;
    final isAccepted = _result != AnswerResult.incorrect;
    final prompt = widget.question.prompt;

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

            // Sentence with inline blank slots (pill or text-input).
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 6,
              runSpacing: 8,
              children: [
                for (var i = 0; i < _tokens.length; i++)
                  if (_blankSet.contains(i))
                    _affixed(
                      _tokens[i],
                      widget.question.completionMode == CompletionMode.textInput
                          ? _buildTextSlot(i, scheme, appColors)
                          : _buildSlot(i, scheme, appColors),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Text(
                          '${_tokens[i].leading}${_tokens[i].word}${_tokens[i].trailing}',
                          style: Theme.of(context).textTheme.bodyLarge),
                    ),
              ],
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
            else if (isAccepted)
              _ResultBanner(
                accepted: true,
                message: FeedbackPhrases.forResult(_result!, context.l10n),
              )
            else
              _ResultBanner(
                accepted: false,
                message: FeedbackPhrases.forResult(_result!, context.l10n),
                trailing: TextButton(
                    onPressed: _tryAgain,
                    child: Text(context.l10n.actionTryAgain)),
                detail: Text(
                  context.l10n.messageAnswerReveal(
                      widget.question.sentence ?? ''),
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // Wrap a blank slot with its leading/trailing punctuation so the marks hug
  // the slot (e.g. ¿___? ) rather than floating with the Wrap's word spacing.
  Widget _affixed(FillBlankToken token, Widget slot) {
    if (token.leading.isEmpty && token.trailing.isEmpty) return slot;
    final style = Theme.of(context).textTheme.bodyLarge;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (token.leading.isNotEmpty) Text(token.leading, style: style),
        slot,
        if (token.trailing.isNotEmpty) Text(token.trailing, style: style),
      ],
    );
  }

  // One inline blank slot: empty/selected/filled before checking; green/red
  // (with the correct word) after.
  Widget _buildSlot(int tokenIndex, ColorScheme scheme, AppColors appColors) {
    final poolId = _placement[tokenIndex];
    final placedWord = poolId != null ? _pool[poolId] : null;
    final answered = _result != null;

    if (answered) {
      final correctWord = _tokens[tokenIndex].word;
      if (placedWord == correctWord) {
        return _slotChip(
            text: correctWord,
            bg: appColors.correctSurface,
            fg: appColors.onCorrectSurface);
      }
      // Wrong: user's word struck through, followed by the correct word.
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Wrap(
          spacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _slotChip(
                text: placedWord ?? '—',
                bg: scheme.errorContainer,
                fg: scheme.onErrorContainer,
                strike: true),
            _slotChip(
                text: correctWord,
                bg: appColors.correctSurface,
                fg: appColors.onCorrectSurface),
          ],
        ),
      );
    }

    final selected = _selectedBlank == tokenIndex;
    return GestureDetector(
      onTap: () => _onBlankTap(tokenIndex),
      child: Container(
        constraints: const BoxConstraints(minWidth: 56),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: placedWord != null ? scheme.secondaryContainer : null,
          border: Border.all(
            color: selected ? scheme.primary : scheme.outline,
            width: selected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          placedWord ?? '   ',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: placedWord != null
                    ? scheme.onSecondaryContainer
                    : scheme.onSurfaceVariant,
              ),
        ),
      ),
    );
  }

  // Text-input slot: a compact inline TextField while unanswered; switches to
  // a coloured chip showing the CANONICAL correct word (not the user's input)
  // on reveal so the learner always sees the right form.
  Widget _buildTextSlot(int tokenIndex, ColorScheme scheme, AppColors appColors) {
    final correctWord = _tokens[tokenIndex].word;
    final answered = _result != null;

    if (answered) {
      final input = _textControllers[tokenIndex]?.text ?? '';
      final inputTrim = input.trim();
      final correct = AppHelpers.isAnswerCorrect(inputTrim, [correctWord]);
      // Was the answer typed exactly, or accepted via tolerance (case /
      // diacritic / typo)? A close acceptance still shows the canonical form.
      final exact = correct && inputTrim == correctWord;

      // Clean exact entry → single correct chip.
      if (exact) {
        return _slotChip(
            text: correctWord,
            bg: appColors.correctSurface,
            fg: appColors.onCorrectSurface);
      }

      // Close acceptance → show the user's entry (neutral, not struck) next to
      // the canonical form so they see what the right spelling was.
      if (correct) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Wrap(
            spacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _slotChip(
                  text: inputTrim.isEmpty ? '—' : inputTrim,
                  bg: scheme.secondaryContainer,
                  fg: scheme.onSecondaryContainer),
              _slotChip(
                  text: correctWord,
                  bg: appColors.correctSurface,
                  fg: appColors.onCorrectSurface),
            ],
          ),
        );
      }

      // Incorrect → struck-through entry next to the correct form.
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Wrap(
          spacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _slotChip(
                text: inputTrim.isEmpty ? '—' : inputTrim,
                bg: scheme.errorContainer,
                fg: scheme.onErrorContainer,
                strike: true),
            _slotChip(
                text: correctWord,
                bg: appColors.correctSurface,
                fg: appColors.onCorrectSurface),
          ],
        ),
      );
    }

    // Active: a small inline text field sized to the expected word length.
    final approxWidth = (correctWord.length * 11.0).clamp(52.0, 130.0);
    return SizedBox(
      width: approxWidth,
      child: TextField(
        controller: _textControllers[tokenIndex],
        decoration: const InputDecoration(
          isDense: true,
          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          border: OutlineInputBorder(),
        ),
        style: Theme.of(context).textTheme.bodyLarge,
        textInputAction: TextInputAction.done,
        onChanged: (_) => setState(() {}), // recheck _allTextFilled
      ),
    );
  }

  Widget _slotChip(
      {required String text,
      required Color bg,
      required Color fg,
      bool strike = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Text(text,
          style: TextStyle(
              color: fg,
              fontWeight: FontWeight.w600,
              decoration: strike ? TextDecoration.lineThrough : null)),
    );
  }
}