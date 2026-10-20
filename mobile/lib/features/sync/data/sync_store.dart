import 'dart:convert';
import 'package:drift/drift.dart';

import 'package:tindak/core/database/tindak_database.dart';
import 'package:tindak/core/logging/app_logger.dart';
import 'package:tindak/features/intake/incoming_text.dart';
import 'package:tindak/features/memory/data/memory_search.dart';
import 'package:tindak/features/sync/data/cloud_memory_api.dart';
import 'package:tindak/features/understanding/model/detected_entity.dart';
import 'package:tindak/features/understanding/model/entity_type.dart';
import 'package:uuid/uuid.dart';

/// What a sign-out purge did, and which alarms it left for the caller to
/// cancel.
final class PurgeResult {
  const PurgeResult.purged(this.cancelledAlarmIds) : purged = true;
  const PurgeResult.refused()
    : purged = false,
      cancelledAlarmIds = const <int>[];

  /// False when changes were still waiting for the cloud, in which case
  /// nothing was deleted (PD-041).
  final bool purged;

  /// Notification ids whose alarms must now be cancelled.
  final List<int> cancelledAlarmIds;
}

/// The device side of sync: everything sync reads from or writes to SQLite.
///
/// Every query is scoped to one account id. Guest rows are touched in exactly
/// one place — [migrateGuestRows] — and only because the user pressed Sync
/// (PD-044).
final class SyncStore {
  SyncStore(this._db, {Uuid uuid = const Uuid()}) : _uuid = uuid;

  final TindakDatabase _db;
  final Uuid _uuid;

  static const AppLogger _log = AppLogger('sync');

  static const String _pending = 'pending';
  static const String _synced = 'synced';

  static String _cursorKey(String userId) => 'pull_cursor:$userId';
  static String _lastPullKey(String userId) => 'last_pull_at:$userId';

  // ---------------------------------------------------------------------------
  // Push
  // ---------------------------------------------------------------------------

  /// This account's rows waiting for the cloud — new memories and tombstones —
  /// oldest first.
  Future<List<CloudMemory>> pendingChanges(String userId) async {
    final rows =
        await (_db.select(_db.memories)
              ..where(
                (m) =>
                    m.ownerUserId.equals(userId) & m.syncStatus.equals(_pending),
              )
              ..orderBy(<OrderingTerm Function($MemoriesTable)>[
                (m) => OrderingTerm.asc(m.createdAt),
                (m) => OrderingTerm.asc(m.id),
              ]))
            .get();
    if (rows.isEmpty) return const <CloudMemory>[];

    final entityRows = await (_db.select(
      _db.memoryEntities,
    )..where((e) => e.memoryId.isIn(rows.map((r) => r.id)))).get();
    final byMemory = <String, List<CloudEntity>>{};
    for (final e in entityRows) {
      byMemory
          .putIfAbsent(e.memoryId, () => <CloudEntity>[])
          .add(
            CloudEntity(
              id: e.id,
              type: e.type,
              rawValue: e.rawValue,
              normalizedValue: e.normalizedValue,
              confidence: e.confidence,
              start: e.startOffset,
              end: e.endOffset,
            ),
          );
    }

    return <CloudMemory>[
      for (final r in rows)
        CloudMemory(
          id: r.id,
          content: r.content,
          intakeSource: r.intakeSource,
          sourceApp: r.sourceApp,
          createdAt: _utc(r.createdAt),
          deletedAt: r.deletedAt == null ? null : _utc(r.deletedAt!),
          entities: byMemory[r.id] ?? const <CloudEntity>[],
        ),
    ];
  }

  /// Records that the server holds this memory.
  ///
  /// If the user deleted it while the push was in flight, the row is already a
  /// tombstone: it keeps `pending`, so the deletion is sent next, and now knows
  /// the server has a copy to delete.
  Future<void> acknowledgePush(
    String userId,
    String memoryId,
    DateTime serverUpdatedAt,
  ) => _db.customUpdate(
    '''
    UPDATE memories
    SET server_updated_at = ?1,
        sync_status = CASE WHEN deleted_at IS NULL THEN '$_synced'
                           ELSE '$_pending' END
    WHERE id = ?2 AND owner_user_id = ?3
    ''',
    variables: <Variable<Object>>[
      Variable<int>(serverUpdatedAt.millisecondsSinceEpoch),
      Variable<String>(memoryId),
      Variable<String>(userId),
    ],
    updates: <TableInfo<Table, dynamic>>{_db.memories},
  );

