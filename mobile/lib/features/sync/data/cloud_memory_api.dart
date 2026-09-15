/// The cloud side of Memory sync, as the sync engine sees it.
///
/// Pure Dart: no Supabase import. The only implementation that talks to the
/// network is `SupabaseCloudMemoryApi`; tests use a fake. That keeps the sync
/// rules — the part that can lose data — testable without a server.
abstract interface class CloudMemoryApi {
  /// Sends one memory and its entities together, and returns the server's
  /// `updated_at` for it. Safe to repeat: a memory already in the cloud is left
  /// unchanged and its server time returned.
  Future<DateTime> push(String userId, CloudMemory memory);

  /// Marks a memory deleted in the cloud (PD-021). Succeeds when the memory is
  /// already a tombstone or is not in the cloud at all.
  Future<void> tombstone(String userId, String memoryId, DateTime deletedAt);

  /// Memories changed on the server, oldest change first, at most [limit].
  ///
  /// With [after], only changes strictly after that position. Otherwise, with
  /// [since], changes at or after that time; with neither, everything.
  Future<List<CloudMemory>> pull(
    String userId, {
    required int limit,
    DateTime? since,
    SyncCursor? after,
  });
}

/// A position in the server's change order: `updated_at`, then `id`.
final class SyncCursor {
  const SyncCursor(this.updatedAt, this.id);

  /// Encoded as stored in `sync_meta`. Microsecond precision is kept, because
  /// that is the precision Postgres orders by.
  factory SyncCursor.decode(String value) {
    final separator = value.lastIndexOf('|');
    if (separator <= 0) throw const FormatException('cursor');
    return SyncCursor(
      DateTime.parse(value.substring(0, separator)).toUtc(),
      value.substring(separator + 1),
    );
  }

  final DateTime updatedAt;
  final String id;

  String encode() => '${updatedAt.toUtc().toIso8601String()}|$id';
}

/// A memory as it crosses the sync boundary.
///
/// Carries user content, so — like `MemoryRecord` — its `toString` prints none.
final class CloudMemory {
  const CloudMemory({
    required this.id,
    required this.content,
    required this.intakeSource,
    required this.createdAt,
    required this.entities,
    this.sourceApp,
    this.updatedAt,
    this.deletedAt,
  });

  final String id;
  final String content;
  final String intakeSource;
  final String? sourceApp;
  final DateTime createdAt;

  /// Server time. Null on a memory being pushed; the server sets it.
  final DateTime? updatedAt;
  final DateTime? deletedAt;
  final List<CloudEntity> entities;

  @override
  String toString() =>
      'CloudMemory(id: $id, deleted: ${deletedAt != null}, '
      'entities: ${entities.length})';
}

final class CloudEntity {
  const CloudEntity({
    required this.id,
    required this.type,
    required this.rawValue,
    required this.normalizedValue,
    required this.confidence,
    required this.start,
    required this.end,
  });

  final String id;
  final String type;
  final String rawValue;
  final String normalizedValue;
  final double confidence;
  final int start;
  final int end;

  @override
  String toString() => 'CloudEntity($type, [$start, $end))';
}

/// The request did not complete: no connection, a timeout, a server outage.
/// Nothing is lost; the change stays pending and is retried on the next
/// trigger.
final class CloudUnavailableException implements Exception {
  const CloudUnavailableException();

  @override
  String toString() => 'CloudUnavailableException';
}

/// The server answered and refused. [code] is a stable code, never a message
/// that could quote content.
final class CloudRejectedException implements Exception {
  const CloudRejectedException(this.code);

  final String code;

  @override
  String toString() => 'CloudRejectedException($code)';
}

/// The session no longer belongs to the account being synced — signed out, or
/// expired beyond refresh. Sync stops rather than write under another identity.
final class CloudSessionException implements Exception {
  const CloudSessionException();

  @override
  String toString() => 'CloudSessionException';
}
