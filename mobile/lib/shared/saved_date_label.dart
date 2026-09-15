/// When a memory was saved, in the form a Malaysian reader expects.
///
/// `Hari ini, 14:30`, `Semalam, 09:05`, otherwise `14/09/2026, 14:30`. Dates are
/// DD/MM/YYYY (PD-008). No locale package: three cases do not justify one
/// (AI Rule 6).
String savedDateLabel(DateTime saved, {required DateTime today}) {
  final savedDay = DateTime(saved.year, saved.month, saved.day);
  final todayDay = DateTime(today.year, today.month, today.day);
  final time = '${_two(saved.hour)}:${_two(saved.minute)}';

  final daysAgo = todayDay.difference(savedDay).inDays;
  if (daysAgo == 0) return 'Hari ini, $time';
  if (daysAgo == 1) return 'Semalam, $time';
  return '${_two(saved.day)}/${_two(saved.month)}/${saved.year}, $time';
}

String _two(int value) => value.toString().padLeft(2, '0');
