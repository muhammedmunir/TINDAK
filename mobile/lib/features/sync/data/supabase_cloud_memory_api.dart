import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:tindak/features/sync/data/cloud_memory_api.dart';

/// [CloudMemoryApi] over Supabase PostgREST.
///
/// One of the only files in TINDAK that may import Supabase
/// (test/features/understanding/layer_purity_test.dart). Authorisation is RLS:
/// nothing here filters by user id for security, and the user id passed in is
/// used only to refuse a call when the session has changed hands.
///
/// Errors are translated into three exceptions that carry no server message,
/// because a database error can quote the row it rejected.
final class SupabaseCloudMemoryApi implements CloudMemoryApi {
  SupabaseCloudMemoryApi(this._client);

  final SupabaseClient _client;

  static const Duration _timeout = Duration(seconds: 20);

  static const String _columns =
      'id,content,intake_source,source_app,created_at,updated_at,deleted_at,'
      'memory_entities(id,type,raw_value,normalized_value,confidence,'
      'start_offset,end_offset)';

  @override
  Future<DateTime> push(String userId, CloudMemory memory) => _guard(userId, () async {
    final result = await _client
        .rpc<dynamic>(
          'push_memory',
          params: <String, dynamic>{
            'p_id': memory.id,
            'p_content': memory.content,
            'p_intake_source': memory.intakeSource,
            'p_source_app': memory.sourceApp,
            'p_created_at': memory.createdAt.toUtc().toIso8601String(),
            'p_entities': <Map<String, dynamic>>[
              for (final e in memory.entities)
                <String, dynamic>{
                  'id': e.id,
                  'type': e.type,
                  'raw_value': e.rawValue,
                  'normalized_value': e.normalizedValue,
                  'confidence': e.confidence,
                  'start_offset': e.start,
                  'end_offset': e.end,
                },
            ],
          },
        )
        .timeout(_timeout);
    if (result is! String) throw const CloudRejectedException('push_response');
    return DateTime.parse(result).toUtc();
  });

  @override
  Future<void> tombstone(String userId, String memoryId, DateTime deletedAt) =>
      _guard(userId, () async {
        // Only a live row is updated. An existing tombstone is left alone — the
        // database refuses to change one — and a row the server never had
        // matches nothing. Both mean the deletion is already true in the cloud.
        await _client
            .from('memories')
            .update(<String, dynamic>{
              'deleted_at': deletedAt.toUtc().toIso8601String(),
            })
            .eq('id', memoryId)
            .isFilter('deleted_at', null)
            .timeout(_timeout);
      });

  @override
  Future<List<CloudMemory>> pull(
    String userId, {
    required int limit,
    DateTime? since,
    SyncCursor? after,
  }) => _guard(userId, () async {
    var query = _client.from('memories').select(_columns);
    if (after != null) {
      final at = _quoted(after.updatedAt.toUtc().toIso8601String());
      query = query.or(
        'updated_at.gt.$at,and(updated_at.eq.$at,id.gt.${after.id})',
      );
    } else if (since != null) {
      query = query.gte('updated_at', since.toUtc().toIso8601String());
    }
    final rows = await query
        .order('updated_at', ascending: true)
        .order('id', ascending: true)
        .limit(limit)
        .timeout(_timeout);
    return <CloudMemory>[for (final row in rows) _memoryFrom(row)];
  });

  /// Double quotes a PostgREST filter value, which is needed for anything
  /// containing `.`, `:` or `,` — every timestamp.
  static String _quoted(String value) => '"$value"';

  static CloudMemory _memoryFrom(Map<String, dynamic> row) {
    try {
      final entities = row['memory_entities'];
      return CloudMemory(
        id: row['id'] as String,
        content: row['content'] as String,
        intakeSource: row['intake_source'] as String,
        sourceApp: row['source_app'] as String?,
        createdAt: DateTime.parse(row['created_at'] as String).toUtc(),
        updatedAt: DateTime.parse(row['updated_at'] as String).toUtc(),
        deletedAt: row['deleted_at'] == null
            ? null
            : DateTime.parse(row['deleted_at'] as String).toUtc(),
        entities: <CloudEntity>[
          if (entities is List)
            for (final e in entities.cast<Map<String, dynamic>>())
              CloudEntity(
                id: e['id'] as String,
                type: e['type'] as String,
                rawValue: e['raw_value'] as String,
                normalizedValue: e['normalized_value'] as String,
                confidence: (e['confidence'] as num).toDouble(),
                start: e['start_offset'] as int,
                end: e['end_offset'] as int,
              ),
        ],
      );
    } on Object {
      throw const CloudRejectedException('pull_malformed_row');
    }
  }

  /// Refuses to act for an account that no longer holds the session, and maps
  /// every error to one that is safe to log.
  Future<T> _guard<T>(String userId, Future<T> Function() call) async {
    if (_client.auth.currentUser?.id != userId) {
      throw const CloudSessionException();
    }
    try {
      return await call();
    } on CloudRejectedException {
      rethrow;
    } on PostgrestException catch (e) {
      final code = e.code ?? '';
      // PGRST301..303: the JWT is missing, expired or invalid.
      if (code.startsWith('PGRST30')) throw const CloudSessionException();
      // No code, or an HTTP status: a gateway or outage, not a refusal.
      if (code.isEmpty || RegExp(r'^[5]\d\d$').hasMatch(code)) {
        throw const CloudUnavailableException();
      }
      throw CloudRejectedException(code);
    } on AuthRetryableFetchException {
      throw const CloudUnavailableException();
    } on AuthException {
      throw const CloudSessionException();
    } on Object {
      // SocketException, ClientException, TimeoutException, TLS failures. An
      // error nobody anticipated is also retried later rather than dropped:
      // nothing is lost by treating it as "not reached".
      throw const CloudUnavailableException();
    }
  }
}
