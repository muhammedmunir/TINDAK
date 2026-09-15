import 'dart:ffi';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:sqlite3/open.dart';
import 'package:tindak/core/database/tindak_database.dart';

var _configured = false;

/// Points the `sqlite3` package at a SQLite library on the test host.
///
/// On a device `sqlite3_flutter_libs` bundles SQLite. A unit test runs on the
/// developer's machine instead, where no bundled copy exists. Windows 10 and
/// later ship `winsqlite3.dll`, so tests use that unless a standalone
/// `sqlite3.dll` is on the path. Linux and macOS find the system library on
/// their own.
void configureSqliteForTests() {
  if (_configured) return;
  _configured = true;

  if (Platform.isWindows) {
    open.overrideFor(OperatingSystem.windows, () {
      try {
        return DynamicLibrary.open('sqlite3.dll');
      } on ArgumentError {
        return DynamicLibrary.open('winsqlite3.dll');
      }
    });
  }
}

/// A fresh in-memory database with the real production schema.
///
/// Each call is isolated. Closing it is the caller's job; tests do it in
/// `addTearDown`.
TindakDatabase openTestDatabase() {
  configureSqliteForTests();
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  // Streams close synchronously so a widget test does not end with Drift's
  // stream-cleanup timer still pending.
  return TindakDatabase(
    DatabaseConnection(
      NativeDatabase.memory(),
      closeStreamsSynchronously: true,
    ),
  );
}
