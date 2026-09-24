/// Date and time strings the console writes (DESIGN_SPEC §7: plain,
/// concrete, no year where the context already implies it).
library;

const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

const _weekdays = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

/// "23 Sep" — the table Date cell.
String formatDayMonth(DateTime date) =>
    '${date.day} ${_months[date.month - 1]}';

/// "Wednesday 23 September" — the page subtitle.
String formatLongDate(DateTime date) {
  const long = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  return '${_weekdays[date.weekday - 1]} ${date.day} ${long[date.month - 1]}';
}

/// "14:05" — the Feed's Time column. 24-hour, because that is how the
/// rest of the app writes times.
String formatTime(DateTime date) {
  final hour = date.hour.toString().padLeft(2, '0');
  final minute = date.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

/// The Feed's day-group heading: "Today · 23 Sep", "Yesterday · 22 Sep",
/// or "Earlier · 18 Sep" (DESIGN_SPEC §3).
///
/// [now] is a parameter rather than a call to [DateTime.now] so the
/// grouping is testable and so one page render can't straddle midnight.
String dayGroupLabel(DateTime date, DateTime now) {
  final day = DateTime(date.year, date.month, date.day);
  final today = DateTime(now.year, now.month, now.day);
  final difference = today.difference(day).inDays;
  // Today and Yesterday name a single day, so they carry its date. The
  // wider buckets deliberately do not: appending a date there would split
  // "Earlier this week" into one heading per day, which is the opposite of
  // grouping.
  return switch (difference) {
    0 => 'Today · ${formatDayMonth(date)}',
    1 => 'Yesterday · ${formatDayMonth(date)}',
    < 7 => 'Earlier this week',
    < 31 => 'Earlier this month',
    _ => 'Earlier',
  };
}
