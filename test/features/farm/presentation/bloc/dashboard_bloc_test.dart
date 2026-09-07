import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:farm_tracker/core/error/failures.dart';
import 'package:farm_tracker/features/farm/domain/entities/dashboard.dart';
import 'package:farm_tracker/features/farm/domain/repositories/dashboard_repository.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/dashboard_bloc.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/dashboard_event.dart';
import 'package:farm_tracker/features/farm/presentation/bloc/dashboard_state.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeDashboardRepository implements DashboardRepository {
  FakeDashboardRepository({this.result});
  Either<Failure, Dashboard>? result;

  @override
  Future<Either<Failure, Dashboard>> getDashboard() async {
    return result ?? const Left(ServerFailure('not stubbed'));
  }
}

const _counts = DashboardCounts(
  lands: 3,
  plants: 5,
  seasons: 2,
  harvests: 7,
  animalTypes: 4,
  herds: 6,
);
const _totals = DashboardTotals(
  totalCosts: 100,
  totalRevenue: 200,
  profit: 100,
);
const _dashboard = Dashboard(
  counts: _counts,
  totals: _totals,
  recent: DashboardRecent.empty(),
);

void main() {
  group('DashboardBloc', () {
    blocTest<DashboardBloc, DashboardState>(
      'emits [DashboardLoading, DashboardLoaded] with the repository '
      'counts/totals on a successful GetDashboardEvent',
      build: () => DashboardBloc(
        repository: FakeDashboardRepository(result: const Right(_dashboard)),
      ),
      act: (bloc) => bloc.add(GetDashboardEvent()),
      expect: () => [
        const DashboardLoading(),
        const DashboardLoaded(counts: _counts, totals: _totals),
      ],
    );

    blocTest<DashboardBloc, DashboardState>(
      'emits [DashboardLoading, DashboardError] with a resolved message '
      'when the repository fails',
      build: () => DashboardBloc(
        repository: FakeDashboardRepository(
          result: const Left(NetworkFailure()),
        ),
      ),
      act: (bloc) => bloc.add(GetDashboardEvent()),
      expect: () => [
        const DashboardLoading(),
        const DashboardError(
          'No internet connection. Check your network and try again.',
        ),
      ],
    );

    test('starts in DashboardInitial', () {
      final bloc = DashboardBloc(repository: FakeDashboardRepository());
      addTearDown(bloc.close);
      expect(bloc.state, const DashboardInitial());
    });
  });
}
