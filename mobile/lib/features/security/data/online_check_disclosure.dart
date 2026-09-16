import 'package:tindak/core/database/tindak_database.dart';

/// Remembers whether the user has agreed to send links to the online service
/// (C-6).
///
/// Asked once, before the **first** URL ever leaves the device, and never
/// again after that. Stored on the device only: it is a choice about this
/// phone, and it is deliberately **not** the AI consent that M9 will need.
final class OnlineCheckDisclosure {
  const OnlineCheckDisclosure(this._db);

  final TindakDatabase _db;

  static const String _key = 'protect.online_disclosure_accepted';

  Future<bool> accepted() async {
    final row = await (_db.select(
      _db.syncMeta,
    )..where((s) => s.key.equals(_key))).getSingleOrNull();
    return row?.value == 'true';
  }

  /// Recorded only when the user pressed Teruskan. Pressing Batal leaves this
  /// untouched, so nothing is ever sent and the sheet appears again next time.
  Future<void> accept() => _db
      .into(_db.syncMeta)
      .insertOnConflictUpdate(
        SyncMetaCompanion.insert(key: _key, value: 'true'),
      );
}
