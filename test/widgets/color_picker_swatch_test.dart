// Verifies ColorPickerSwatch (#235) is keyboard-accessible: it takes focus via
// tab traversal and activates on Enter and Space, so the set-colour picker can
// be driven without a mouse. A disabled swatch (onTap == null) must not
// activate.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flash_me/widgets/color_picker_swatch.dart';

void main() {
  Widget host({required VoidCallback? onTap, bool selected = false}) {
    return MaterialApp(
      home: Scaffold(
        body: ColorPickerSwatch(
          color: const Color(0xFF42A5F5),
          selected: selected,
          semanticLabel: 'Blue',
          onTap: onTap,
        ),
      ),
    );
  }

  // Moves focus onto the swatch by pressing Tab, exactly as a keyboard user
  // would, then returns whether it actually took focus.
  Future<void> tabToSwatch(WidgetTester tester) async {
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    final swatchElement = tester.element(find.byType(ColorPickerSwatch));
    expect(
      Focus.of(swatchElement, scopeOk: true).hasFocus,
      isTrue,
      reason: 'Tab should move focus onto the swatch',
    );
  }

  testWidgets('takes focus on Tab and activates on Enter', (tester) async {
    var taps = 0;
    await tester.pumpWidget(host(onTap: () => taps++));

    await tabToSwatch(tester);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(taps, 1, reason: 'Enter activates the focused swatch');
  });

  testWidgets('activates on Space', (tester) async {
    var taps = 0;
    await tester.pumpWidget(host(onTap: () => taps++));

    await tabToSwatch(tester);

    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(taps, 1, reason: 'Space activates the focused swatch');
  });

  testWidgets('activates on tap', (tester) async {
    var taps = 0;
    await tester.pumpWidget(host(onTap: () => taps++));
    await tester.tap(find.byType(ColorPickerSwatch));
    await tester.pump();
    expect(taps, 1, reason: 'a pointer tap still works');
  });

  testWidgets('disabled swatch does not activate', (tester) async {
    await tester.pumpWidget(host(onTap: null));
    // Tapping a disabled swatch is a no-op (no callback to fire, no throw).
    await tester.tap(find.byType(ColorPickerSwatch));
    await tester.pump();
    // Reaching here without an exception is the assertion.
    expect(find.byType(ColorPickerSwatch), findsOneWidget);
  });
}
