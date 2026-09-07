import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:farm_tracker/core/error/failures.dart';
import 'package:farm_tracker/features/farm/domain/entities/trash_item.dart';
import 'package:farm_tracker/features/farm/domain/repositories/trash_repository.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/trash_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/trash_event.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/trash_state.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeTrashRepository implements TrashRepository {
  FakeTrashRepository({this.getResult, this.restoreResult});
  Either<Failure, List<TrashItem>>? getResult;
  Either<Failure, void>? restoreResult;

  ({String entity, String id})? lastRestoreCall;

  @override
  Future<Either<Failure, List<TrashItem>>> getTrash() async {
    return getResult ?? const Left(ServerFailure('not stubbed'));
  }

  @override
  Future<Either<Failure, void>> restore({
    required String entity,
    required String id,
  }) async {
    lastRestoreCall = (entity: entity, id: id);
    return restoreResult ?? const Left(ServerFailure('not stubbed'));
  }
}

const _land = TrashItem(entity: 'land', id: '1', label: 'North Field');
const _season = TrashItem(entity: 'season', id: '2', label: 'Long Rains');

void main() {
  group('TrashBloc', () {
    test('starts in TrashInitial', () {
      final bloc = TrashBloc(repository: FakeTrashRepository());
      addTearDown(bloc.close);
      expect(bloc.state, const TrashInitial());
    });

    blocTest<TrashBloc, TrashState>(
      'emits [TrashLoading, TrashLoaded] with items grouped by entity on a '
      'successful LoadTrashEvent',
      build: () => TrashBloc(
        repository: FakeTrashRepository(
          getResult: const Right([_land, _season]),
        ),
      ),
      act: (bloc) => bloc.add(LoadTrashEvent()),
      expect: () => [
        const TrashLoading(),
        const TrashLoaded(items: [_land, _season]),
      ],
      verify: (bloc) {
        final loaded = bloc.state as TrashLoaded;
        expect(loaded.groupedByEntity['land'], [_land]);
        expect(loaded.groupedByEntity['season'], [_season]);
      },
    );

    blocTest<TrashBloc, TrashState>(
      'emits [TrashLoading, TrashError] with a resolved message when the '
      'load fails',
      build: () => TrashBloc(
        repository: FakeTrashRepository(
          getResult: const Left(NetworkFailure()),
        ),
      ),
      act: (bloc) => bloc.add(LoadTrashEvent()),
      expect: () => [
        const TrashLoading(),
        const TrashError(
          'No internet connection. Check your network and try again.',
        ),
      ],
    );

    blocTest<TrashBloc, TrashState>(
      'a successful RestoreItemEvent removes the item and emits a success '
      'message carrying its label',
      build: () => TrashBloc(
        repository: FakeTrashRepository(
          getResult: const Right([_land, _season]),
          restoreResult: const Right(null),
        ),
      ),
      act: (bloc) async {
        bloc.add(LoadTrashEvent());
        await bloc.stream.firstWhere((s) => s is TrashLoaded);
        bloc.add(RestoreItemEvent(entity: 'land', id: '1'));
      },
      skip: 1, // TrashLoading
      expect: () => [
        const TrashLoaded(items: [_land, _season]),
        const TrashLoaded(
          items: [_season],
          successMessage: 'North Field restored',
        ),
      ],
    );

    blocTest<TrashBloc, TrashState>(
      'a 409 RestoreItemEvent keeps the item and surfaces the conflict '
      'message distinctly from successMessage',
      build: () => TrashBloc(
        repository: FakeTrashRepository(
          getResult: const Right([_land, _season]),
          restoreResult: const Left(
            ConflictFailure('plant is still deleted'),
          ),
        ),
      ),
      act: (bloc) async {
        bloc.add(LoadTrashEvent());
        await bloc.stream.firstWhere((s) => s is TrashLoaded);
        bloc.add(RestoreItemEvent(entity: 'season', id: '2'));
      },
      skip: 1, // TrashLoading
      expect: () => [
        const TrashLoaded(items: [_land, _season]),
        const TrashLoaded(
          items: [_land, _season],
          conflictMessage: 'plant is still deleted',
        ),
      ],
    );

    blocTest<TrashBloc, TrashState>(
      'a non-conflict restore failure emits TrashError, keeping the '
      'current items',
      build: () => TrashBloc(
        repository: FakeTrashRepository(
          getResult: const Right([_land]),
          restoreResult: const Left(ServerFailure('boom')),
        ),
      ),
      act: (bloc) async {
        bloc.add(LoadTrashEvent());
        await bloc.stream.firstWhere((s) => s is TrashLoaded);
        bloc.add(RestoreItemEvent(entity: 'land', id: '1'));
      },
      skip: 1, // TrashLoading
      expect: () => [
        const TrashLoaded(items: [_land]),
        const TrashError('boom', items: [_land]),
      ],
    );

    test('RestoreItemEvent calls the repository with the event entity/id', () async {
      final repo = FakeTrashRepository(
        getResult: const Right([_land]),
        restoreResult: const Right(null),
      );
      final bloc = TrashBloc(repository: repo)
        ..add(LoadTrashEvent());
      addTearDown(bloc.close);
      await bloc.stream.firstWhere((s) => s is TrashLoaded);

      bloc.add(RestoreItemEvent(entity: 'land', id: '1'));
      await bloc.stream.firstWhere(
        (s) => s is TrashLoaded && s.successMessage != null,
      );

      expect(repo.lastRestoreCall, (entity: 'land', id: '1'));
    });
  });
}
