import 'package:equatable/equatable.dart';
import 'package:farm_tracker/features/farm/domain/entities/infrastructure.dart';

abstract class InfrastructureState extends Equatable {
  const InfrastructureState({this.infrastructures = const []});
  final List<Infrastructure> infrastructures;

  @override
  List<Object?> get props => [infrastructures];
}

class InfrastructureInitial extends InfrastructureState {}

class InfrastructureLoading extends InfrastructureState {
  const InfrastructureLoading({super.infrastructures});
}

class InfrastructureLoaded extends InfrastructureState {
  const InfrastructureLoaded(
    List<Infrastructure> infrastructures, {
    this.successMessage,
    this.hasReachedMax = true,
    this.nextCursor,
  }) : super(infrastructures: infrastructures);
  final String? successMessage;

  /// Online infinite-scroll (P3-02a): `false` only when the last page came
  /// back full (== `kOnlineListPageSize`), i.e. another page may exist.
  /// Defaults to `true` so the offline stream path (and the Add/Update/
  /// Delete handlers, which don't page) never trigger a load-more.
  final bool hasReachedMax;

  /// The server id to page from next (`?cursor=`), i.e. the last item's id.
  /// `null` once [hasReachedMax] or when the list is empty.
  final int? nextCursor;

  @override
  List<Object?> get props =>
      [infrastructures, successMessage, hasReachedMax, nextCursor];
}

class InfrastructureError extends InfrastructureState {
  const InfrastructureError(this.message, {super.infrastructures});
  final String message;

  @override
  List<Object?> get props => [message, infrastructures];
}
