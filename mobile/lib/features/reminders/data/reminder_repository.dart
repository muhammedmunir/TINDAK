import 'package:drift/drift.dart';

import 'package:tindak/core/clock/clock.dart';
import 'package:tindak/core/database/tindak_database.dart';
import 'package:tindak/core/failure/failure.dart';
import 'package:tindak/core/logging/app_logger.dart';
import 'package:tindak/core/result/result.dart';
import 'package:tindak/features/intake/incoming_text.dart';
import 'package:tindak/features/memory/data/memory_repository.dart';
import 'package:tindak/features/reminders/model/reminder.dart';
import 'package:tindak/features/understanding/model/understanding_result.dart';
import 'package:uuid/uuid.dart';

/// Reminders on this device (M7a).
///
/// Device-local by decision (B-5): nothing here syncs, and no cloud table
/// exists. What the user chose — a date and a time of day — is what is stored;
/// the instant is derived from it (B-2).
///
/// This layer never schedules anything. It owns the rules; `ReminderScheduler`
/// owns delivery, and `ReminderReconciler` keeps the two in step.
abstract interface class ReminderRepository {
  /// Sets a reminder on a memory that is already saved.
  Future<Result<ReminderRecord>> create({
    required String memoryId,
    required LocalDateTime at,
  });

  /// Sets a reminder on a result that has not been saved yet, saving the
  /// memory first, in one transaction (implicit Save).
  Future<Result<ReminderRecord>> createWithMemory({
    required IncomingText incoming,
    required UnderstandingResult understanding,
    required LocalDateTime at,
  });

  /// Moves an existing reminder to a new time. The old one stays in force
  /// until the new one is committed (B-7).
  Future<Result<ReminderRecord>> replace({
    required String reminderId,
    required LocalDateTime at,
  });

  /// Cancels a reminder. The memory is untouched.
  Future<Result<void>> cancel(String reminderId);

  /// The memory's active reminder, or null.
  Future<ReminderRecord?> activeFor(String memoryId);

  /// The memory's reminders, newest first — the active one, if any, plus the
  /// history that stops a fired reminder from looking lost (B-4).
  Stream<List<ReminderRecord>> watchFor(String memoryId);

  /// Every active reminder on this device, for the reconciler.
  Future<List<ReminderRecord>> active();

  /// Marks a reminder as having alerted.
  Future<void> markFired(String reminderId);

  /// Records that the device scheduler now holds an alarm for this instant.
  Future<void> markScheduled(String reminderId, DateTime at);

  /// Cancels every active reminder on a memory, without touching the memory.
  /// Used when an account memory is tombstoned, where the row survives the
  /// delete and the cascade would not fire.
  Future<List<int>> cancelForMemory(String memoryId);

  /// Gives this account's reminders to it, alongside the memories that moved
  /// at guest migration (PD-044).
  Future<int> adoptGuestReminders(String userId);

  /// Removes this account's reminders from the device at sign-out (PD-017,
  /// ADR-031). Returns the notification ids whose alarms must be cancelled.
  Future<List<int>> purgeAccount(String userId);
}

final class DriftReminderRepository implements ReminderRepository {
  DriftReminderRepository(
    this._db, {
    required Clock clock,
    required MemoryRepository memories,
    Uuid uuid = const Uuid(),
  }) : _clock = clock,
       _memories = memories,
       _uuid = uuid;

  final TindakDatabase _db;
  final Clock _clock;
  final MemoryRepository _memories;
  final Uuid _uuid;

  static const AppLogger _log = AppLogger('reminders');

  static const String _scheduled = 'scheduled';
  static const String _fired = 'fired';
  static const String _cancelled = 'cancelled';

  @override
  Future<Result<ReminderRecord>> create({
    required String memoryId,
    required LocalDateTime at,
  }) async {
    final refusal = _refuseIfNotFuture(at);
    if (refusal != null) return Result<ReminderRecord>.err(refusal);

    try {
      return await _db.transaction(() async {
        final memory = await (_db.select(
          _db.memories,
        )..where((m) => m.id.equals(memoryId) & m.deletedAt.isNull()))
            .getSingleOrNull();
        if (memory == null) {
          return const Result<ReminderRecord>.err(NotFoundFailure());
        }
        if (await activeFor(memoryId) != null) {
          // One active reminder per memory (B-7). Replace it instead.
          return const Result<ReminderRecord>.err(
            ReminderAlreadyExistsFailure(),
          );
        }
        return Result<ReminderRecord>.ok(
          await _insert(memoryId: memoryId, owner: memory.ownerUserId, at: at),
        );
      });
    } catch (error, stackTrace) {
      return _failure<ReminderRecord>('create', error, stackTrace);
    }
  }

