import 'package:farm_tracker/core/error/failures.dart';
import 'package:farm_tracker/core/logging/app_logger.dart';
import 'package:farm_tracker/core/usecases/usecase.dart';
import 'package:farm_tracker/features/farm/domain/entities/season.dart';
import 'package:farm_tracker/features/farm/domain/usecases/add_season.dart';
import 'package:farm_tracker/features/farm/domain/usecases/delete_season.dart';
import 'package:farm_tracker/features/farm/domain/usecases/get_seasons.dart';
import 'package:farm_tracker/features/farm/domain/usecases/update_season.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/season_event.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/season_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class SeasonBloc extends Bloc<SeasonEvent, SeasonState> {
  SeasonBloc({
    required this.getSeasons,
    required this.addSeason,
    required this.updateSeason,
    required this.deleteSeason,
  }) : super(SeasonInitial()) {
    on<GetSeasonsEvent>((event, emit) async {
      appLogger.debug(LogCategory.farm, 'GetSeasonsEvent triggered');
      emit(const SeasonLoading());

      final result = await getSeasons(NoParams());
      result.fold(
        (failure) {
          appLogger.warning(LogCategory.farm, 'GetSeasons failed: $failure');
          emit(SeasonError(resolveFailureMessage(failure, 'Failed to load seasons')));
        },
        (seasons) {
          appLogger.info(LogCategory.farm, 'Loaded ${seasons.length} seasons');
          emit(SeasonLoaded(seasons: seasons));
        },
      );
    });

    on<AddSeasonEvent>((event, emit) async {
      final currentSeasons = state.seasons;

      emit(SeasonLoading(seasons: currentSeasons));
      final result = await addSeason(AddSeasonParams(season: event.season));
      result.fold(
        (failure) => emit(SeasonError(
          resolveFailureMessage(failure, 'Failed to add season'),
          seasons: currentSeasons,
        )),
        (season) {
          final updatedSeasons = List<Season>.from(currentSeasons)..add(season);
          emit(SeasonLoaded(seasons: updatedSeasons, successMessage: 'Season created'));
        },
      );
    });

    on<UpdateSeasonEvent>((event, emit) async {
      final currentSeasons = state.seasons;

      emit(SeasonLoading(seasons: currentSeasons));
      final result = await updateSeason(
        UpdateSeasonParams(season: event.season),
      );
      result.fold(
        (failure) => emit(SeasonError(
          resolveFailureMessage(failure, 'Failed to update season'),
          seasons: currentSeasons,
        )),
        (updatedSeason) {
          final updatedSeasons = currentSeasons.map((season) {
            return season.id == updatedSeason.id ? updatedSeason : season;
          }).toList();
          emit(SeasonLoaded(seasons: updatedSeasons, successMessage: 'Season updated'));
        },
      );
    });

    on<DeleteSeasonEvent>((event, emit) async {
      final currentSeasons = state.seasons;

      emit(SeasonLoading(seasons: currentSeasons));
      final result = await deleteSeason(DeleteSeasonParams(id: event.id));
      result.fold(
        (failure) => emit(SeasonError(
          resolveFailureMessage(failure, 'Failed to delete season'),
          seasons: currentSeasons,
        )),
        (_) {
          final updatedSeasons = currentSeasons
              .where((season) => season.id != event.id)
              .toList();
          emit(SeasonLoaded(seasons: updatedSeasons, successMessage: 'Season deleted'));
        },
      );
    });
  }
  final GetSeasons getSeasons;
  final AddSeason addSeason;
  final UpdateSeason updateSeason;
  final DeleteSeason deleteSeason;
}
