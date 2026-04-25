import 'package:equatable/equatable.dart';

class GetRevenuesParams extends Equatable {
  const GetRevenuesParams({this.source, this.startDate, this.endDate});
  final String? source;
  final DateTime? startDate;
  final DateTime? endDate;

  @override
  List<Object?> get props => [source, startDate, endDate];
}