  @override
  Future<Result<ReminderRecord>> createWithMemory({
    required IncomingText incoming,
    required UnderstandingResult understanding,
    required LocalDateTime at,
  }) async {
    final refusal = _refuseIfNotFuture(at);
    if (refusal != null) return Result<ReminderRecord>.err(refusal);

    try {
      return await _db.transaction(() async {
        // Pressing Tetapkan is itself the decision to keep the item, so the
        // memory is saved here rather than asked about again (PD-003 holds:
        // nothing is saved without a press). Both rows commit together, so a
        // failure leaves neither.
        final saved = await _memories.save(
          incoming: incoming,
          understanding: understanding,
        );
        return switch (saved) {
          Err<String>(:final failure) => Result<ReminderRecord>.err(failure),
          Ok<String>(value: final memoryId) => Result<ReminderRecord>.ok(
            await _insert(memoryId: memoryId, owner: null, at: at),
          ),
        };
      });
    } catch (error, stackTrace) {
      return _failure<ReminderRecord>('create_with_memory', error, stackTrace);
    }
  }

  @override
  Future<Result<ReminderRecord>> replace({
    required String reminderId,
    required LocalDateTime at,
  }) async {
    final refusal = _refuseIfNotFuture(at);
    // Refused before anything is written, so the existing reminder survives a
    // rejected edit (B-7).
    if (refusal != null) return Result<ReminderRecord>.err(refusal);

    try {
      final existing = await _rowOf(reminderId);
      if (existing == null || existing.status != _scheduled) {
        return const Result<ReminderRecord>.err(NotFoundFailure());
      }

      final now = _clock.now().millisecondsSinceEpoch;
      // One statement: the reminder moves to the new time or stays where it
      // was. There is no moment in between with no reminder at all.
      await (_db.update(
        _db.reminders,
      )..where((r) => r.id.equals(reminderId) & r.status.equals(_scheduled)))
          .write(
            RemindersCompanion(
              localDate: Value<String>(at.date),
              localTime: Value<String>(at.time),
              timeZone: Value<String>(_zoneName()),
              remindAt: Value<int>(at.resolve().millisecondsSinceEpoch),
              // The alarm still points at the old time until the reconciler
              // replaces it.
              scheduledAt: const Value<int?>(null),
              updatedAt: Value<int>(now),
            ),
          );

      final updated = await _rowOf(reminderId);
      if (updated == null) {
        return const Result<ReminderRecord>.err(NotFoundFailure());
      }
      return Result<ReminderRecord>.ok(_toRecord(updated)!);
    } catch (error, stackTrace) {
      return _failure<ReminderRecord>('replace', error, stackTrace);
    }
  }

  @override
  Future<Result<void>> cancel(String reminderId) async {
    try {
      final changed =
          await (_db.update(_db.reminders)..where(
                (r) => r.id.equals(reminderId) & r.status.equals(_scheduled),
              ))
              .write(
                RemindersCompanion(
                  status: const Value<String>(_cancelled),
                  updatedAt: Value<int>(_clock.now().millisecondsSinceEpoch),
                ),
              );
      if (changed == 0) return const Result<void>.err(NotFoundFailure());
      return const Result<void>.ok(null);
    } catch (error, stackTrace) {
      return _failure<void>('cancel', error, stackTrace);
    }
  }

  @override
  Future<ReminderRecord?> activeFor(String memoryId) async {
    final row =
        await (_db.select(_db.reminders)..where(
              (r) => r.memoryId.equals(memoryId) & r.status.equals(_scheduled),
            ))
            .getSingleOrNull();
    return row == null ? null : _toRecord(row);
  }

  @override
  Stream<List<ReminderRecord>> watchFor(String memoryId) =>
      (_db.select(_db.reminders)
            ..where((r) => r.memoryId.equals(memoryId))
            ..orderBy(<OrderingTerm Function($RemindersTable)>[
              (r) => OrderingTerm.desc(r.createdAt),
            ]))
          .watch()
          .map(
            (rows) => <ReminderRecord>[
              for (final row in rows)
                if (_toRecord(row) case final ReminderRecord record) record,
            ],
          );

  @override
  Future<List<ReminderRecord>> active() async {
    final rows = await (_db.select(
      _db.reminders,
    )..where((r) => r.status.equals(_scheduled))).get();
    return <ReminderRecord>[
      for (final row in rows)
        if (_toRecord(row) case final ReminderRecord record) record,
    ];
  }

  @override
  Future<void> markFired(String reminderId) async {
    await (_db.update(_db.reminders)..where(
          (r) => r.id.equals(reminderId) & r.status.equals(_scheduled),
        ))
        .write(
          RemindersCompanion(
            status: const Value<String>(_fired),
            updatedAt: Value<int>(_clock.now().millisecondsSinceEpoch),
          ),
        );
  }

