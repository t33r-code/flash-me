import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flash_me/models/card_field.dart';
import 'package:flash_me/models/card_set.dart';
import 'package:flash_me/models/flash_card.dart';
import 'package:flash_me/models/study_session.dart';
import 'package:flash_me/providers/card_set_provider.dart';

// ---------------------------------------------------------------------------
// StudySessionScreen — displays one card at a time from a StudySession.
//
// Card data is loaded via cardsInSetProvider (already streamed by the set
// detail screen, so no extra Firestore reads on first open).  All per-card
// interaction state (reveals, answers) is held in local widget state and
// reset automatically when the user navigates to a new card.
//
// Navigation (Previous / Next) and persistence (auto-save, Know / Don't Know,
// session completion) are added in Phase 5c.
// ---------------------------------------------------------------------------
class StudySessionScreen extends ConsumerStatefulWidget {
  final StudySession session;
  final CardSet cardSet;
  const StudySessionScreen(
      {super.key, required this.session, required this.cardSet});

  @override
  ConsumerState<StudySessionScreen> createState() =>
      _StudySessionScreenState();
}

class _StudySessionScreenState extends ConsumerState<StudySessionScreen> {
  late int _currentIndex;
  // false = show word-only centred view; true = slide to top and show fields
  bool _revealed = false;

  @override
  void initState() {
    super.initState();
    // Restore position for resumed sessions.
    _currentIndex = widget.session.currentCardIndex;
  }

  String get _currentCardId =>
      widget.session.cardSequence[_currentIndex];
  int get _total => widget.session.cardSequence.length;

  void _previous() {
    if (_currentIndex > 0) {
      setState(() { _currentIndex--; _revealed = false; });
    }
  }

  void _next() {
    if (_currentIndex < _total - 1) {
      setState(() { _currentIndex++; _revealed = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cardsAsync = ref.watch(cardsInSetProvider(widget.cardSet.id));

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.cardSet.name),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('End'),
          ),
        ],
      ),
      body: Column(
        children: [
          // Thin bar showing how far through the session the user is.
          LinearProgressIndicator(
            value: (_currentIndex + 1) / _total,
          ),

          // Card content — two-phase:
          //   • Before reveal: word card centred on screen (_WordCard)
          //   • After tap: card slides to top, fields appear below
          Expanded(
            child: cardsAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (_, _) =>
                  const Center(child: Text('Failed to load cards.')),
              data: (cards) {
                final cardsMap = {for (final c in cards) c.id: c};
                final card = cardsMap[_currentCardId];
                if (card == null) {
                  return const Center(child: Text('Card not found.'));
                }
                return AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      // Incoming content rises in from slightly below.
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.04),
                        end: Offset.zero,
                      ).animate(CurvedAnimation(
                          parent: animation, curve: Curves.easeOut)),
                      child: child,
                    ),
                  ),
                  child: _revealed
                      ? SingleChildScrollView(
                          key: ValueKey('${_currentIndex}-revealed'),
                          padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                          child: Column(
                            children: [
                              _PrimaryFieldCard(card: card),
                              for (final field in card.fields)
                                _buildField(field),
                              const SizedBox(height: 16),
                            ],
                          ),
                        )
                      : _WordCard(
                          key: ValueKey('${_currentIndex}-word'),
                          card: card,
                          onReveal: () => setState(() => _revealed = true),
                        ),
                );
              },
            ),
          ),

          // Previous / Next navigation bar.
          _NavigationBar(
            currentIndex: _currentIndex,
            total: _total,
            onPrevious: _previous,
            onNext: _next,
          ),
        ],
      ),
    );
  }

  // Dispatch each field to its typed widget using Dart's sealed class switch.
  Widget _buildField(CardField field) => switch (field.content) {
        RevealContent c => _RevealFieldCard(field: field, content: c),
        TextInputContent c => _TextInputFieldCard(field: field, content: c),
        MultipleChoiceContent c =>
          _MultipleChoiceFieldCard(field: field, content: c),
      };
}

// ---------------------------------------------------------------------------
// _WordCard — pre-reveal view.  Fills the available space with just the
// primary word (centred).  Calling onReveal transitions to the full field
// list.  Handles primaryWordHidden: shows "Show Word" before the word.
// ---------------------------------------------------------------------------
class _WordCard extends StatefulWidget {
  final FlashCard card;
  final VoidCallback onReveal;
  const _WordCard(
      {super.key, required this.card, required this.onReveal});

  @override
  State<_WordCard> createState() => _WordCardState();
}

class _WordCardState extends State<_WordCard> {
  late bool _wordVisible;

  @override
  void initState() {
    super.initState();
    _wordVisible = !widget.card.primaryWordHidden;
  }

