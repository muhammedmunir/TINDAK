import 'package:drift/drift.dart';

import 'package:tindak/core/clock/clock.dart';
import 'package:tindak/core/database/tindak_database.dart';
import 'package:tindak/core/failure/failure.dart';
import 'package:tindak/core/logging/app_logger.dart';
import 'package:tindak/core/result/result.dart';
import 'package:tindak/features/intake/incoming_text.dart';
import 'package:tindak/features/memory/data/memory_search.dart';
import 'package:tindak/features/memory/model/memory_record.dart';
import 'package:tindak/features/understanding/model/detected_entity.dart';
import 'package:tindak/features/understanding/model/entity_type.dart';
import 'package:tindak/features/understanding/model/understanding_result.dart';
import 'package:uuid/uuid.dart';

/// Memory could not be read. Carries no detail, deliberately: the underlying
/// error can quote SQL, and nothing the UI shows needs more than this.
final class MemoryStorageException implements Exception {
  const MemoryStorageException();

  @override
  String toString() => 'MemoryStorageException';
}

/// Local Memory (M5a).
///
/// Everything here works with no network permission and no connection.
abstract interface class MemoryRepository {
  /// Stores one item because the user pressed Simpan.
  ///
  /// Every call creates a new memory. Two explicit saves are two memories;
  /// nothing is deduplicated here.
  Future<Result<String>> save({
    required IncomingText incoming,
    required UnderstandingResult understanding,
  });

  /// Every visible memory matching [query], newest first. Re-emits whenever
  /// memories change.
  Stream<List<MemoryRecord>> watch({String query = ''});

  Future<Result<MemoryRecord>> findById(String id);

  /// Permanently removes a memory and everything derived from it (PD-006).
  Future<Result<void>> delete(String id);
}

final class DriftMemoryRepository implements MemoryRepository {
  DriftMemoryRepository(this._db, {required Clock clock, Uuid uuid = const Uuid()})
    : _clock = clock,
      _uuid = uuid;

  final TindakDatabase _db;
  final Clock _clock;
  final Uuid _uuid;

  static const AppLogger _log = AppLogger('memory');

  /// Sync status of every row written in M5a.
  static const String _localOnly = 'local_only';

  @override
  Future<Result<String>> save({
    required IncomingText incoming,
    required UnderstandingResult understanding,
  }) async {
    final id = _uuid.v4();
    final now = _clock.now().toUtc().millisecondsSinceEpoch;

    try {
      await _db.transaction(() async {
        await _db
            .into(_db.memories)
            .insert(
              MemoriesCompanion.insert(
                id: id,
                // The original text, never a normalised reconstruction.
                content: incoming.text,
                intakeSource: incoming.source.name,
                sourceApp: Value<String?>(incoming.sourceApp),
                createdAt: now,
                updatedAt: now,
                // Guest-owned and local only. M5a has no account to own it and
                // no cloud to send it to.
                ownerUserId: const Value<String?>(null),
                syncStatus: _localOnly,
              ),
            );

        for (final entity in understanding.entities) {
          await _db
              .into(_db.memoryEntities)
              .insert(
                MemoryEntitiesCompanion.insert(
                  id: _uuid.v4(),
                  memoryId: id,
                  type: entity.type.name,
                  rawValue: entity.rawValue,
                  normalizedValue: entity.normalizedValue,
                  searchValue: MemorySearch.searchValueFor(entity),
                  confidence: entity.confidence,
                  startOffset: entity.start,
                  endOffset: entity.end,
                  createdAt: now,
                ),
              );
        }
      });
      return Result<String>.ok(id);
    } catch (error, stackTrace) {
      return _storageFailure<String>('save', error, stackTrace);
    }
  }

  @override
  Stream<List<MemoryRecord>> watch({String query = ''}) {
    final text = MemorySearch.textOf(query);
    final digits = MemorySearch.digitsOf(query);

    final rows = _db.customSelect(
      '''
      SELECT m.* FROM memories m
      WHERE m.deleted_at IS NULL
        AND (
          ?1 = ''
          OR m.content LIKE ?2 ESCAPE '\\'
          OR EXISTS (
            SELECT 1 FROM memory_entities e
            WHERE e.memory_id = m.id
              AND (
                e.search_value LIKE ?3 ESCAPE '\\'
                OR (?4 <> '' AND e.search_value LIKE ?5 ESCAPE '\\')
              )
          )
        )
      ORDER BY m.created_at DESC, m.id DESC
      ''',
      variables: <Variable<Object>>[
        Variable<String>(text),
        Variable<String>(MemorySearch.containsPattern(text)),
        Variable<String>(MemorySearch.containsPattern(text.toLowerCase())),
        Variable<String>(digits),
        Variable<String>(MemorySearch.containsPattern(digits)),
      ],
      readsFrom: <ResultSetImplementation<dynamic, dynamic>>{
        _db.memories,
        _db.memoryEntities,
      },
    );

    return rows
        .map((row) => _db.memories.map(row.data))
        .watch()
        .asyncMap(_withEntities)
        .handleError((Object error, StackTrace stackTrace) {
          _log.failure(
            'memory_watch_failed_${error.runtimeType}',
            stackTrace: stackTrace,
          );
          // Replaced, not rethrown: the original error can quote SQL, and the
          // UI only needs to know that Memory could not be read.
          throw const MemoryStorageException();
        });
  }

