import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tindak/core/clock/clock_provider.dart';
import 'package:tindak/features/intake/intake_controller.dart';
import 'package:tindak/features/understanding/engine/understanding_engine.dart';
import 'package:tindak/features/understanding/model/understanding_result.dart';

/// Supplies the understanding engine.
///
/// Lives outside `features/understanding/` on purpose: that layer is pure Dart
/// with no Flutter or Riverpod imports, and a test enforces it.
final Provider<UnderstandingEngine> understandingEngineProvider =
    Provider<UnderstandingEngine>(
      // The clock reaches the engine because a date written without a year
      // resolves against today (PD-025).
      (ref) => UnderstandingEngine.withClock(ref.watch(clockProvider)),
    );

/// What TINDAK understood from the text currently on screen.
///
/// Recomputed whenever new text arrives, whichever intake path brought it. The
/// engine never learns which path that was (PD-033).
final Provider<UnderstandingResult?> intakeUnderstandingProvider =
    Provider<UnderstandingResult?>((ref) {
      final incoming = ref.watch(intakeControllerProvider);
      if (incoming == null) return null;
      return ref.watch(understandingEngineProvider).understand(incoming.text);
    });
