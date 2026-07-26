// Verifies the KeyboardActions wrapper (#235): Enter fires the confirm
// callback, Esc fires the cancel callback, and Enter stands down while a
// multi-line field or a button holds focus so it doesn't hijack a newline or a
// button activation.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flash_me/widgets/keyboard_actions.dart';

void main() {
  Widget host({
    required Widget child,
    VoidCallback? onConfirm,
    VoidCallback? onCancel,
    bool autofocus = true,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: KeyboardActions(
          onConfirm: onConfirm,
          onCancel: onCancel,
          autofocus: autofocus,
          child: child,
        ),
      ),
    );
  }

  testWidgets('Enter fires onConfirm, Esc fires onCancel', (tester) async {
    var confirmed = 0;
    var cancelled = 0;
    await tester.pumpWidget(
      host(
        onConfirm: () => confirmed++,
        onCancel: () => cancelled++,
        child: const Text('body'),
      ),
    );
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(confirmed, 1, reason: 'Enter confirms');
    expect(cancelled, 0);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(cancelled, 1, reason: 'Esc cancels');
    expect(confirmed, 1);
  });

  testWidgets('Enter does not confirm while a multi-line field has focus', (
    tester,
  ) async {
    var confirmed = 0;
    final focusNode = FocusNode();
    addTearDown(focusNode.dispose);
    await tester.pumpWidget(
      host(
        onConfirm: () => confirmed++,
        autofocus: false,
        child: TextField(focusNode: focusNode, maxLines: 3),
      ),
    );
    focusNode.requestFocus();
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(
      confirmed,
      0,
      reason: 'Enter is a newline in a multi-line field, not a confirm',
    );
  });

  testWidgets('Enter still confirms from a single-line field is left to the '
      'field, but the wrapper confirms when focus is elsewhere', (
    tester,
  ) async {
    // Focus on the wrapper (nothing text-editing) — Enter should confirm.
    var confirmed = 0;
    await tester.pumpWidget(
      host(onConfirm: () => confirmed++, child: const Text('body')),
    );
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(confirmed, 1);
  });

  testWidgets('Enter activates a focused button instead of onConfirm', (
    tester,
  ) async {
    var confirmed = 0;
    var buttonPressed = 0;
    final buttonFocus = FocusNode();
    addTearDown(buttonFocus.dispose);
    await tester.pumpWidget(
      host(
        onConfirm: () => confirmed++,
        autofocus: false,
        child: OutlinedButton(
          focusNode: buttonFocus,
          onPressed: () => buttonPressed++,
          child: const Text('btn'),
        ),
      ),
    );
    buttonFocus.requestFocus();
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(confirmed, 0, reason: 'wrapper stands down for a focused button');
    expect(buttonPressed, 1, reason: 'the focused button activates on Enter');
  });
}
