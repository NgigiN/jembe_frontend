import 'package:equatable/equatable.dart';

class Animal extends Equatable {
  const Animal({
    required this.id,
    required this.userId,
    required this.name,
    required this.type,
    this.number,
    required this.createdAt,
    required this.updatedAt,
  });
  final String id;
  final String userId;
  final String name;
  final String type;
  final int? number;
  final DateTime createdAt;
  final DateTime updatedAt;

  @override
  List<Object?> get props => [
    id,
    userId,
    name,
    type,
    number,
    createdAt,
    updatedAt,
  ];
}
