import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../../domain/entities/season.dart';
import '../../domain/usecases/get_seasons.dart';
import '../../domain/usecases/add_season.dart';
import '../bloc/season_event.dart';
import '../bloc/season_state.dart';

class SeasonBloc extends Bloc<SeasonEvent, SeasonState> {
  final GetSeasons getSeasons;
  final AddSeason addSeason;

  SeasonBloc({required this.getSeasons, required this.addSeason})
    : super(SeasonInitial()) {
    on<GetSeasonsEvent>((event, emit) async {
      print('GetSeasonsEvent triggered');
      emit(SeasonLoading());

      try {
        final result = await getSeasons(NoParams());
        result.fold(
          (failure) {
            print('GetSeasons failed: $failure');
            String message = 'Failed to load seasons';
            if (failure is ServerFailure && failure.errorMessage != null) {
              message = failure.errorMessage!;
            }
            emit(SeasonError(message));
          },
          (seasons) {
            print('GetSeasons success: ${seasons.length} seasons loaded');
            emit(SeasonLoaded(seasons: seasons));
          },
        );
      } catch (e) {
        print('GetSeasons exception: $e');
        emit(SeasonError('Unexpected error: $e'));
      }
    });

    on<AddSeasonEvent>((event, emit) async {
      // Store current seasons before emitting loading state
      final currentSeasons = state is SeasonLoaded
          ? (state as SeasonLoaded).seasons
          : <Season>[];

      emit(SeasonLoading());
      final result = await addSeason(AddSeasonParams(season: event.season));
      result.fold(
        (failure) {
          String message = 'Failed to add season';
          if (failure is ServerFailure && failure.errorMessage != null) {
            message = failure.errorMessage!;
          }
          emit(SeasonError(message));
        },
        (season) {
          final updatedSeasons = List<Season>.from(currentSeasons)..add(season);
          emit(SeasonLoaded(seasons: updatedSeasons));
        },
      );
    });
  }
}
