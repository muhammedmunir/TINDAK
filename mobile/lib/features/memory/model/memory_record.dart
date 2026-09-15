import 'package:tindak/features/intake/incoming_text.dart';
import 'package:tindak/features/understanding/model/detected_entity.dart';

/// Where a saved item lives, as a person would describe it (PD-020).
///
/// The UI shows these in plain words, never as database terms.
enum MemoryStorage {
  /// Guest-owned. Exists only on this phone.
  deviceOnly,

  /// Belongs to the signed-in account; the cloud has not confirmed it yet.
  pendingSync,

  /// Belongs to the signed-in account and is in the cloud.
  synced,
}

/// A saved item, as the rest of the app sees it.
///
/// The UI never touches a database row. Drift's generated rows print every
/// field in `toString`; this type does not print [content], so a saved message
/// cannot escape into a log through a stray interpolation.
final class MemoryRecord {
  MemoryRecord({
    required this.id,
    required this.content,
    required this.source,
    required this.createdAt,
    required this.updatedAt,
    required List<DetectedEntity> entities,
    this.sourceApp,
    this.storage = MemoryStorage.deviceOnly,
  }) : entities = List<DetectedEntity>.unmodifiable(entities);

  /// Client-generated UUIDv4.
  final String id;

  /// The user's text exactly as it arrived.
  final String content;

  final IntakeSource source;
  final String? sourceApp;

  /// Local time.
  final DateTime createdAt;
  final DateTime updatedAt;

  /// What TINDAK understood when the item was saved, in text order.
  ///
  /// Reuses [DetectedEntity], so a saved phone number offers exactly the same
  /// validated actions as a freshly shared one.
  final List<DetectedEntity> entities;

  /// Guest item, or account item waiting for or already in the cloud.
  final MemoryStorage storage;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MemoryRecord && id == other.id && storage == other.storage;

  @override
  int get hashCode => Object.hash(id, storage);

  /// Deliberately excludes [content] and entity values
  /// (docs/12_SECURITY.md section 11).
  @override
  String toString() =>
      'MemoryRecord(id: $id, source: ${source.name}, '
      'storage: ${storage.name}, characters: ${content.length}, '
      'entities: ${entities.length})';
}
