import 'package:equatable/equatable.dart';

class Animal extends Equatable {
  const Animal({
    required this.id,
    required this.userId,
    required this.name,
    required this.animalTypeId,
    required this.herdId,
    required this.birthDate,
    required this.createdAt, required this.updatedAt, this.sex,
    this.acquisitionSource,
  });

  final String id;
  final String userId;
  final String name;
  final String animalTypeId;
  final String herdId;
  final DateTime birthDate;

  /// "male" or "female". Null means not recorded.
  final String? sex;

  /// "bought", "bredOnFarm", or "gift". Null means not recorded.
  final String? acquisitionSource;
  final DateTime createdAt;
  final DateTime updatedAt;

  @override
  List<Object?> get props => [
        id,
        userId,
        name,
        animalTypeId,
        herdId,
        birthDate,
        sex,
        acquisitionSource,
        createdAt,
        updatedAt,
      ];
}
