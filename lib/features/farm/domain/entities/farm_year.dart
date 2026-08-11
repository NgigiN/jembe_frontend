import 'package:equatable/equatable.dart';

/// A 12-month reporting window starting on [startMonth] (1-12) of
/// [startYear]. When [startMonth] is 1 this is just the calendar year.
class FarmYear extends Equatable {
  const FarmYear({required this.startYear, required this.startMonth});

  factory FarmYear.containing(DateTime date, int startMonth) {
    final year = date.month >= startMonth ? date.year : date.year - 1;
    return FarmYear(startYear: year, startMonth: startMonth);
  }

  final int startYear;
  final int startMonth;

  DateTime get start => DateTime(startYear, startMonth);
  DateTime get end => DateTime(startYear + 1, startMonth);

  String get label => startMonth == 1
      ? '$startYear'
      : '$startYear/${(startYear + 1) % 100}';

  String get rangeLabel {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    if (startMonth == 1) return '$startYear';
    final endMonthIndex = (startMonth - 2) % 12; // month before start, next year
    return '${months[startMonth - 1]} $startYear – ${months[endMonthIndex]} ${startYear + 1}';
  }

  FarmYear get previous => FarmYear(startYear: startYear - 1, startMonth: startMonth);
  FarmYear get next => FarmYear(startYear: startYear + 1, startMonth: startMonth);

  bool canGoNext(DateTime now) =>
      startYear < FarmYear.containing(now, startMonth).startYear;

  @override
  List<Object?> get props => [startYear, startMonth];
}
