import 'dart:async';

import 'package:tindak/features/auth/data/auth_gateway.dart';
import 'package:tindak/features/sync/data/cloud_memory_api.dart';

/// An in-memory stand-in for the Supabase project, with the same rules the
/// migrations enforce: server-set `updated_at`, per-user visibility, immutable
/// memories, one-way tombstones, and memory + entities stored together.
final class FakeCloud implements CloudMemoryApi {
  FakeCloud({DateTime? start})
    : _now = start ?? DateTime.utc(2026, 9, 15, 9);

  DateTime _now;
  final Map<String, ServerRow> rows = <String, ServerRow>{};

  /// Who holds the session. Calls for any other user fail as a lost session.
  String? sessionUser;

  bool offline = false;

  /// Ids the server refuses, as if a constraint failed.
  final Set<String> rejectIds = <String>{};

  /// Runs inside a push, after the server stored the row but before the reply
  /// arrives — the moment a user action can race a sync.
  Future<void> Function(CloudMemory memory)? duringPush;

  final List<String> pushed = <String>[];
  final List<String> tombstoned = <String>[];
  int pulledRows = 0;
  int pullRequests = 0;

  DateTime _tick() => _now = _now.add(const Duration(milliseconds: 1));

  /// Moves server time on, as real time passes between writes.
  void advance(Duration duration) => _now = _now.add(duration);

  /// Another device, or the server itself, writing directly.
  void insertDirect(String userId, CloudMemory memory) {
    rows[memory.id] = ServerRow(userId, memory, _tick(), null);
  }

  void tombstoneDirect(String id) {
    final row = rows[id]!;
    rows[id] = ServerRow(row.userId, row.memory, _tick(), _now);
  }

  void _check(String userId) {
    if (offline) throw const CloudUnavailableException();
    if (sessionUser != userId) throw const CloudSessionException();
  }

  @override
  Future<DateTime> push(String userId, CloudMemory memory) async {
    _check(userId);
    if (rejectIds.contains(memory.id)) {
      throw const CloudRejectedException('23514');
    }
    final existing = rows[memory.id];
    if (existing != null) {
      if (existing.userId != userId) {
        throw const CloudRejectedException('42501');
      }
      return existing.updatedAt;
    }
    if (memory.deletedAt != null ||
        memory.content.runes.length > 10000) {
      throw const CloudRejectedException('23514');
    }
    rows[memory.id] = ServerRow(userId, memory, _tick(), null);
    pushed.add(memory.id);
    await duringPush?.call(memory);
    if (offline) throw const CloudUnavailableException();
    return rows[memory.id]!.updatedAt;
  }

  @override
  Future<void> tombstone(
    String userId,
    String memoryId,
    DateTime deletedAt,
  ) async {
    _check(userId);
    tombstoned.add(memoryId);
    final row = rows[memoryId];
    if (row == null || row.userId != userId || row.deletedAt != null) return;
    rows[memoryId] = ServerRow(userId, row.memory, _tick(), deletedAt);
  }

  @override
  Future<List<CloudMemory>> pull(
    String userId, {
    required int limit,
    DateTime? since,
    SyncCursor? after,
  }) async {
    _check(userId);
    pullRequests++;
    final visible =
        rows.values.where((r) => r.userId == userId).where((r) {
          if (after != null) {
            return r.updatedAt.isAfter(after.updatedAt) ||
                (r.updatedAt == after.updatedAt &&
                    r.memory.id.compareTo(after.id) > 0);
          }
          if (since != null) return !r.updatedAt.isBefore(since);
          return true;
        }).toList()..sort((a, b) {
          final byTime = a.updatedAt.compareTo(b.updatedAt);
          return byTime != 0 ? byTime : a.memory.id.compareTo(b.memory.id);
        });
    final page = visible.take(limit).map((r) => r.asCloud()).toList();
    pulledRows += page.length;
    return page;
  }

  bool isDeleted(String id) => rows[id]?.deletedAt != null;
}

final class ServerRow {
  ServerRow(this.userId, this.memory, this.updatedAt, this.deletedAt);

  final String userId;
  final CloudMemory memory;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  CloudMemory asCloud() => CloudMemory(
    id: memory.id,
    content: memory.content,
    intakeSource: memory.intakeSource,
    sourceApp: memory.sourceApp,
    createdAt: memory.createdAt,
    updatedAt: updatedAt,
    deletedAt: deletedAt,
    entities: memory.entities,
  );
}

/// Sign-in with no server. [sessionEnded] records the order of events so a
/// test can prove the purge happened first.
final class FakeAuthGateway implements AuthGateway {
  FakeAuthGateway({Account? account, this.cloud}) : _account = account {
    cloud?.sessionUser = account?.id;
  }

  final FakeCloud? cloud;
  Account? _account;
  bool sessionEnded = false;
  final List<String> sentCodes = <String>[];
  AuthOutcome nextOutcome = AuthOutcome.success;

  final StreamController<Account?> _changes =
      StreamController<Account?>.broadcast(sync: true);

  @override
  bool get isAvailable => true;

  @override
  Account? get currentAccount => _account;

  @override
  Stream<Account?> get accountChanges => _changes.stream;

  void signInAs(Account? account) {
    _account = account;
    cloud?.sessionUser = account?.id;
    _changes.add(account);
  }

  @override
  Future<AuthOutcome> sendCode(String email) async {
    sentCodes.add(email);
    return nextOutcome;
  }

  @override
  Future<AuthOutcome> verifyCode(String email, String code) async {
    if (nextOutcome == AuthOutcome.success) {
      signInAs(Account(id: 'user-$email', email: email));
    }
    return nextOutcome;
  }

  @override
  Future<void> endSession() async {
    sessionEnded = true;
    signInAs(null);
  }
}
