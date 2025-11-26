import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/logging/app_logger.dart';
import '../../../../core/usecases/usecase.dart';
import '../../domain/entities/season.dart';
import '../../domain/usecases/get_seasons.dart';
import '../../domain/usecases/add_season.dart';
import '../../domain/usecases/update_season.dart';
import '../../domain/usecases/delete_season.dart';
import '../bloc/season_event.dart';
import '../bloc/season_state.dart';

class SeasonBloc extends Bloc<SeasonEvent, SeasonState> {
  final GetSeasons getSeasons;
  final AddSeason addSeason;
  final UpdateSeason updateSeason;
  final DeleteSeason deleteSeason;

  SeasonBloc({
    required this.getSeasons,
    required this.addSeason,
    required this.updateSeason,
    required this.deleteSeason,
  })
    : super(SeasonInitial()) {
    on<GetSeasonsEvent>((event, emit) async {
      appLogger.debug(LogCategory.farm, 'GetSeasonsEvent triggered');
      emit(SeasonLoading());

      try {
        final result = await getSeasons(NoParams());
        result.fold(
          (failure) {
            appLogger.warning(LogCategory.farm, 'GetSeasons failed: $failure');
            String message = 'Failed to load seasons';
            if (failure is ServerFailure && failure.errorMessage != null) {
              message = failure.errorMessage!;
            }
            emit(SeasonError(message));
          },
          (seasons) {
            appLogger.info(
              LogCategory.farm,
              'Loaded ${seasons.length} seasons',
            );
            emit(SeasonLoaded(seasons: seasons));
          },
        );
      } catch (e) {
        appLogger.error(LogCategory.farm, 'GetSeasons exception', e);
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

    on<UpdateSeasonEvent>((event, emit) async {
      final currentSeasons = state is SeasonLoaded
          ? (state as SeasonLoaded).seasons
          : <Season>[];

      emit(SeasonLoading());
      final result =
          await updateSeason(UpdateSeasonParams(season: event.season));
      result.fold(
        (failure) {
          String message = 'Failed to update season';
          if (failure is ServerFailure && failure.errorMessage != null) {
            message = failure.errorMessage!;
          }
          emit(SeasonError(message, seasons: currentSeasons));
        },
        (updatedSeason) {
          final updatedSeasons = currentSeasons.map((season) {
            return season.id == updatedSeason.id ? updatedSeason : season;
          }).toList();
          emit(SeasonLoaded(seasons: updatedSeasons));
        },
      );
    });

    on<DeleteSeasonEvent>((event, emit) async {
      final currentSeasons = state is SeasonLoaded
          ? (state as SeasonLoaded).seasons
          : <Season>[];

      emit(SeasonLoading());
      final result = await deleteSeason(DeleteSeasonParams(id: event.id));
      result.fold(
        (failure) {
          String message = 'Failed to delete season';
          if (failure is ServerFailure && failure.errorMessage != null) {
            message = failure.errorMessage!;
          }
          emit(SeasonError(message, seasons: currentSeasons));
        },
        (_) {
          final updatedSeasons =
              currentSeasons.where((season) => season.id != event.id).toList();
          emit(SeasonLoaded(seasons: updatedSeasons));
        },
      );
    });
  }
}
