import 'package:flutter_test/flutter_test.dart';
import 'package:tindak/core/clock/clock.dart';

void main() {
  group('FixedClock', () {
    test('now returns the pinned instant', () {
      final clock = FixedClock(DateTime(2026, 9, 10, 20, 42, 13));

      expect(clock.now(), DateTime(2026, 9, 10, 20, 42, 13));
    });

    test('today clears the time component', () {
      final clock = FixedClock(DateTime(2026, 9, 10, 20, 42, 13));

      expect(clock.today(), DateTime(2026, 9, 10));
    });

    test('holds across a year boundary', () {
      // PD-025 resolves a date with no year to the next occurrence, so the
      // date parser's behaviour depends on today. Pinning the clock is what
      // stops those tests breaking in January.
      final clock = FixedClock(DateTime(2026, 12, 31, 23, 59));

      expect(clock.today(), DateTime(2026, 12, 31));
    });
  });

  group('SystemClock', () {
    test('today has no time component', () {
      const clock = SystemClock();
      final today = clock.today();

      expect(today.hour, 0);
      expect(today.minute, 0);
      expect(today.second, 0);
      expect(today.millisecond, 0);
    });

    test('today matches now', () {
      const clock = SystemClock();
      final now = clock.now();
      final today = clock.today();

      expect(today.year, now.year);
      expect(today.month, now.month);
      expect(today.day, now.day);
    });
  });
}
