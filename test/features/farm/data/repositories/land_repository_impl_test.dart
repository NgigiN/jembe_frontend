import 'package:farm_tracker/features/farm/data/datasources/land_remote_data_source.dart';
import 'package:farm_tracker/features/farm/data/models/land_model.dart';
import 'package:farm_tracker/features/farm/data/repositories/land_repository_impl.dart';
import 'package:farm_tracker/features/farm/domain/entities/land.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeLandRemoteDataSource implements LandRemoteDataSource {
  LandModel? lastAdded;
  LandModel? lastUpdated;

  @override
  Future<List<LandModel>> getLands({DateTime? updatedSince}) async => [];

  @override
  Future<LandModel> addLand(LandModel land) async {
    lastAdded = land;
    return land;
  }

  @override
  Future<LandModel> updateLand(LandModel land) async {
    lastUpdated = land;
    return land;
  }

  @override
  Future<void> deleteLand(String id) async {}
}

void main() {
  test('addLand carries tenureType from the Land entity into the model sent to the data source', () async {
    final dataSource = FakeLandRemoteDataSource();
    final repository = LandRepositoryImpl(remoteDataSource: dataSource);
    final now = DateTime.now();

    await repository.addLand(
      Land(
        id: '',
        userId: 'user-1',
        name: 'North Field',
        tenureType: 'rented',
        createdAt: now,
        updatedAt: now,
      ),
    );

    expect(dataSource.lastAdded?.tenureType, 'rented');
  });

  test('updateLand carries tenureType from the Land entity into the model sent to the data source', () async {
    final dataSource = FakeLandRemoteDataSource();
    final repository = LandRepositoryImpl(remoteDataSource: dataSource);
    final now = DateTime.now();

    await repository.updateLand(
      Land(
        id: 'land-1',
        userId: 'user-1',
        name: 'North Field',
        tenureType: 'owned',
        createdAt: now,
        updatedAt: now,
      ),
    );

    expect(dataSource.lastUpdated?.tenureType, 'owned');
  });
}