  @override
  Future<void> markScheduled(String reminderId, DateTime at) async {
    await (_db.update(_db.reminders)..where((r) => r.id.equals(reminderId)))
        .write(
          RemindersCompanion(
            scheduledAt: Value<int?>(at.millisecondsSinceEpoch),
          ),
        );
  }

  @override
  Future<List<int>> cancelForMemory(String memoryId) async {
    final rows = await (_db.select(_db.reminders)..where(
          (r) => r.memoryId.equals(memoryId) & r.status.equals(_scheduled),
        ))
        .get();
    if (rows.isEmpty) return const <int>[];

    await (_db.update(_db.reminders)..where(
          (r) => r.memoryId.equals(memoryId) & r.status.equals(_scheduled),
        ))
        .write(
          RemindersCompanion(
            status: const Value<String>(_cancelled),
            updatedAt: Value<int>(_clock.now().millisecondsSinceEpoch),
          ),
        );
    return rows.map((r) => r.notificationId).toList();
  }

  @override
  Future<int> adoptGuestReminders(String userId) => _db.customUpdate(
    '''
    UPDATE reminders SET owner_user_id = ?1, updated_at = ?2
    WHERE owner_user_id IS NULL
      AND memory_id IN (SELECT id FROM memories WHERE owner_user_id = ?1)
    ''',
    variables: <Variable<Object>>[
      Variable<String>(userId),
      Variable<int>(_clock.now().millisecondsSinceEpoch),
    ],
    updates: <TableInfo<Table, dynamic>>{_db.reminders},
    updateKind: UpdateKind.update,
  );

  @override
  Future<List<int>> purgeAccount(String userId) async {
    final rows = await (_db.select(
      _db.reminders,
    )..where((r) => r.ownerUserId.equals(userId))).get();
    await (_db.delete(
      _db.reminders,
    )..where((r) => r.ownerUserId.equals(userId))).go();
    return rows
        .where((r) => r.status == _scheduled)
        .map((r) => r.notificationId)
        .toList();
  }

  /// B-3, checked at commit rather than only in the picker. Equal to now is
  /// also refused: a reminder for this instant cannot alert in time.
  Failure? _refuseIfNotFuture(LocalDateTime at) {
    if (!at.isRealMoment) return const ReminderTimeInPastFailure();
    if (!at.resolve().isAfter(_clock.now())) {
      return const ReminderTimeInPastFailure();
    }
    return null;
  }

  Future<ReminderRecord> _insert({
    required String memoryId,
    required String? owner,
    required LocalDateTime at,
  }) async {
    final now = _clock.now().millisecondsSinceEpoch;
    final id = _uuid.v4();

    final notificationId = await _db
        .into(_db.reminders)
        .insert(
          RemindersCompanion.insert(
            id: id,
            memoryId: memoryId,
            ownerUserId: Value<String?>(owner),
            localDate: at.date,
            localTime: at.time,
            timeZone: _zoneName(),
            remindAt: at.resolve().millisecondsSinceEpoch,
            status: _scheduled,
            createdAt: now,
            updatedAt: now,
          ),
        );

    return ReminderRecord(
      id: id,
      memoryId: memoryId,
      at: at,
      status: ReminderStatus.scheduled,
      notificationId: notificationId,
      remindAt: at.resolve(),
      ownerUserId: owner,
    );
  }

  Future<ReminderRow?> _rowOf(String id) =>
      (_db.select(_db.reminders)..where((r) => r.id.equals(id)))
          .getSingleOrNull();

  /// Diagnostics only. Scheduling always recomputes from the chosen local time.
  String _zoneName() => _clock.now().timeZoneName;

  static ReminderRecord? _toRecord(ReminderRow row) {
    final at = LocalDateTime.parse(row.localDate, row.localTime);
    final status = switch (row.status) {
      _scheduled => ReminderStatus.scheduled,
      _fired => ReminderStatus.fired,
      _cancelled => ReminderStatus.cancelled,
      _ => null,
    };
    if (at == null || status == null) {
      _log.failure('reminder_row_unreadable');
      return null;
    }

    return ReminderRecord(
      id: row.id,
      memoryId: row.memoryId,
      at: at,
      status: status,
      notificationId: row.notificationId,
      remindAt: DateTime.fromMillisecondsSinceEpoch(row.remindAt),
      ownerUserId: row.ownerUserId,
      scheduledAt: row.scheduledAt == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(row.scheduledAt!),
    );
  }

  /// Logs the operation and the error's type only. A SQLite error can quote
  /// the statement it failed on (docs/12_SECURITY.md section 11).
  static Result<T> _failure<T>(
    String operation,
    Object error,
    StackTrace stackTrace,
  ) {
    _log.failure(
      'reminder_${operation}_failed_${error.runtimeType}',
      stackTrace: stackTrace,
    );
    return Result<T>.err(const StorageFailure());
  }
}