  /// The cloud has the deletion; the local tombstone has done its job.
  Future<void> removeTombstone(String userId, String memoryId) =>
      (_db.delete(_db.memories)..where(
            (m) =>
                m.id.equals(memoryId) &
                m.ownerUserId.equals(userId) &
                m.deletedAt.isNotNull(),
          ))
          .go();

  // ---------------------------------------------------------------------------
  // Pull
  // ---------------------------------------------------------------------------

  /// Applies one page of server changes in a single transaction.
  ///
  /// Memories are immutable in V1 (docs/14_M5B_RECONCILIATION.md section 3.1),
  /// so a change is either a memory this device lacks, or a tombstone. Deletion
  /// always wins: a pulled tombstone removes the row, and a local tombstone is
  /// never undone by a pulled live copy.
  Future<void> applyPulled(String userId, List<CloudMemory> page) =>
      _db.transaction(() async {
        for (final memory in page) {
          await _applyOne(userId, memory);
        }
      });

  Future<void> _applyOne(String userId, CloudMemory memory) async {
    final serverTime = memory.updatedAt;
    if (serverTime == null) return;

    final local = await (_db.select(
      _db.memories,
    )..where((m) => m.id.equals(memory.id))).getSingleOrNull();

    // An id held by a guest row or another account is never overwritten or
    // reassigned by a pull.
    if (local != null && local.ownerUserId != userId) {
      _log.failure('sync_pull_owner_mismatch');
      return;
    }

    if (memory.deletedAt != null) {
      if (local != null) {
        await (_db.delete(
          _db.memories,
        )..where((m) => m.id.equals(memory.id))).go();
      }
      return;
    }

    if (local != null) {
      // A local tombstone stays: it is sent on the next push.
      if (local.deletedAt != null) {
        await (_db.update(
          _db.memories,
        )..where((m) => m.id.equals(memory.id))).write(
          MemoriesCompanion(
            serverUpdatedAt: Value<int?>(serverTime.millisecondsSinceEpoch),
          ),
        );
        return;
      }
      await (_db.update(
        _db.memories,
      )..where((m) => m.id.equals(memory.id))).write(
        MemoriesCompanion(
          serverUpdatedAt: Value<int?>(serverTime.millisecondsSinceEpoch),
          syncStatus: const Value<String>(_synced),
        ),
      );
      return;
    }

    // The server enforces the same rules, so these only trip on a server that
    // no longer does — and then the row is skipped, not stored broken.
    if (memory.content.runes.length > TindakDatabase.maxContentLength ||
        IntakeSource.values.asNameMap()[memory.intakeSource] == null) {
      _log.failure('sync_pull_invalid_memory');
      return;
    }

    final created = memory.createdAt.millisecondsSinceEpoch;
    final server = serverTime.millisecondsSinceEpoch;

    await _db
        .into(_db.memories)
        .insert(
          MemoriesCompanion.insert(
            id: memory.id,
            content: memory.content,
            intakeSource: memory.intakeSource,
            sourceApp: Value<String?>(memory.sourceApp),
            createdAt: created,
            // A save dated after the server's own time would break the local
            // updated_at >= created_at rule.
            updatedAt: server < created ? created : server,
            ownerUserId: Value<String?>(userId),
            syncStatus: _synced,
            serverUpdatedAt: Value<int?>(server),
          ),
        );

    for (final e in memory.entities) {
      if (e.start < 0 ||
          e.end <= e.start ||
          e.confidence < 0 ||
          e.confidence > 1) {
        _log.failure('sync_pull_invalid_entity');
        continue;
      }
      await _db
          .into(_db.memoryEntities)
          .insert(
            MemoryEntitiesCompanion.insert(
              id: e.id.isEmpty ? _uuid.v4() : e.id,
              memoryId: memory.id,
              type: e.type,
              rawValue: e.rawValue,
              normalizedValue: e.normalizedValue,
              searchValue: _searchValueFor(e),
              confidence: e.confidence,
              startOffset: e.start,
              endOffset: e.end,
              createdAt: created,
            ),
            mode: InsertMode.insertOrIgnore,
          );
    }
  }

