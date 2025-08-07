import 'package:equatable/equatable.dart';
import '../../domain/entities/crop.dart';

abstract class CropState extends Equatable {
  final List<Crop> crops;

  const CropState({this.crops = const []});

  @override
  List<Object> get props => [crops];
}

class CropInitial extends CropState {}

class CropLoading extends CropState {
  const CropLoading({super.crops});
}

class CropLoaded extends CropState {
  const CropLoaded({required super.crops});

  @override
  List<Object> get props => [crops];
}

class CropError extends CropState {
  final String message;

  const CropError(this.message, {super.crops});

  @override
  List<Object> get props => [message, crops];
}