  @override
  Widget build(BuildContext context) {
    final card = widget.card;
    final scheme = Theme.of(context).colorScheme;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Card(
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: _wordVisible ? widget.onReveal : null,
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (card.primaryImageUrl != null) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        card.primaryImageUrl!,
                        height: 180,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const SizedBox(
                          height: 80,
                          child: Center(
                            child: Icon(Icons.broken_image_outlined,
                                size: 40, color: Colors.grey),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  if (!_wordVisible) ...[
                    Icon(Icons.help_outline,
                        size: 56, color: scheme.onSurfaceVariant),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: () =>
                          setState(() => _wordVisible = true),
                      icon: const Icon(Icons.visibility_outlined),
                      label: const Text('Show Word'),
                    ),
                  ] else ...[
                    Text(
                      card.primaryWord,
                      style: Theme.of(context).textTheme.headlineLarge,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.touch_app_outlined,
                            size: 18, color: scheme.onSurfaceVariant),
                        const SizedBox(width: 6),
                        Text(
                          'Tap to reveal',
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _PrimaryFieldCard — compact card at the top of the revealed list.
// Translation is always visible here since this widget only appears
// after the user has tapped to reveal.
// ---------------------------------------------------------------------------
class _PrimaryFieldCard extends StatelessWidget {
  final FlashCard card;
  const _PrimaryFieldCard({required this.card});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (card.primaryImageUrl != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  card.primaryImageUrl!,
                  height: 140,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const SizedBox(
                    height: 60,
                    child: Center(
                      child: Icon(Icons.broken_image_outlined,
                          size: 32, color: Colors.grey),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            Text(
              card.primaryWord,
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const Divider(height: 24),
            Text(
              card.translation,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(color: scheme.primary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _RevealFieldCard — shows a field label and hides the answer behind a tap.
// ---------------------------------------------------------------------------
class _RevealFieldCard extends StatefulWidget {
  final CardField field;
  final RevealContent content;
  const _RevealFieldCard({required this.field, required this.content});

  @override
  State<_RevealFieldCard> createState() => _RevealFieldCardState();
}

class _RevealFieldCardState extends State<_RevealFieldCard> {
  bool _revealed = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: _revealed ? null : () => setState(() => _revealed = true),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _FieldLabel(name: widget.field.name),
              const SizedBox(height: 8),
              // Both states are always laid out so the card height is
              // determined by the answer text before the tap, eliminating
              // the height jump on reveal.  Only one state is painted at
              // a time via maintainSize visibility toggling.
              Stack(
                children: [
                  Visibility(
                    visible: _revealed,
                    maintainSize: true,
                    maintainAnimation: true,
                    maintainState: true,
                    child: Text(
                      widget.content.answer ?? '',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ),
                  Visibility(
                    visible: !_revealed,
                    maintainSize: true,
                    maintainAnimation: true,
                    maintainState: true,
                    child: Row(children: [
                      Icon(Icons.visibility_outlined,
                          size: 18, color: scheme.onSurfaceVariant),
                      const SizedBox(width: 6),
                      Text(
                        'Tap to reveal',
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ]),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _TextInputFieldCard — user types a free-text answer, validated against
// correctAnswers.  Supports case-insensitive (default) or exact matching.
// Shows correct/incorrect feedback and a Try Again button on wrong answers.
// ---------------------------------------------------------------------------
class _TextInputFieldCard extends StatefulWidget {
  final CardField field;
  final TextInputContent content;
  const _TextInputFieldCard({required this.field, required this.content});

  @override
  State<_TextInputFieldCard> createState() => _TextInputFieldCardState();
}

class _TextInputFieldCardState extends State<_TextInputFieldCard> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  // null = not yet checked; true = correct; false = incorrect
  bool? _result;

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _check() {
    final input = _controller.text.trim();
    if (input.isEmpty) return;
    final answers = widget.content.correctAnswers ?? [];
    // Always case-insensitive; exactMatch (case-sensitive) to be wired
    // up in a future iteration when the option is added to the UI.
    final correct =
        answers.any((a) => a.toLowerCase() == input.toLowerCase());
    setState(() => _result = correct);
  }

  void _tryAgain() {
    setState(() {
      _controller.clear();
      _result = null;
    });
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final answered = _result != null;
    final isCorrect = _result == true;

    // Tint the card background to reinforce the result.
    final cardColor = answered
        ? (isCorrect
            ? Colors.green.withValues(alpha: 0.08)
            : scheme.errorContainer.withValues(alpha: 0.4))
        : null;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      color: cardColor,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _FieldLabel(name: widget.field.name),

            // Optional hint.
            if (widget.content.hint != null) ...[
              const SizedBox(height: 4),
              Text(
                widget.content.hint!,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],

            const SizedBox(height: 12),

            // Text field + Check button (side by side).
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    enabled: !answered,
                    textInputAction: TextInputAction.done,
                    onSubmitted: answered ? null : (_) => _check(),
                    decoration: const InputDecoration(
                      hintText: 'Type your answer',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                if (!answered) ...[
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _check,
                    child: const Text('Check'),
                  ),
                ],
              ],
            ),

            // Feedback row — shown after the user submits.
            if (answered) ...[
              const SizedBox(height: 10),
              if (isCorrect)
                Row(children: [
                  Icon(Icons.check_circle_outline,
                      color: Colors.green[700], size: 20),
                  const SizedBox(width: 6),
                  Text(
                    'Correct!',
                    style: TextStyle(
                        color: Colors.green[700],
                        fontWeight: FontWeight.bold),
                  ),
                ])
              else ...[
                Row(
                  children: [
                    Icon(Icons.cancel_outlined,
                        color: scheme.error, size: 20),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Incorrect',
                        style: TextStyle(
                            color: scheme.error,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                    TextButton(
                        onPressed: _tryAgain,
                        child: const Text('Try Again')),
                  ],
                ),
                // Show the expected answer after a wrong attempt.
                const SizedBox(height: 4),
                Text(
                  'Answer: ${widget.content.correctAnswers?.join(' / ') ?? ''}',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _MultipleChoiceFieldCard — vertical list of option buttons.
// After selection: correct option turns green, wrong selection turns red.
// ---------------------------------------------------------------------------
class _MultipleChoiceFieldCard extends StatefulWidget {
  final CardField field;
  final MultipleChoiceContent content;
  const _MultipleChoiceFieldCard(
      {required this.field, required this.content});

  @override
  State<_MultipleChoiceFieldCard> createState() =>
      _MultipleChoiceFieldCardState();
}

class _MultipleChoiceFieldCardState
    extends State<_MultipleChoiceFieldCard> {
  int? _selectedIndex;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final options = widget.content.options ?? [];
    final correctIndex = widget.content.correctIndex;
    final answered = _selectedIndex != null;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _FieldLabel(name: widget.field.name),
            const SizedBox(height: 12),

            for (var i = 0; i < options.length; i++)
              _OptionButton(
                label: options[i],
                state: _stateFor(i, correctIndex, answered),
                onTap:
                    answered ? null : () => setState(() => _selectedIndex = i),
              ),

            // Optional explanation shown after answering.
            if (answered && widget.content.explanation != null) ...[
              const SizedBox(height: 8),
              Text(
                widget.content.explanation!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontStyle: FontStyle.italic),
              ),
            ],
          ],
        ),
      ),
    );
  }

  _OptionState _stateFor(int i, int? correctIndex, bool answered) {
    if (!answered) return _OptionState.neutral;
    if (i == correctIndex) return _OptionState.correct;
    if (i == _selectedIndex) return _OptionState.incorrect;
    return _OptionState.neutral;
  }
}

enum _OptionState { neutral, correct, incorrect }

// Single option button with semantic colour coding post-answer.
class _OptionButton extends StatelessWidget {
  final String label;
  final _OptionState state;
  final VoidCallback? onTap;
  const _OptionButton(
      {required this.label, required this.state, this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final Color bg;
    final Color border;
    final Color fg;

    switch (state) {
      case _OptionState.correct:
        bg = Colors.green.withValues(alpha: 0.12);
        border = Colors.green[700]!;
        fg = Colors.green[800]!;
      case _OptionState.incorrect:
        bg = scheme.errorContainer.withValues(alpha: 0.5);
        border = scheme.error;
        fg = scheme.error;
      case _OptionState.neutral:
        bg = Colors.transparent;
        border = scheme.outline;
        fg = scheme.onSurface;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton(
          onPressed: onTap,
          style: OutlinedButton.styleFrom(
            backgroundColor: bg,
            side: BorderSide(color: border),
            foregroundColor: fg,
            // Override disabled colours so the result highlight stays visible.
            disabledForegroundColor: fg,
            disabledBackgroundColor: bg,
            alignment: Alignment.centerLeft,
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          child: Text(label),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _NavigationBar — Previous / Next buttons with a "X of Y" counter.
// Know / Don't Know marking is added in Phase 5c.
// ---------------------------------------------------------------------------
class _NavigationBar extends StatelessWidget {
  final int currentIndex;
  final int total;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  const _NavigationBar({
    required this.currentIndex,
    required this.total,
    required this.onPrevious,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 24),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
              color: Theme.of(context).colorScheme.outlineVariant),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            iconSize: 32,
            tooltip: 'Previous card',
            onPressed: currentIndex > 0 ? onPrevious : null,
          ),
          Expanded(
            child: Text(
              '${currentIndex + 1} / $total',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            iconSize: 32,
            tooltip: 'Next card',
            onPressed: currentIndex < total - 1 ? onNext : null,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _FieldLabel — shared field-name label used by all additional field cards.
// ---------------------------------------------------------------------------
class _FieldLabel extends StatelessWidget {
  final String name;
  const _FieldLabel({required this.name});

  @override
  Widget build(BuildContext context) => Text(
        name,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant),
      );
}
