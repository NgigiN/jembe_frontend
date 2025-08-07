import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../../domain/entities/crop.dart';
import '../../domain/usecases/get_crops.dart';
import '../../domain/usecases/add_crop.dart';
import '../bloc/crop_event.dart';
import '../bloc/crop_state.dart';

class CropBloc extends Bloc<CropEvent, CropState> {
  final GetCrops getCrops;
  final AddCrop addCrop;

  CropBloc({required this.getCrops, required this.addCrop})
    : super(CropInitial()) {
    on<GetCropsEvent>((event, emit) async {
      emit(CropLoading());
      final result = await getCrops(NoParams());
      result.fold(
        (failure) => emit(CropError('Failed to load crops')),
        (crops) => emit(CropLoaded(crops: crops)),
      );
    });

    on<AddCropEvent>((event, emit) async {
      emit(CropLoading());
      final result = await addCrop(AddCropParams(crop: event.crop));
      result.fold(
        (failure) {
          String message = 'Failed to add crop';
          if (failure is ServerFailure && failure.errorMessage != null) {
            message = failure.errorMessage!;
          }
          emit(CropError(message));
        },
        (crop) {
          final currentState = state;
          if (currentState is CropLoaded) {
            final updatedCrops = List<Crop>.from(currentState.crops)..add(crop);
            emit(CropLoaded(crops: updatedCrops));
          } else {
            emit(CropLoaded(crops: [crop]));
          }
        },
      );
    });
  }
}
