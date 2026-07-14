import 'package:flash_me/utils/layout_breakpoints.dart';
import 'package:test/test.dart';

void main() {
  group('isWideWidth', () {
    test('just below the breakpoint is narrow', () {
      expect(isWideWidth(kWideLayoutBreakpoint - 1), isFalse);
    });

    test('exactly at the breakpoint is wide', () {
      expect(isWideWidth(kWideLayoutBreakpoint), isTrue);
    });

    test('well above the breakpoint is wide', () {
      expect(isWideWidth(1200), isTrue);
    });

    test('a typical phone width is narrow', () {
      expect(isWideWidth(390), isFalse);
    });
  });
}
