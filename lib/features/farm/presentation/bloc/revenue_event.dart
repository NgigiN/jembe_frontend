import 'package:equatable/equatable.dart';
import 'package:farm_tracker/features/farm/domain/entities/analytics_scope.dart';

abstract class RevenueEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class LoadRevenues extends RevenueEvent {
  LoadRevenues({
    this.scope = const AnalyticsScope.all(),
    this.startDate,
    this.endDate,
  });
  final AnalyticsScope scope;
  final DateTime? startDate;
  final DateTime? endDate;

  @override
  List<Object?> get props => [scope, startDate, endDate];
}

/// Flag-on counterpart to [LoadRevenues]: on first dispatch, subscribes to
/// the repository's reactive, UNFILTERED `watchRevenues()` stream (guarded
/// against a double-subscribe — see `RevenueBloc._watchStarted`) and caches
/// every emission. [scope]/[startDate]/[endDate] seed (and, on a later
/// dispatch, UPDATE) the bloc's in-memory filter — re-dispatching this event
/// after the stream is already live never re-subscribes; it only changes
/// which of the cached revenues get emitted. See `RevenueBloc`'s R1 doc.
/// [seasonIdsOnLand] is needed only for a LAND scope: the page resolves the
/// land's season ids from `SeasonBloc` so the bloc stays dependency-free.
class WatchRevenuesEvent extends RevenueEvent {
  WatchRevenuesEvent({
    this.scope = const AnalyticsScope.all(),
    this.startDate,
    this.endDate,
    this.seasonIdsOnLand = const {},
  });
  final AnalyticsScope scope;
  final DateTime? startDate;
  final DateTime? endDate;
  final Set<String> seasonIdsOnLand;

  @override
  List<Object?> get props => [scope, startDate, endDate, seasonIdsOnLand];
}

/// Flag-OFF (online) only: fetches the NEXT page of revenues using the
/// current `RevenueLoaded.nextCursor` and APPENDS it, re-applying the same
/// [scope]/[startDate]/[endDate] filter the current page was loaded with.
/// Ignored when the loaded state has already reached max or a load-more is in
/// flight. The offline (`watchRevenues`) path never dispatches this.
class LoadMoreRevenuesEvent extends RevenueEvent {
  LoadMoreRevenuesEvent({
    this.scope = const AnalyticsScope.all(),
    this.startDate,
    this.endDate,
  });
  final AnalyticsScope scope;
  final DateTime? startDate;
  final DateTime? endDate;

  @override
  List<Object?> get props => [scope, startDate, endDate];
}

class AddRevenueEvent extends RevenueEvent {
  AddRevenueEvent({
    required this.source,
    required this.sourceId,
    required this.type,
    required this.quantity,
    required this.unitPrice,
    required this.date,
    this.total,
    this.notes,
  });
  final String source;
  final String sourceId;
  final String type;
  final double quantity;
  final double unitPrice;
  final double? total;
  final DateTime date;
  final String? notes;

  @override
  List<Object?> get props => [
    source,
    sourceId,
    type,
    quantity,
    unitPrice,
    total,
    date,
    notes,
  ];
}

class UpdateRevenueEvent extends RevenueEvent {
  UpdateRevenueEvent({
    required this.id,
    required this.source,
    required this.sourceId,
    required this.type,
    required this.quantity,
    required this.unitPrice,
    required this.total,
    required this.date,
    this.notes,
  });
  final String id;
  final String source;
  final String sourceId;
  final String type;
  final double quantity;
  final double unitPrice;
  final double total;
  final DateTime date;
  final String? notes;

  @override
  List<Object?> get props => [
    id,
    source,
    sourceId,
    type,
    quantity,
    unitPrice,
    total,
    date,
    notes,
  ];
}

class DeleteRevenueEvent extends RevenueEvent {
  DeleteRevenueEvent(this.id);
  final String id;

  @override
  List<Object?> get props => [id];
}
