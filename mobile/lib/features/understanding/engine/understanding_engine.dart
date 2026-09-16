import 'package:tindak/core/clock/clock.dart';
import 'package:tindak/features/understanding/detectors/date_detector.dart';
import 'package:tindak/features/understanding/detectors/entity_detector.dart';
import 'package:tindak/features/understanding/detectors/money_detector.dart';
import 'package:tindak/features/understanding/detectors/phone_detector.dart';
import 'package:tindak/features/understanding/detectors/url_detector.dart';
import 'package:tindak/features/understanding/model/detected_entity.dart';
import 'package:tindak/features/understanding/model/understanding_result.dart';
import 'package:tindak/features/understanding/normalizer/content_normalizer.dart';

/// Turns text into structured meaning, locally.
///
/// ```text
/// input ─► ContentNormalizer ─► every detector ─► overlap resolution ─► result
/// ```
///
/// Pure Dart. No Flutter, no I/O, no network — which is what lets the whole
/// understanding layer run in unit tests on the Dart VM (ADR-005,
/// docs/10_ARCHITECTURE.md section 5).
///
/// It understands and nothing more. It does not call, open, check, save or
/// decide what the user should do; that is M4.
final class UnderstandingEngine {
  const UnderstandingEngine({
    this.normalizer = const ContentNormalizer(),
    this.detectors = defaultDetectors,
    this.maxInputLength = defaultMaxInputLength,
  });

  /// PD-028. Longer input is still displayed and still saveable; only its start
  /// is analysed (docs/10_ARCHITECTURE.md section 9.2).
  static const int defaultMaxInputLength = 10000;

  /// Detectors with a real clock. A date with no year resolves against today,
  /// so anything that depends on "today" should build the engine with
  /// [UnderstandingEngine.withClock] instead.
  static const List<EntityDetector> defaultDetectors = <EntityDetector>[
    UrlDetector(),
    PhoneDetector(),
    MoneyDetector(),
    DateDetector(),
  ];

  /// The engine with its clock injected — what the app uses, and what a test
  /// pins so no-year dates behave the same in January as in December
  /// (docs/20_TEST_PLAN.md section 1).
  factory UnderstandingEngine.withClock(Clock clock) => UnderstandingEngine(
    detectors: <EntityDetector>[
      const UrlDetector(),
      const PhoneDetector(),
      const MoneyDetector(),
      DateDetector(clock: clock),
    ],
  );

  final ContentNormalizer normalizer;
  final List<EntityDetector> detectors;
  final int maxInputLength;

  UnderstandingResult understand(String input) {
    final wasTruncated = input.length > maxInputLength;
    final analysed = wasTruncated ? input.substring(0, maxInputLength) : input;

    final content = normalizer.normalize(analysed);
    final candidates = <DetectedEntity>[
      for (final detector in detectors) ...detector.detect(content),
    ];

    final entities = _resolveOverlaps(candidates)
      ..retainWhere(_carriesNoInvisibleCharacters)
      ..sort((a, b) {
        final byStart = a.start.compareTo(b.start);
        return byStart != 0 ? byStart : a.end.compareTo(b.end);
      });

    return UnderstandingResult(
      content: content,
      entities: entities,
      wasTruncated: wasTruncated,
    );
  }

  /// One place decides between detectors, so detectors never need to know
  /// about each other.
  ///
  /// - An entity strictly inside another is part of it and is dropped. The
  ///   digits in `https://example.com/012-3456789` belong to the link, whatever
  ///   either detector's confidence.
  /// - Otherwise, where two entities overlap, the more confident wins; ties go
  ///   to the type with the lower priority number, then to the earlier start.
  static List<DetectedEntity> _resolveOverlaps(
    List<DetectedEntity> candidates,
  ) {
    final kept = <DetectedEntity>[];

    for (final candidate in candidates) {
      var keep = true;
      final displaced = <DetectedEntity>[];

      for (final existing in kept) {
        if (!candidate.overlaps(existing)) continue;

        if (candidate.isStrictlyInside(existing)) {
          keep = false;
          break;
        }
        if (existing.isStrictlyInside(candidate)) {
          displaced.add(existing);
          continue;
        }
        if (_beats(existing, candidate)) {
          keep = false;
          break;
        }
        displaced.add(existing);
      }

      if (keep) {
        kept
          ..removeWhere(displaced.contains)
          ..add(candidate);
      }
    }
    return kept;
  }

  static bool _beats(DetectedEntity a, DetectedEntity b) {
    if (a.confidence != b.confidence) return a.confidence > b.confidence;
    if (a.type.priority != b.type.priority) {
      return a.type.priority < b.type.priority;
    }
    return a.start <= b.start;
  }

  /// PD-032, enforced a second time.
  ///
  /// The normaliser already removed every format character, so this never
  /// drops anything today. It exists so the guarantee survives a future
  /// detector that builds a value from somewhere other than normalised text.
  static bool _carriesNoInvisibleCharacters(DetectedEntity entity) =>
      !ContentNormalizer.containsFormatCharacter(entity.rawValue) &&
      !ContentNormalizer.containsFormatCharacter(entity.normalizedValue);
}
