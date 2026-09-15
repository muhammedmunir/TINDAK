import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tindak/core/clock/clock_provider.dart';
import 'package:tindak/core/database/tindak_database.dart';
import 'package:tindak/core/failure/failure.dart';
import 'package:tindak/core/logging/app_logger.dart';
import 'package:tindak/core/result/result.dart';
import 'package:tindak/features/intake/incoming_text.dart';
import 'package:tindak/features/memory/data/memory_repository.dart';
import 'package:tindak/features/memory/model/memory_record.dart';
import 'package:tindak/features/understanding/model/understanding_result.dart';

/// The device database. Opened lazily on first use, closed with the app.
/// Overridden with an in-memory database in tests.
final Provider<TindakDatabase> databaseProvider = Provider<TindakDatabase>((
  ref,
) {
  final db = TindakDatabase.onDevice();
  ref.onDispose(db.close);
  return db;
});

final Provider<MemoryRepository> memoryRepositoryProvider =
    Provider<MemoryRepository>(
      (ref) => DriftMemoryRepository(
        ref.watch(databaseProvider),
        clock: ref.watch(clockProvider),
      ),
    );

/// The text in the Memory search field.
final NotifierProvider<MemoryQuery, String> memoryQueryProvider =
    NotifierProvider<MemoryQuery, String>(MemoryQuery.new);

class MemoryQuery extends Notifier<String> {
  @override
  String build() => '';

  void update(String query) => state = query;
}

/// Visible memories matching the current search, newest first.
final StreamProvider<List<MemoryRecord>> memoryListProvider =
    StreamProvider<List<MemoryRecord>>(
      (ref) => ref
          .watch(memoryRepositoryProvider)
          .watch(query: ref.watch(memoryQueryProvider)),
    );

/// One memory, for the detail screen.
final memoryDetailProvider = FutureProvider.autoDispose
    .family<Result<MemoryRecord>, String>(
      (ref, id) => ref.watch(memoryRepositoryProvider).findById(id),
    );

/// True while a save is being written, so Simpan can show that the press was
/// received and cannot be pressed again (PD-040).
final NotifierProvider<MemorySaving, bool> memorySavingProvider =
    NotifierProvider<MemorySaving, bool>(MemorySaving.new);

class MemorySaving extends Notifier<bool> {
  @override
  bool build() => false;

  void set({required bool inFlight}) => state = inFlight;
}

final Provider<MemorySaver> memorySaverProvider = Provider<MemorySaver>(
  (ref) => MemorySaver(
    ref.watch(memoryRepositoryProvider),
    onInFlightChanged: (inFlight) =>
        ref.read(memorySavingProvider.notifier).set(inFlight: inFlight),
  ),
);

/// What happened when the user pressed Simpan.
enum SaveOutcome {
  saved,

  /// The content exceeds the Memory limit and was refused, not truncated
  /// (PD-039).
  tooLong,

  failed,

  /// The previous press was still being written. Ignored, so one physical
  /// double tap does not become two memories (PD-040).
  busy,
}

/// Saves because the user pressed Simpan — and for no other reason.
///
/// **Called from the Simpan button's `onPressed` and from nowhere else.** Not on
/// share, paste, detection, action, render or resume (PD-003).
///
/// Every completed press creates a new memory; there is no content-based
/// duplicate suppression. Only a press that arrives while the previous one is
/// still being written is ignored — concurrency protection, not deduplication
/// (PD-040).
final class MemorySaver {
  MemorySaver(
    this._repository, {
    void Function(bool inFlight)? onInFlightChanged,
  }) : _onInFlightChanged = onInFlightChanged;

  final MemoryRepository _repository;
  final void Function(bool inFlight)? _onInFlightChanged;
  bool _inFlight = false;

  static const AppLogger _log = AppLogger('memory');

  Future<SaveOutcome> save({
    required IncomingText incoming,
    required UnderstandingResult understanding,
  }) async {
    if (_inFlight) return SaveOutcome.busy;
    _setInFlight(true);
    try {
      final result = await _repository.save(
        incoming: incoming,
        understanding: understanding,
      );
      return switch (result) {
        Ok<String>() => SaveOutcome.saved,
        Err<String>(failure: ContentTooLongFailure()) => SaveOutcome.tooLong,
        Err<String>() => SaveOutcome.failed,
      };
    } catch (error, stackTrace) {
      _log.failure(
        'memory_save_threw_${error.runtimeType}',
        stackTrace: stackTrace,
      );
      return SaveOutcome.failed;
    } finally {
      _setInFlight(false);
    }
  }

  void _setInFlight(bool value) {
    _inFlight = value;
    _onInFlightChanged?.call(value);
  }
}
