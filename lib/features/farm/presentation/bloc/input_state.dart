import 'package:equatable/equatable.dart';
import 'package:farm_tracker/features/farm/domain/entities/input.dart';

abstract class InputState extends Equatable {
  const InputState({this.inputs = const []});
  final List<Input> inputs;

  @override
  List<Object?> get props => [inputs];
}

class InputInitial extends InputState {}

class InputLoading extends InputState {
  const InputLoading({super.inputs});
}

class InputLoaded extends InputState {
  const InputLoaded({
    required super.inputs,
    this.successMessage,
    this.hasReachedMax = true,
    this.nextCursor,
  });
  final String? successMessage;

  /// Online infinite-scroll (P3-02a): `false` only when the last page came
  /// back full (== `kOnlineListPageSize`), i.e. another page may exist.
  /// Defaults to `true` so the offline stream path and the Add/Update/Delete
  /// handlers (which don't page) never trigger a load-more.
  final bool hasReachedMax;

  /// The server id to page from next (`?cursor=`), i.e. the last item's id.
  /// `null` once [hasReachedMax] or when the list is empty.
  final int? nextCursor;

  @override
  List<Object?> get props => [inputs, successMessage, hasReachedMax, nextCursor];
}

class InputError extends InputState {
  const InputError(this.message, {super.inputs});
  final String message;

  @override
  List<Object> get props => [message, inputs];
}