  /// Search values are device-only and derived, so they are rebuilt on pull
  /// with exactly the rules used at save. A type this build does not know is
  /// stored and searchable by its value, but not shown.
  static String _searchValueFor(CloudEntity e) {
    final type = EntityType.values.asNameMap()[e.type];
    if (type == null) return e.normalizedValue.toLowerCase();
    return MemorySearch.searchValueFor(
      DetectedEntity(
        type: type,
        rawValue: e.rawValue,
        normalizedValue: e.normalizedValue,
        confidence: e.confidence,
        start: e.start,
        end: e.end,
      ),
    );
  }

  Future<SyncCursor?> cursor(String userId) async {
    final value = await _read(_cursorKey(userId));
    if (value == null) return null;
    try {
      return SyncCursor.decode(value);
    } on FormatException {
      // A cursor that cannot be read costs a full pull, never a skipped change.
      _log.failure('sync_cursor_unreadable');
      return null;
    }
  }

  Future<void> saveCursor(String userId, SyncCursor cursor) =>
      _write(_cursorKey(userId), cursor.encode());

  /// Device time of the last pull that completed, epoch ms.
  Future<DateTime?> lastPullAt(String userId) async {
    final value = int.tryParse(await _read(_lastPullKey(userId)) ?? '');
    return value == null ? null : _utc(value);
  }

  Future<void> saveLastPullAt(String userId, DateTime time) =>
      _write(_lastPullKey(userId), '${time.millisecondsSinceEpoch}');

  static String _stagingAttemptKey(String userId) =>
      'stage:$userId:active_attempt';
  static String _stagingMetaKey(String userId, String attemptId) =>
      'stage:$userId:$attemptId:meta';
  static String _stagingPageKey(
    String userId,
    String attemptId,
    int pageIndex,
  ) =>
      'stage:$userId:$attemptId:page:$pageIndex';

