import 'package:tindak/core/database/tindak_database.dart';

/// Remembers that the user agreed, once, to send selected text to an AI
/// service — and **which version of that promise** they agreed to.
///
/// A number rather than a flag, because the disclosure makes a claim about who
/// receives the text and what they may do with it. If that claim changes —
/// a different provider, different terms, a different data-use tier under
/// PD-048 — the old agreement no longer covers the new arrangement, and
/// [requiredVersion] is raised so the user is asked again. A boolean could not
/// express that, and would silently carry consent across a change the user
/// never saw.
///
/// Local to this installation. Not synced, and deliberately **not** cleared on
/// sign-out: it is a standing choice about this phone, and the person holding
/// it has not changed by signing out. Clearing app data or uninstalling clears
/// it, which is the user's own reset.
///
/// Separate from `OnlineCheckDisclosure`. Agreeing to send a link to a
/// reputation service is not agreeing to send a whole message to a model, and
/// neither key implies the other (PD-024).
final class AiDisclosure {
  const AiDisclosure(this._db);

  final TindakDatabase _db;

  /// The version of the disclosure this build shows. Raised whenever the
  /// promise materially changes.
  static const int requiredVersion = 1;

  static const String key = 'ai.disclosure_version_accepted';

  Future<bool> accepted() async => await acceptedVersion() >= requiredVersion;

  /// 0 when the user has never agreed, or agreed to something unreadable.
  Future<int> acceptedVersion() async {
    final row = await (_db.select(
      _db.syncMeta,
    )..where((s) => s.key.equals(key))).getSingleOrNull();
    final value = row?.value;
    if (value == null) return 0;
    return int.tryParse(value) ?? 0;
  }

  /// Recorded only when the user pressed Teruskan. Batal leaves this untouched,
  /// so nothing is sent and the sheet appears again next time.
  Future<void> accept() => _db
      .into(_db.syncMeta)
      .insertOnConflictUpdate(
        SyncMetaCompanion.insert(key: key, value: '$requiredVersion'),
      );

  /// Withdraws the agreement. The next attempt asks again.
  Future<void> withdraw() =>
      (_db.delete(_db.syncMeta)..where((s) => s.key.equals(key))).go();
}
