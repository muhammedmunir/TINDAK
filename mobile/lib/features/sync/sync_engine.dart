import 'dart:async';

import 'package:tindak/core/clock/clock.dart';
import 'package:tindak/core/logging/app_logger.dart';
import 'package:tindak/features/sync/data/cloud_memory_api.dart';
import 'package:tindak/features/sync/data/sync_store.dart';

/// How a sync run ended.
enum SyncResult {
  /// Every pending change was accepted and every server change applied.
  upToDate,

  /// The cloud could not be reached. Nothing is lost; changes stay pending.
  offline,

  /// The session no longer belongs to this account. Sync stopped before
  /// writing anything under another identity.
  sessionEnded,

  /// The server refused a change, or something unexpected happened. Changes
  /// that were not accepted stay pending.
  failed,
}

/// Local-first sync for one account (docs/10_ARCHITECTURE.md section 8).
///
/// Push first, then pull. Pushing first means a device never pulls a change
/// and then overwrites it with an older local one, and it is what lets
/// sign-out ask "is anything still pending?" after a single run.
///
/// Runs only when asked — after Save or Delete while signed in, after sign-in,
/// on resume, and on request. No background service, no timer.
final class SyncEngine {
  SyncEngine({
    required SyncStore store,
    required CloudMemoryApi api,
    required Clock clock,
    this.pageSize = 200,
  }) : _store = store,
       _api = api,
       _clock = clock;

  final SyncStore _store;
  final CloudMemoryApi _api;
  final Clock _clock;

  /// Server changes fetched per request.
  final int pageSize;

  /// Server tombstones are purged after 90 days (PD-028). A device whose last
  /// pull is older than this could miss a deletion whose tombstone is already
  /// gone, so it pulls everything again. Set inside the purge window, with a
  /// margin, so the reset always happens before a tombstone can disappear.
  static const Duration fullPullAfter = Duration(days: 80);

  /// Read back from before the stored cursor on every pull. A change committed
  /// by a slow transaction can carry a server time slightly earlier than a
  /// change already seen; re-reading applies idempotently.
  static const Duration cursorOverlap = Duration(seconds: 1);

  static const AppLogger _log = AppLogger('sync');

  Future<void> _tail = Future<void>.value();
  Future<SyncResult>? _queued;
  String? _queuedFor;

  /// Syncs [userId]. Runs never overlap. A request made while a run is in
  /// progress is served by exactly one more run afterwards, so a change made
  /// mid-sync is never left behind and a burst of requests is not a burst of
  /// runs.
  Future<SyncResult> sync(String userId) {
    final queued = _queued;
    if (queued != null && _queuedFor == userId) return queued;

    final completer = Completer<SyncResult>();
    _queued = completer.future;
    _queuedFor = userId;
    _tail = _tail.then((_) async {
      if (identical(_queued, completer.future)) {
        _queued = null;
        _queuedFor = null;
      }
      completer.complete(await _run(userId));
    });
    return completer.future;
  }

  Future<SyncResult> _run(String userId) async {
    _log.event('sync_started');
    try {
      final pushRejected = await _push(userId);
      await _pull(userId);
      _log.event('sync_finished');
      return pushRejected ? SyncResult.failed : SyncResult.upToDate;
    } on CloudUnavailableException {
      _log.event('sync_offline');
      return SyncResult.offline;
    } on CloudSessionException {
      _log.failure('sync_session_ended');
      return SyncResult.sessionEnded;
    } on CloudRejectedException catch (e) {
      _log.failure('sync_rejected_${e.code}');
      return SyncResult.failed;
    } catch (error, stackTrace) {
      _log.failure(
        'sync_failed_${error.runtimeType}',
        stackTrace: stackTrace,
      );
      return SyncResult.failed;
    }
  }

  /// Returns true when the server refused at least one change. A refused change
  /// stays pending and does not block the others behind it.
  Future<bool> _push(String userId) async {
    var rejected = false;
    for (final change in await _store.pendingChanges(userId)) {
      try {
        final deletedAt = change.deletedAt;
        if (deletedAt != null) {
          // Content is never uploaded for a deleted memory. If the server
          // never had it, the tombstone matches nothing and still succeeds.
          await _api.tombstone(userId, change.id, deletedAt);
          await _store.removeTombstone(userId, change.id);
        } else {
          final serverTime = await _api.push(userId, change);
          await _store.acknowledgePush(userId, change.id, serverTime);
        }
      } on CloudRejectedException catch (e) {
        _log.failure('sync_push_rejected_${e.code}');
        rejected = true;
      }
    }
    return rejected;
  }

  Future<void> _pull(String userId) async {
    final lastPull = await _store.lastPullAt(userId);
    if (lastPull != null &&
        _clock.now().toUtc().difference(lastPull) > fullPullAfter) {
      _log.event('sync_full_pull');
      await _store.resetForFullPull(userId);
    }

    final stored = await _store.cursor(userId);
    final since = stored?.updatedAt.subtract(cursorOverlap);
    SyncCursor? after;

    while (true) {
      final page = await _api.pull(
        userId,
        limit: pageSize,
        since: after == null ? since : null,
        after: after,
      );
      await _store.applyPulled(userId, page);
      if (page.isEmpty) break;

      final last = page.last;
      final lastTime = last.updatedAt;
      if (lastTime == null) break;
      after = SyncCursor(lastTime, last.id);
      // Never moves backwards: a page made only of overlap re-reads must not
      // rewind the stored position.
      if (stored == null || !lastTime.isBefore(stored.updatedAt)) {
        await _store.saveCursor(userId, after);
      }
      if (page.length < pageSize) break;
    }

    await _store.saveLastPullAt(userId, _clock.now().toUtc());
  }
}
