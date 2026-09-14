import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tindak/core/clock/clock.dart';

/// The application clock. Overridden with a [FixedClock] in tests.
final Provider<Clock> clockProvider = Provider<Clock>(
  (ref) => const SystemClock(),
);
