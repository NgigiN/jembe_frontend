import 'package:equatable/equatable.dart';

class Crop extends Equatable {
  final String id;
  final String userId;
  final String name;
  final String? variety;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Crop({
    required this.id,
    required this.userId,
    required this.name,
    this.variety,
    required this.createdAt,
    required this.updatedAt,
  });

  @override
  List<Object?> get props => [id, userId, name, variety, createdAt, updatedAt];
}
