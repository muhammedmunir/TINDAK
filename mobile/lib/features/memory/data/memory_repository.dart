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

/// Memory on this device — the source of truth (ADR-014).
///
/// Everything here works with no connection. Nothing here talks to the cloud:
/// sync reads and acknowledges rows through `SyncStore`, never through this
/// interface, so a save or delete can never wait on the network (PD-042).
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

  /// Removes a memory and everything derived from it (PD-006). It disappears
  /// from Memory and search at once, whether or not sync has run yet.
  Future<Result<void>> delete(String id);
}

final class DriftMemoryRepository implements MemoryRepository {
  DriftMemoryRepository(
    this._db, {
    required Clock clock,
    Uuid uuid = const Uuid(),
    String? Function()? currentUserId,
  }) : _clock = clock,
       _uuid = uuid,
       _currentUserId = currentUserId ?? _guest;

  final TindakDatabase _db;
  final Clock _clock;
  final Uuid _uuid;

  /// The signed-in account, or null for a guest. Read on every call, so
  /// signing in or out takes effect without rebuilding the repository.
  final String? Function() _currentUserId;

  static String? _guest() => null;

  static const AppLogger _log = AppLogger('memory');

  static const String _localOnly = 'local_only';
  static const String _pending = 'pending';
  static const String _synced = 'synced';

  @override
  Future<Result<String>> save({
    required IncomingText incoming,
    required UnderstandingResult understanding,
  }) async {
    // PD-039: refused, never truncated. Counted in code points to match the
    // database constraint and the cloud schema. The database enforces the same
    // limit, so this check is the friendly refusal and the CHECK is the guard.
    if (incoming.text.runes.length > TindakDatabase.maxContentLength) {
      return const Result<String>.err(
        ContentTooLongFailure(TindakDatabase.maxContentLength),
      );
    }

    final id = _uuid.v4();
    final now = _clock.now().toUtc().millisecondsSinceEpoch;
    final owner = _currentUserId();

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
                // A guest's save stays on this phone. A signed-in save belongs
                // to the account and waits for sync (PD-042) — committed here
                // first, so it never depends on the network.
                ownerUserId: Value<String?>(owner),
                syncStatus: owner == null ? _localOnly : _pending,
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
        AND (m.owner_user_id IS NULL OR m.owner_user_id = ?6)
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
        // Unified Memory (PD-020): guest rows plus the signed-in account's.
        // No account id is empty, so a guest sees guest rows only.
        Variable<String>(_currentUserId() ?? ''),
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
      final row = await _visibleRow(id);
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
      final row = await _visibleRow(id);
      if (row == null) return const Result<void>.err(NotFoundFailure());

      // A guest row never leaves this phone, so there is no other copy to
      // inform: it is removed outright, entities and reminders by cascade. The
      // reconciler cancels any alarm those reminders still held.
      if (row.ownerUserId == null) {
        await (_db.delete(_db.memories)..where((m) => m.id.equals(id))).go();
        return const Result<void>.ok(null);
      }

      // An account row becomes a tombstone, which sync sends and then removes
      // here (PD-021). Even with no server acknowledgement yet: a push of this
      // row may be in flight, and a hard delete now would let the next pull
      // bring it back. Sync never uploads the content of a tombstone.
      final now = _clock.now().toUtc().millisecondsSinceEpoch;
      await _db.transaction(() async {
        await (_db.update(_db.memories)..where((m) => m.id.equals(id))).write(
          MemoriesCompanion(
            deletedAt: Value<int?>(now),
            // A device clock behind the save time must not break updated_at >=
            // created_at. The server sets its own updated_at regardless.
            updatedAt: Value<int>(now < row.createdAt ? row.createdAt : now),
            syncStatus: const Value<String>(_pending),
          ),
        );
        // A tombstoned row survives, so nothing cascades: its reminder is
        // cancelled here, or it would alert for an item the user deleted (M7).
        await _db.customStatement(
          "UPDATE reminders SET status = 'cancelled', updated_at = ?2 "
          "WHERE memory_id = ?1 AND status = 'scheduled'",
          <Object?>[id, _clock.now().millisecondsSinceEpoch],
        );
      });
      return const Result<void>.ok(null);
    } catch (error, stackTrace) {
      return _storageFailure<void>('delete', error, stackTrace);
    }
  }

  /// A row the current user may see: not deleted, and guest-owned or owned by
  /// the signed-in account. Another account's rows are never visible.
  Future<MemoryRow?> _visibleRow(String id) {
    final uid = _currentUserId();
    return (_db.select(_db.memories)..where((m) {
          final owned = uid == null
              ? m.ownerUserId.isNull()
              : m.ownerUserId.isNull() | m.ownerUserId.equals(uid);
          return m.id.equals(id) & m.deletedAt.isNull() & owned;
        }))
        .getSingleOrNull();
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
      final record = _toRecord(
        row,
        byMemory[row.id] ?? const <DetectedEntity>[],
      );
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
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        row.createdAt,
        isUtc: true,
      ).toLocal(),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        row.updatedAt,
        isUtc: true,
      ).toLocal(),
      entities: entities,
      storage: row.ownerUserId == null
          ? MemoryStorage.deviceOnly
          : row.syncStatus == _synced
          ? MemoryStorage.synced
          : MemoryStorage.pendingSync,
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