  /// Removes all persistent staging entries in SQLite for [userId].
  ///
  /// Guarantees that interrupted or incomplete attempts never leak or mix with
  /// future sync attempts or other accounts.
  Future<void> cleanStaging(String userId) async {
    final escaped = userId
        .replaceAll(r'\', r'\\')
        .replaceAll('%', r'\%')
        .replaceAll('_', r'\_');
    await _db.customStatement(
      "DELETE FROM sync_meta WHERE key LIKE ?1 ESCAPE '\\'",
      <Object?>['stage:$escaped:%'],
    );
  }

  /// Begins a persistent staging session for a full pull under [attemptId].
  ///
  /// Any prior uncommitted staging for [userId] is cleaned up first.
  Future<void> startFullPull(String userId, String attemptId) async {
    await cleanStaging(userId);
    await _write(_stagingAttemptKey(userId), attemptId);
    await _write(
      _stagingMetaKey(userId, attemptId),
      jsonEncode(<String, dynamic>{
        'attemptId': attemptId,
        'userId': userId,
        'complete': false,
        'pageCount': 0,
      }),
    );
  }

  /// Persists one page of pulled cloud memories into SQLite staging.
  Future<void> stageFullPullPage(
    String userId,
    String attemptId,
    int pageIndex,
    List<CloudMemory> page,
  ) async {
    final pageJson = jsonEncode(page.map((m) => m.toJson()).toList());
    await _write(
      _stagingPageKey(userId, attemptId, pageIndex),
      pageJson,
    );
    await _write(
      _stagingMetaKey(userId, attemptId),
      jsonEncode(<String, dynamic>{
        'attemptId': attemptId,
        'userId': userId,
        'complete': false,
        'pageCount': pageIndex + 1,
      }),
    );
  }

  /// Marks the staging session for [attemptId] as complete once all pages have
  /// been received from the cloud.
  ///
  /// Throws [StateError] if the metadata record for [userId]/[attemptId] does
  /// not exist or belongs to a different user or attempt. Creating synthetic
  /// metadata here would defeat the fail-closed guarantee: a staging session
  /// that was never started via [startFullPull] must not be committable.
  Future<void> markFullPullComplete(
    String userId,
    String attemptId,
  ) async {
    final metaStr = await _read(_stagingMetaKey(userId, attemptId));
    if (metaStr == null) {
      throw StateError(
        'Cannot mark full pull complete: staging meta missing for '
        'attempt $attemptId (userId=$userId). '
        'Was startFullPull() called for this attempt?',
      );
    }
    final meta = jsonDecode(metaStr) as Map<String, dynamic>;
    // Guard against cross-attempt or cross-user collisions in the key space.
    if (meta['attemptId'] != attemptId || meta['userId'] != userId) {
      throw StateError(
        'Cannot mark full pull complete: metadata mismatch — '
        'expected attemptId=$attemptId userId=$userId, '
        'got attemptId=${meta["attemptId"]} userId=${meta["userId"]}',
      );
    }
    meta['complete'] = true;
    await _write(_stagingMetaKey(userId, attemptId), jsonEncode(meta));
  }

  /// Returns whether staging for [attemptId] is complete.
  Future<bool> isFullPullStagingComplete(
    String userId,
    String attemptId,
  ) async {
    final metaStr = await _read(_stagingMetaKey(userId, attemptId));
    if (metaStr == null) return false;
    final meta = jsonDecode(metaStr) as Map<String, dynamic>;
    return meta['complete'] == true;
  }

  /// Atomically commits a completed full-pull staging session into SQLite
  /// (EAR-FIX-01):
  ///
  /// 1. Verifies staging completion. Refuses to commit partial datasets.
  /// 2. Reads all staged pages from SQLite.
  /// 3. In a single atomic SQLite transaction:
  ///    a. Collects all IDs present in the cloud dataset: [cloudIds].
  ///    b. Identifies local synced memories for [userId] that are NOT in
  ///       [cloudIds] (memories purged on the server after the 90-day window).
  ///       Collects reminder notification IDs for these purged memories so
  ///       alarms can be cancelled. Deletes only these purged memories; their
  ///       entities and reminders cascade delete.
  ///    c. For each memory in the staged dataset, applies it via [_applyOne].
  ///       Existing memories are updated in-place, so their active reminders
  ///       and notification IDs are 100% preserved in SQLite!
  ///    d. Unsynced changes (`sync_status = 'pending'`) and guest memories
  ///       (`owner_user_id IS NULL`) are completely untouched.
  ///    e. Updates the cursor if [finalCursor] is supplied, or removes it if
  ///       the cloud returned zero memories.
  ///    f. Cleans up staging keys for [userId].
  ///
  /// Returns the notification IDs of alarms for memories that were purged from
  /// the cloud.
  Future<List<int>> commitFullPull(
    String userId,
    String attemptId,
    SyncCursor? finalCursor,
  ) async {
    final metaStr = await _read(_stagingMetaKey(userId, attemptId));
    if (metaStr == null) {
      throw StateError('Cannot commit full pull: staging meta missing');
    }
    final meta = jsonDecode(metaStr) as Map<String, dynamic>;

    // Guard: metadata must identify this exact attempt and user.
    // Checked before 'complete' so cross-attempt corruption is reported accurately.
    if (meta['attemptId'] != attemptId || meta['userId'] != userId) {
      throw StateError(
        'Cannot commit full pull: metadata mismatch — '
        'expected attemptId=$attemptId userId=$userId, '
        'got attemptId=${meta["attemptId"]} userId=${meta["userId"]}',
      );
    }

    if (meta['complete'] != true) {
      throw StateError('Cannot commit full pull: staging is incomplete');
    }

    final pageCount = meta['pageCount'] as int? ?? 0;
    final stagedMemories = <CloudMemory>[];
    final missingPages = <int>[];

    for (var i = 0; i < pageCount; i++) {
      final pageKey = _stagingPageKey(userId, attemptId, i);
      final pageStr = await _read(pageKey);
      if (pageStr == null) {
        missingPages.add(i);
        continue;
      }
      final rawList = jsonDecode(pageStr) as List<dynamic>;
      for (final item in rawList) {
        stagedMemories.add(CloudMemory.fromJson(item as Map<String, dynamic>));
      }
    }

    // Fail closed: every page that was staged must still be present.
    // A missing page means the staging data is corrupt or was partially
    // cleaned up between markFullPullComplete and commitFullPull.
    // Committing a partial dataset would delete active memories whose IDs
    // were only in the missing pages, which is data loss.
    if (missingPages.isNotEmpty) {
      throw StateError(
        'Cannot commit full pull: staging pages missing for '
        'attempt $attemptId — missing page indices: $missingPages. '
        'The active dataset and cursor have not been modified.',
      );
    }

    final cancelledAlarmIds = <int>[];

    await _db.transaction(() async {
      final cloudIds = stagedMemories.map((m) => m.id).toSet();

      // Find local synced memories that no longer exist in the cloud.
      final localSynced = await (_db.select(_db.memories)
            ..where(
              (m) =>
                  m.ownerUserId.equals(userId) & m.syncStatus.equals(_synced),
            ))
          .get();

      final purged =
          localSynced.where((m) => !cloudIds.contains(m.id)).toList();

      for (final p in purged) {
        final alarms = await (_db.select(_db.reminders)
              ..where(
                (r) =>
                    r.memoryId.equals(p.id) & r.status.equals('scheduled'),
              ))
            .get();
        cancelledAlarmIds.addAll(alarms.map((a) => a.notificationId));
        await (_db.delete(_db.memories)..where((m) => m.id.equals(p.id))).go();
      }

      // Reconcile each staged cloud memory.
      // R1 fix: _applyOne deletes local rows for tombstoned memories via the
      // database cascade (ON DELETE CASCADE on reminders.memory_id). Those
      // reminder rows — and their notification IDs — must be collected BEFORE
      // _applyOne is called for any tombstoned memory, otherwise the cascade
      // deletes them silently and the OS alarm is never cancelled.
      //
      // Collect alarm IDs for tombstoned memories that have a local live row.
      final tombstonedIds =
          stagedMemories.where((m) => m.deletedAt != null).map((m) => m.id).toSet();
      if (tombstonedIds.isNotEmpty) {
        final tombstoneAlarms = await (_db.select(_db.reminders)
              ..where(
                (r) =>
                    r.memoryId.isIn(tombstonedIds) &
                    r.status.equals('scheduled'),
              ))
            .get();
        cancelledAlarmIds.addAll(
          tombstoneAlarms.map((a) => a.notificationId),
        );
      }

      for (final memory in stagedMemories) {
        await _applyOne(userId, memory);
      }

      if (finalCursor != null) {
        await saveCursor(userId, finalCursor);
      } else {
        await (_db.delete(
          _db.syncMeta,
        )..where((s) => s.key.equals(_cursorKey(userId)))).go();
      }

      await cleanStaging(userId);
    });

    return cancelledAlarmIds;
  }

  /// Retained for direct unit testing of full-pull reset behavior.
  Future<void> resetForFullPull(String userId) => _db.transaction(() async {
    await (_db.delete(_db.memories)..where(
          (m) =>
              m.ownerUserId.equals(userId) & m.syncStatus.equals(_synced),
        ))
        .go();
    await (_db.delete(
      _db.syncMeta,
    )..where((s) => s.key.equals(_cursorKey(userId)))).go();
  });

  // ---------------------------------------------------------------------------
  // Counts, migration and sign-out
  // ---------------------------------------------------------------------------

  /// This account's changes the cloud has not acknowledged.
  Stream<int> watchPendingCount(String userId) => _count(
    'owner_user_id = ?1 AND sync_status = ?2',
    <Variable<Object>>[Variable<String>(userId), const Variable<String>(_pending)],
  ).watchSingle();

  Future<int> pendingCount(String userId) => _count(
    'owner_user_id = ?1 AND sync_status = ?2',
    <Variable<Object>>[Variable<String>(userId), const Variable<String>(_pending)],
  ).getSingle();

  /// Visible guest items: saved on this phone before or without an account.
  Stream<int> watchGuestCount() => _count(
    'owner_user_id IS NULL AND deleted_at IS NULL',
    const <Variable<Object>>[],
  ).watchSingle();

  Future<int> guestCount() => _count(
    'owner_user_id IS NULL AND deleted_at IS NULL',
    const <Variable<Object>>[],
  ).getSingle();

  Selectable<int> _count(String where, List<Variable<Object>> variables) => _db
      .customSelect(
        'SELECT COUNT(*) AS n FROM memories WHERE $where',
        variables: variables,
        readsFrom: <ResultSetImplementation<dynamic, dynamic>>{_db.memories},
      )
      .map((row) => row.read<int>('n'));

  /// Gives every guest item on this device to the signed-in account.
  ///
  /// Called only from the Sync button on the migration prompt or in Settings
  /// (PD-044, PD-045). Ids are kept, so nothing is duplicated; the rows become
  /// pending and are pushed by the next sync. Returns how many moved.
  Future<int> migrateGuestRows(String userId) => _db.customUpdate(
    '''
    UPDATE memories
    SET owner_user_id = ?1, sync_status = '$_pending'
    WHERE owner_user_id IS NULL AND deleted_at IS NULL
    ''',
    variables: <Variable<Object>>[Variable<String>(userId)],
    updates: <TableInfo<Table, dynamic>>{_db.memories},
    updateKind: UpdateKind.update,
  );

  /// Removes this account's data from the device, but only when nothing of it
  /// is still waiting for the cloud (ADR-031). Checked and deleted in one
  /// transaction, so a save arriving in between cannot be deleted unsent.
  ///
  /// Returns [PurgeResult.refused], deleting nothing, when changes are still
  /// pending. On success it returns the reminder alarm ids it removed: the
  /// rows go by cascade with their memories, so the ids have to be read
  /// **before** the delete or the alarms could never be cancelled (M7b).
  Future<PurgeResult> purgeAccountIfSafe(String userId) =>
      _db.transaction(() async {
        if (await pendingCount(userId) > 0) return const PurgeResult.refused();

        final alarms = await _db
            .customSelect(
              '''
              SELECT r.notification_id AS id FROM reminders r
              JOIN memories m ON m.id = r.memory_id
              WHERE r.status = 'scheduled'
                AND (r.owner_user_id = ?1 OR m.owner_user_id = ?1)
              ''',
              variables: <Variable<Object>>[Variable<String>(userId)],
              readsFrom: <ResultSetImplementation<dynamic, dynamic>>{
                _db.reminders,
                _db.memories,
              },
            )
            .map((row) => row.read<int>('id'))
            .get();

        await (_db.delete(
          _db.memories,
        )..where((m) => m.ownerUserId.equals(userId))).go();
        // Any reminder still owned by the account whose memory was a guest
        // row, which the cascade above would have missed.
        await (_db.delete(
          _db.reminders,
        )..where((r) => r.ownerUserId.equals(userId))).go();
        await (_db.delete(_db.syncMeta)..where(
              (s) =>
                  s.key.equals(_cursorKey(userId)) |
                  s.key.equals(_lastPullKey(userId)),
            ))
            .go();
        await cleanStaging(userId);
        return PurgeResult.purged(alarms);
      });

  Future<String?> _read(String key) async {
    final row = await (_db.select(
      _db.syncMeta,
    )..where((s) => s.key.equals(key))).getSingleOrNull();
    return row?.value;
  }

  Future<void> _write(String key, String value) => _db
      .into(_db.syncMeta)
      .insertOnConflictUpdate(SyncMetaCompanion.insert(key: key, value: value));

  static DateTime _utc(int ms) =>
      DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
}
