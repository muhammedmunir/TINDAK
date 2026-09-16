import 'package:tindak/features/understanding/model/detected_entity.dart';

/// What a user can explicitly do with a detected entity.
///
/// M4 shipped the first three and M6b adds two. Save is M5a, Security Check is
/// M8, Try AI is M9 — each arrives with its own milestone and gate.
enum ActionKind {
  /// Opens the dialer pre-filled. Does **not** place the call; the user still
  /// presses call in the dialer, and TINDAK needs no CALL_PHONE permission.
  call,

  /// Opens a chat with the number in WhatsApp.
  whatsapp,

  /// Opens an http or https link in the user's browser.
  openUrl,

  /// Puts an amount on the clipboard, in its canonical form (M6b).
  copy,

  /// A date's reminder. **M6 schedules nothing**: the reminder flow, the time
  /// the user picks and the notification permission all arrive with M7. Here it
  /// says so plainly rather than pretending a reminder was created.
  remind,
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
