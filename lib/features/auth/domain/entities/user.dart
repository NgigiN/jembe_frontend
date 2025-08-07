import 'package:equatable/equatable.dart';

class User extends Equatable {
  final String id;
  final String email;
  final String name;
  final String farmName;
  final String location;
  const User({
    required this.id,
    required this.email,
    required this.name,
    required this.farmName,
    required this.location,
  });

  @override
  List<Object?> get props => [id, email, name, farmName, location];
}
