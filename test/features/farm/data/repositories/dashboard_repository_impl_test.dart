import 'package:farm_tracker/core/error/exceptions.dart';
import 'package:farm_tracker/core/error/failures.dart';
import 'package:farm_tracker/features/farm/data/datasources/dashboard_remote_data_source.dart';
import 'package:farm_tracker/features/farm/data/models/dashboard_model.dart';
import 'package:farm_tracker/features/farm/data/repositories/dashboard_repository_impl.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeDashboardRemoteDataSource implements DashboardRemoteDataSource {
  Exception? throwOnGetDashboard;

  @override
  Future<DashboardModel> getDashboard() async {
    if (throwOnGetDashboard != null) throw throwOnGetDashboard!;
    return const DashboardModel(
      counts: DashboardCountsModel(
        lands: 1,
        plants: 2,
        seasons: 3,
        harvests: 4,
        animalTypes: 5,
        herds: 6,
      ),
      totals: DashboardTotalsModel(
        totalCosts: 10,
        totalRevenue: 20,
        profit: 10,
      ),
      recent: DashboardRecentModel(
        activities: [],
        harvests: [],
        inputs: [],
        revenues: [],
      ),
    );
  }
}

void main() {
  test('getDashboard maps the model to Right(Dashboard)', () async {
    final repository = DashboardRepositoryImpl(
      remoteDataSource: FakeDashboardRemoteDataSource(),
    );

    final result = await repository.getDashboard();

    final dashboard = result.getOrElse(() => throw StateError('expected Right'));
    expect(dashboard.counts.herds, 6);
    expect(dashboard.totals.profit, 10);
  });

  test('a NetworkException maps to NetworkFailure', () async {
    final dataSource = FakeDashboardRemoteDataSource()
      ..throwOnGetDashboard = NetworkException();
    final repository = DashboardRepositoryImpl(remoteDataSource: dataSource);

    final result = await repository.getDashboard();

    result.fold(
      (failure) => expect(failure, isA<NetworkFailure>()),
      (_) => fail('expected Left'),
    );
  });

  test('a ServerException(msg) maps to ServerFailure(msg)', () async {
    final dataSource = FakeDashboardRemoteDataSource()
      ..throwOnGetDashboard = const ServerException('boom');
    final repository = DashboardRepositoryImpl(remoteDataSource: dataSource);

    final result = await repository.getDashboard();

    result.fold(
      (failure) => expect((failure as ServerFailure).message, 'boom'),
      (_) => fail('expected Left'),
    );
  });

  test(
    'an UnauthorizedException maps to UnauthorizedFailure (F1-05/S4-C1)',
    () async {
      final dataSource = FakeDashboardRemoteDataSource()
        ..throwOnGetDashboard = UnauthorizedException();
      final repository = DashboardRepositoryImpl(remoteDataSource: dataSource);

      final result = await repository.getDashboard();

      result.fold(
        (failure) => expect(failure, isA<UnauthorizedFailure>()),
        (_) => fail('expected Left'),
      );
    },
  );
}
