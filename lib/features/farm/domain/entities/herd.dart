import 'package:equatable/equatable.dart';

class Herd extends Equatable {
  const Herd({
    required this.id,
    required this.userId,
    required this.name,
    required this.animalTypeId,
    required this.location,
    required this.initialHeadCount,
    required this.currentHeadCount,
    required this.createdAt,
    required this.updatedAt,
  });
  final String id;
  final String userId;
  final String name;
  final String animalTypeId;
  final String location;
  final int initialHeadCount;
  final int currentHeadCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  @override
  List<Object?> get props => [
    id,
    userId,
    name,
    animalTypeId,
    location,
    initialHeadCount,
    currentHeadCount,
    createdAt,
    updatedAt,
  ];
}
