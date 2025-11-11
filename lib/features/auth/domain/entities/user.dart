import 'package:equatable/equatable.dart';

class User extends Equatable {
  final String id;
  final String email;
  final String firstName;
  final String lastName;
  final String farmName;
  final String location;
  const User({
    required this.id,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.farmName,
    required this.location,
  });

  String get fullName => '$firstName $lastName';

  @override
  List<Object?> get props => [id, email, firstName, lastName, farmName, location];
}
