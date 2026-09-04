import 'package:farm_tracker/features/farm/data/models/animal_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final birthDate = DateTime(2024);

  group('AnimalModel.create', () {
    test('carries optional sex and acquisitionSource through', () {
      final animal = AnimalModel.create(
        userId: 'user-1',
        name: 'Bessie',
        animalTypeId: 'type-1',
        herdId: 'herd-1',
        birthDate: birthDate,
        sex: 'female',
        acquisitionSource: 'bought',
      );

      expect(animal.sex, 'female');
      expect(animal.acquisitionSource, 'bought');
    });

    test('defaults sex and acquisitionSource to null when omitted', () {
      final animal = AnimalModel.create(
        userId: 'user-1',
        name: 'Bessie',
        animalTypeId: 'type-1',
        herdId: 'herd-1',
        birthDate: birthDate,
      );

      expect(animal.sex, isNull);
      expect(animal.acquisitionSource, isNull);
    });
  });

  group('AnimalModel.fromJson', () {
    test('parses snake_case sex and acquisition_source', () {
      final animal = AnimalModel.fromJson({
        'id': '1',
        'user_id': 'user-1',
        'name': 'Bessie',
        'animal_type_id': 'type-1',
        'herd_id': 'herd-1',
        'birth_date': birthDate.toIso8601String(),
        'sex': 'male',
        'acquisition_source': 'gift',
      });

      expect(animal.sex, 'male');
      expect(animal.acquisitionSource, 'gift');
    });

    test('parses missing sex and acquisition_source as null', () {
      final animal = AnimalModel.fromJson({
        'id': '1',
        'user_id': 'user-1',
        'name': 'Bessie',
        'animal_type_id': 'type-1',
        'herd_id': 'herd-1',
        'birth_date': birthDate.toIso8601String(),
      });

      expect(animal.sex, isNull);
      expect(animal.acquisitionSource, isNull);
    });
  });

  group('AnimalModel.toJson', () {
    test('includes sex and acquisition_source', () {
      final animal = AnimalModel.create(
        userId: 'user-1',
        name: 'Bessie',
        animalTypeId: 'type-1',
        herdId: 'herd-1',
        birthDate: birthDate,
        sex: 'female',
        acquisitionSource: 'bredOnFarm',
      );

      expect(animal.toJson()['sex'], 'female');
      expect(animal.toJson()['acquisition_source'], 'bredOnFarm');
    });
  });
}
