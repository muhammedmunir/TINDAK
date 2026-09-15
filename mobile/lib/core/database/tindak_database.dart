import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';

part 'tindak_database.g.dart';

/// The device database — the source of truth on this phone (ADR-014).
///
/// Local SQLite through Drift (ADR-015). The schema is documented in
/// docs/11_DATABASE.md section 3 and is the first persistent user-data schema
/// in TINDAK, so it is built for M5b now even though M5b has not started:
///
/// - client-generated UUIDv4 ids, so a row keeps its identity when it is later
///   synced and nothing is ever re-keyed;
/// - nullable ownership, so a guest row is structurally different from an
///   account row, and a database constraint stops a guest row claiming to be
///   synced;
/// - a sync status that is always `local_only` in M5a;
/// - `deleted_at` for a future sync tombstone, never shown to the user.
///
/// **No cloud behaviour exists here.** Nothing reads `owner_user_id` other than
/// to keep it null, and nothing ever sets `sync_status` to anything but
/// `local_only` in M5a.
///
/// Stored text is private. Drift's generated row classes print their fields in
/// `toString`, so rows never cross into logging or UI directly: the repository
/// maps them to domain types whose `toString` omits content.
@DriftDatabase(tables: <Type>[Memories, MemoryEntities])
class TindakDatabase extends _$TindakDatabase {
  TindakDatabase(super.executor);

  /// Opens the database file in the app's private support directory.
  ///
  /// That directory is excluded from cloud backup and device transfer by
  /// `allowBackup=false` and the data extraction rules installed at M1
  /// (ADR-021). A guest's memories exist nowhere else.
  factory TindakDatabase.onDevice() => TindakDatabase(
    LazyDatabase(() async {
      final directory = await getApplicationSupportDirectory();
      final file = File('${directory.path}/tindak.sqlite');
      return NativeDatabase.createInBackground(file);
    }),
  );

  /// Longest content a saved Memory may hold, in Unicode code points (PD-039).
  ///
  /// The same number locally and in the cloud schema
  /// (docs/11_DATABASE.md section 2.2), so nothing saved on a device can later
  /// be impossible to sync.
  static const int maxContentLength = 10000;

  /// Schema history. Every change bumps this and adds an explicit step to
  /// [migration]; a step that has run on a real device is never edited
  /// (docs/11_DATABASE.md section 6).
  ///
  /// - 1 — M5a Local Memory.
  /// - 2 — M5b: `memories.server_updated_at`, so the device knows whether the
  ///   server has ever acknowledged a row
  ///   (docs/14_M5B_RECONCILIATION.md section 2.1).
  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      // Only known steps are run. An unknown jump — including a downgrade from
      // a newer build — is refused rather than guessed at, because guessing
      // with a user's only copy of their data is the one thing a migration must
      // never do.
      if (from < 1 || to > 2 || from >= to) {
        throw StateError('No migration path from schema $from to $to');
      }
      if (from < 2) {
        // ADD COLUMN, not a table rebuild: existing rows keep every value and
        // every CHECK, and the new column is NULL — correctly meaning "the
        // server has never seen this row", which is true of every M5a row.
        await m.addColumn(memories, memories.serverUpdatedAt);
      }
    },
    beforeOpen: (details) async {
      // SQLite leaves foreign keys off unless asked. Without this, deleting a
      // memory would orphan its entities and their searchable values.
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}

/// One saved item.
@DataClassName('MemoryRow')
@TableIndex(
  name: 'memories_visible_created_idx',
  columns: {#deletedAt, #createdAt},
)
class Memories extends Table {
  /// Client-generated UUIDv4, assigned at save and never reassigned.
  TextColumn get id => text()();

  /// The user's text exactly as it arrived. Never a normalised
  /// reconstruction; normalised values live on [MemoryEntities].
  TextColumn get content => text()();

  /// `share` or `paste` (PD-033).
  TextColumn get intakeSource => text().named('intake_source')();

  /// The sending package, when Android disclosed it. Never trusted.
  TextColumn get sourceApp => text().named('source_app').nullable()();

  /// Epoch milliseconds, UTC.
  IntColumn get createdAt => integer().named('created_at')();
  IntColumn get updatedAt => integer().named('updated_at')();

  /// Reserved for a future sync tombstone (PD-021). M5a deletes rows outright
  /// and never sets this; every read ignores rows where it is set.
  IntColumn get deletedAt => integer().named('deleted_at').nullable()();

  /// Null means guest-owned. Set only by M5b sign-in and migration.
  TextColumn get ownerUserId => text().named('owner_user_id').nullable()();

  /// `local_only` in M5a, always.
  TextColumn get syncStatus => text().named('sync_status')();

  /// The server's `updated_at` from the last successful push or pull, epoch ms
  /// UTC. NULL means the server has never acknowledged this row — so deleting
  /// it can be a local hard delete, with no tombstone to send (schema v2).
  IntColumn get serverUpdatedAt =>
      integer().named('server_updated_at').nullable()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};

  @override
  List<String> get customConstraints => <String>[
    "CHECK (sync_status IN ('local_only', 'pending', 'synced'))",
    "CHECK (intake_source IN ('share', 'paste'))",
    'CHECK (length(id) = 36)',
    // A guest row can never claim to be synced. Only an account-owned row
    // can leave the device (PD-016).
    "CHECK (owner_user_id IS NOT NULL OR sync_status = 'local_only')",
    'CHECK (updated_at >= created_at)',
    // PD-039: the persisted Memory limit, enforced by the database itself so
    // no code path — including one that bypasses the repository — can store
    // more. SQLite's length() counts code points, as Postgres's char_length()
    // does, so this matches the cloud constraint exactly.
    'CHECK (length(content) <= ${TindakDatabase.maxContentLength})',
  ];
}

/// Something TINDAK understood in a saved item.
///
/// Derived from the memory's content, so it is replaced wholesale with its
/// memory and never synced on its own (docs/11_DATABASE.md section 2.3).
@DataClassName('MemoryEntityRow')
@TableIndex(name: 'memory_entities_memory_idx', columns: {#memoryId})
@TableIndex(name: 'memory_entities_search_idx', columns: {#searchValue})
class MemoryEntities extends Table {
  TextColumn get id => text()();

  TextColumn get memoryId => text()
      .named('memory_id')
      .references(Memories, #id, onDelete: KeyAction.cascade)();

  /// Stored as text, not constrained to today's types, so M6 can add money
  /// and date without rebuilding this table. Unknown values are skipped on
  /// read rather than trusted.
  TextColumn get type => text()();

  /// The matched characters from the normalised text.
  TextColumn get rawValue => text().named('raw_value')();

  /// Canonical value: E.164 phone, lowercased-host URL.
  TextColumn get normalizedValue => text().named('normalized_value')();

  /// Lowercased forms a person would type when searching, e.g. both
  /// `0123456789` and `60123456789` for a phone. Local-only and derived.
  TextColumn get searchValue => text().named('search_value')();

  RealColumn get confidence => real()();
  IntColumn get startOffset => integer().named('start_offset')();
  IntColumn get endOffset => integer().named('end_offset')();
  IntColumn get createdAt => integer().named('created_at')();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};

  @override
  List<String> get customConstraints => <String>[
    'CHECK (confidence >= 0 AND confidence <= 1)',
    'CHECK (start_offset >= 0 AND end_offset > start_offset)',
  ];
}
