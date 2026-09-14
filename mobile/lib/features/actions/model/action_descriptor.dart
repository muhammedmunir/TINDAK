import 'package:tindak/features/understanding/model/detected_entity.dart';

/// What a user can explicitly do with a detected entity.
///
/// M4 ships these three only. Save is M5a, Reminder is M7, Security Check is
/// M8, Try AI is M9 — each arrives with its own milestone and gate.
enum ActionKind {
  /// Opens the dialer pre-filled. Does **not** place the call; the user still
  /// presses call in the dialer, and TINDAK needs no CALL_PHONE permission.
  call,

  /// Opens a chat with the number in WhatsApp.
  whatsapp,

  /// Opens an http or https link in the user's browser.
  openUrl,
}

/// One action bound to one entity.
///
/// The entity travels with the action so a tap on one row can only ever use
/// that row's value. A multi-entity result cannot route a Call to the wrong
/// number, because there is no shared "current number" to get wrong.
final class ActionDescriptor {
  const ActionDescriptor({required this.kind, required this.entity});

  final ActionKind kind;
  final DetectedEntity entity;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ActionDescriptor && kind == other.kind && entity == other.entity;

  @override
  int get hashCode => Object.hash(kind, entity);

  /// Deliberately excludes the entity's value (docs/12_SECURITY.md section 11).
  @override
  String toString() => 'ActionDescriptor(${kind.name}, ${entity.type.name})';
}
