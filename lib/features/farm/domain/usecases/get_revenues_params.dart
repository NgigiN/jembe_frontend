import 'package:equatable/equatable.dart';

class GetRevenuesParams extends Equatable {
  final String? source;
  final DateTime? startDate;
  final DateTime? endDate;

  const GetRevenuesParams({
    this.source,
    this.startDate,
    this.endDate,
  });

  @override
  List<Object?> get props => [source, startDate, endDate];
}


