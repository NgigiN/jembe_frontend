import 'package:equatable/equatable.dart';

class AnimalType extends Equatable {
  const AnimalType({
    required this.id,
    required this.userId,
    required this.name,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });
  final String id;
  final String userId;
  final String name;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  @override
  List<Object?> get props => [id, userId, name, notes, createdAt, updatedAt];
}
