/// Reads the current time.
///
/// Injected rather than calling [DateTime.now] directly, because date
/// understanding is time-sensitive: a date with no year resolves to the next
/// occurrence (PD-025), so its behaviour depends on today. A parser whose tests
/// break in January is not tested — see docs/20_TEST_PLAN.md section 1.
abstract interface class Clock {
  /// The current instant, in local time.
  DateTime now();

  /// Today's date with the time component cleared.
  DateTime today();
}

/// The real clock. Used everywhere outside tests.
final class SystemClock implements Clock {
  const SystemClock();

  @override
  DateTime now() => DateTime.now();

  @override
  DateTime today() {
    final n = now();
    return DateTime(n.year, n.month, n.day);
  }
}

/// A clock pinned to a fixed instant.
///
/// Lives in `lib/` rather than `test/` so every test that depends on "today"
/// can pin it the same way.
final class FixedClock implements Clock {
  const FixedClock(this._instant);

  final DateTime _instant;

  @override
  DateTime now() => _instant;

  @override
  DateTime today() =>
      DateTime(_instant.year, _instant.month, _instant.day);
}
