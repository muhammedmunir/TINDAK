/// Where a reminder is in its life.
enum ReminderStatus {
  /// Active: it is meant to alert, and it holds the memory's single active
  /// slot (B-7).
  scheduled,

  /// It has alerted. Kept as history so a memory never looks as though the
  /// reminder was never set (B-4); it holds no slot, so a new one can be made.
  fired,

  /// The user cancelled it. History, like [fired].
  cancelled,
}

/// A date and a time of day as the user chose them, with no time zone.
///
/// **This is the authoritative form** (B-2). "9:00 on 25 September" means 9:00
/// wherever the user happens to be, so the instant is recomputed from this
/// rather than the other way round.
final class LocalDateTime {
  const LocalDateTime({
    required this.year,
    required this.month,
    required this.day,
    required this.hour,
    required this.minute,
  });

  factory LocalDateTime.from(DateTime local) => LocalDateTime(
    year: local.year,
    month: local.month,
    day: local.day,
    hour: local.hour,
    minute: local.minute,
  );

  /// Reads the stored pair, `YYYY-MM-DD` and `HH:MM`. Returns null for
  /// anything else rather than guessing.
  static LocalDateTime? parse(String date, String time) {
    final d = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(date);
    final t = RegExp(r'^(\d{2}):(\d{2})$').firstMatch(time);
    if (d == null || t == null) return null;

    final value = LocalDateTime(
      year: int.parse(d.group(1)!),
      month: int.parse(d.group(2)!),
      day: int.parse(d.group(3)!),
      hour: int.parse(t.group(1)!),
      minute: int.parse(t.group(2)!),
    );
    return value.isRealMoment ? value : null;
  }

  final int year;
  final int month;
  final int day;
  final int hour;
  final int minute;

  /// False for a date the calendar does not have, or an impossible clock time.
  bool get isRealMoment {
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return false;
    final built = DateTime(year, month, day, hour, minute);
    return built.year == year &&
        built.month == month &&
        built.day == day &&
        built.hour == hour &&
        built.minute == minute;
  }

  String get date =>
      '${year.toString().padLeft(4, '0')}-'
      '${month.toString().padLeft(2, '0')}-'
      '${day.toString().padLeft(2, '0')}';

  String get time =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  /// The instant this means **on this device, now**. Recomputed rather than
  /// stored, so moving time zone moves the alarm with the clock (B-2).
  DateTime resolve() => DateTime(year, month, day, hour, minute);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LocalDateTime && date == other.date && time == other.time;

  @override
  int get hashCode => Object.hash(date, time);

  @override
  String toString() => 'LocalDateTime($date $time)';
}

/// One reminder, as the rest of the app sees it.
final class ReminderRecord {
  const ReminderRecord({
    required this.id,
    required this.memoryId,
    required this.at,
    required this.status,
    required this.notificationId,
    required this.remindAt,
    this.ownerUserId,
    this.scheduledAt,
  });

  final String id;
  final String memoryId;

  /// What the user chose (B-2).
  final LocalDateTime at;

  final ReminderStatus status;

  /// The Android id this reminder owns. Device-local.
  final int notificationId;

  /// The resolved instant as last stored, local time.
  final DateTime remindAt;

  /// Null for a guest's reminder.
  final String? ownerUserId;

  /// What the device scheduler was last told, if anything.
  final DateTime? scheduledAt;

  bool get isActive => status == ReminderStatus.scheduled;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReminderRecord && id == other.id && status == other.status;

  @override
  int get hashCode => Object.hash(id, status);

  /// Carries no memory content, and none is printed.
  @override
  String toString() =>
      'ReminderRecord(id: $id, status: ${status.name}, at: ${at.date})';
}
