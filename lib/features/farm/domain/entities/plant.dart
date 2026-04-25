import 'package:equatable/equatable.dart';

class Plant extends Equatable {
  const Plant({
    required this.id,
    required this.userId,
    required this.name,
    this.variety,
    required this.createdAt,
    required this.updatedAt,
  });
  final String id;
  final String userId;
  final String name;
  final String? variety;
  final DateTime createdAt;
  final DateTime updatedAt;

  @override
  List<Object?> get props => [id, userId, name, variety, createdAt, updatedAt];
}
