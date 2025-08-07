import 'package:equatable/equatable.dart';
import '../../domain/entities/crop.dart';

abstract class CropEvent extends Equatable {
  @override
  List<Object> get props => [];
}

class GetCropsEvent extends CropEvent {}

class AddCropEvent extends CropEvent {
  final Crop crop;

  AddCropEvent(this.crop);

  @override
  List<Object> get props => [crop];
}
