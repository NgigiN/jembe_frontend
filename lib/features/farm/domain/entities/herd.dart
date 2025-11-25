import 'package:equatable/equatable.dart';

class Herd extends Equatable {
  final String id;
  final String userId;
  final String name;
  final String animalTypeId;
  final String location;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Herd({
    required this.id,
    required this.userId,
    required this.name,
    required this.animalTypeId,
    required this.location,
    required this.createdAt,
    required this.updatedAt,
  });

  @override
  List<Object?> get props => [id, userId, name, animalTypeId, location, createdAt, updatedAt];
}

