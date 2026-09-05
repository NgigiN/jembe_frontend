import 'package:farm_tracker/features/farm/data/datasources/animal_remote_data_source.dart';
import 'package:farm_tracker/features/farm/data/models/animal_model.dart';
import 'package:farm_tracker/features/farm/data/repositories/animal_repository_impl.dart';
import 'package:farm_tracker/features/farm/domain/entities/animal.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeAnimalRemoteDataSource implements AnimalRemoteDataSource {
  AnimalModel? lastAdded;
  AnimalModel? lastUpdated;

  @override
  Future<List<AnimalModel>> getAnimals() async => [];

  @override
  Future<AnimalModel> addAnimal(AnimalModel animal) async {
    lastAdded = animal;
    return animal;
  }

  @override
  Future<AnimalModel> updateAnimal(AnimalModel animal) async {
    lastUpdated = animal;
    return animal;
  }

  @override
  Future<void> deleteAnimal(String id) async {}
}

void main() {
  final birthDate = DateTime(2024);

  test(
    'addAnimal carries sex and acquisitionSource from the Animal entity into the model sent to the data source',
    () async {
      final dataSource = FakeAnimalRemoteDataSource();
      final repository = AnimalRepositoryImpl(remoteDataSource: dataSource);
      final now = DateTime.now();

      await repository.addAnimal(
        Animal(
          id: '',
          userId: 'user-1',
          name: 'Bessie',
          animalTypeId: 'type-1',
          herdId: 'herd-1',
          birthDate: birthDate,
          sex: 'female',
          acquisitionSource: 'bought',
          createdAt: now,
          updatedAt: now,
        ),
      );

      expect(dataSource.lastAdded?.sex, 'female');
      expect(dataSource.lastAdded?.acquisitionSource, 'bought');
    },
  );

  test(
    'updateAnimal carries sex and acquisitionSource from the Animal entity into the model sent to the data source',
    () async {
      final dataSource = FakeAnimalRemoteDataSource();
      final repository = AnimalRepositoryImpl(remoteDataSource: dataSource);
      final now = DateTime.now();

      await repository.updateAnimal(
        Animal(
          id: 'animal-1',
          userId: 'user-1',
          name: 'Bessie',
          animalTypeId: 'type-1',
          herdId: 'herd-1',
          birthDate: birthDate,
          sex: 'male',
          acquisitionSource: 'gift',
          createdAt: now,
          updatedAt: now,
        ),
      );

      expect(dataSource.lastUpdated?.sex, 'male');
      expect(dataSource.lastUpdated?.acquisitionSource, 'gift');
    },
  );
}
