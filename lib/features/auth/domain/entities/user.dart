import 'package:equatable/equatable.dart';

class User extends Equatable {
  const User({
    required this.id,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.farmName,
    required this.location,
    required this.pictureUrl,
  });
  final String id;
  final String email;
  final String firstName;
  final String lastName;
  final String farmName;
  final String location;
  final String pictureUrl;

  String get fullName => '$firstName $lastName';

  @override
  List<Object?> get props => [id, email, firstName, lastName, farmName, location, pictureUrl];
}