  @override
  Future<Result<MemoryRecord>> findById(String id) async {
    try {
      final row =
          await (_db.select(_db.memories)
                ..where((m) => m.id.equals(id) & m.deletedAt.isNull()))
              .getSingleOrNull();
      if (row == null) {
        return const Result<MemoryRecord>.err(NotFoundFailure());
      }

      final records = await _withEntities(<MemoryRow>[row]);
      if (records.isEmpty) {
        return const Result<MemoryRecord>.err(NotFoundFailure());
      }
      return Result<MemoryRecord>.ok(records.single);
    } catch (error, stackTrace) {
      return _storageFailure<MemoryRecord>('find', error, stackTrace);
    }
  }

  @override
  Future<Result<void>> delete(String id) async {
    try {
      final row =
          await (_db.select(_db.memories)
                ..where((m) => m.id.equals(id) & m.deletedAt.isNull()))
              .getSingleOrNull();
      if (row == null) return const Result<void>.err(NotFoundFailure());

      // M5a only ever writes local_only rows, and a row that never left the
      // device needs no tombstone: it is removed outright, with its entities by
      // cascade. A row that has been synced must instead become a tombstone so
      // other devices learn of the deletion (PD-021) — that is M5b's job, and
      // until it exists such a row is refused rather than silently hard
      // deleted and later resurrected by a sync.
      if (row.syncStatus != _localOnly) {
        _log.failure('memory_delete_requires_sync');
        return const Result<void>.err(UnexpectedFailure('delete_requires_sync'));
      }

      await (_db.delete(_db.memories)..where((m) => m.id.equals(id))).go();
      return const Result<void>.ok(null);
    } catch (error, stackTrace) {
      return _storageFailure<void>('delete', error, stackTrace);
    }
  }

  /// Attaches entities to rows, and maps both to domain types.
  ///
  /// A row that cannot be mapped is skipped and logged by code, not by content.
  /// One malformed row must never take the whole Memory list down with it.
  Future<List<MemoryRecord>> _withEntities(List<MemoryRow> rows) async {
    if (rows.isEmpty) return const <MemoryRecord>[];

    final ids = rows.map((r) => r.id).toList();
    final entityRows =
        await (_db.select(_db.memoryEntities)
              ..where((e) => e.memoryId.isIn(ids))
              ..orderBy(<OrderingTerm Function($MemoryEntitiesTable)>[
                (e) => OrderingTerm.asc(e.startOffset),
              ]))
            .get();

    final byMemory = <String, List<DetectedEntity>>{};
    for (final row in entityRows) {
      final entity = _toEntity(row);
      if (entity == null) continue;
      byMemory.putIfAbsent(row.memoryId, () => <DetectedEntity>[]).add(entity);
    }

    final records = <MemoryRecord>[];
    for (final row in rows) {
      final record = _toRecord(row, byMemory[row.id] ?? const <DetectedEntity>[]);
      if (record != null) records.add(record);
    }
    return records;
  }

  static MemoryRecord? _toRecord(MemoryRow row, List<DetectedEntity> entities) {
    final source = IntakeSource.values.asNameMap()[row.intakeSource];
    if (source == null) {
      _log.failure('memory_row_unknown_source');
      return null;
    }
    return MemoryRecord(
      id: row.id,
      content: row.content,
      source: source,
      sourceApp: row.sourceApp,
      createdAt: DateTime.fromMillisecondsSinceEpoch(row.createdAt, isUtc: true)
          .toLocal(),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(row.updatedAt, isUtc: true)
          .toLocal(),
      entities: entities,
    );
  }

  /// Returns null for an entity this version of TINDAK does not understand —
  /// for instance a type added by a later release — rather than guessing.
  static DetectedEntity? _toEntity(MemoryEntityRow row) {
    final type = EntityType.values.asNameMap()[row.type];
    if (type == null) return null;
    if (row.startOffset < 0 || row.endOffset <= row.startOffset) return null;
    if (row.confidence < 0 || row.confidence > 1) return null;

    return DetectedEntity(
      type: type,
      rawValue: row.rawValue,
      normalizedValue: row.normalizedValue,
      confidence: row.confidence,
      start: row.startOffset,
      end: row.endOffset,
    );
  }

  /// Logs the operation and the error's type — never the error itself. A
  /// SQLite error can quote the statement or constraint it failed on, and
  /// saved text must not reach a log (docs/12_SECURITY.md section 11).
  static Result<T> _storageFailure<T>(
    String operation,
    Object error,
    StackTrace stackTrace,
  ) {
    _log.failure(
      'memory_${operation}_failed_${error.runtimeType}',
      stackTrace: stackTrace,
    );
    return Result<T>.err(const StorageFailure());
  }
}
