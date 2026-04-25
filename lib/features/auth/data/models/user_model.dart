import 'package:farm_tracker/features/auth/domain/entities/user.dart';

class UserModel extends User {
  const UserModel({
    required super.id,
    required super.email,
    required super.firstName,
    required super.lastName,
    required super.farmName,
    required super.location,
    required super.pictureUrl,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: (json['id'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      firstName: (json['first_name'] ?? '').toString(),
      lastName: (json['last_name'] ?? '').toString(),
      farmName: (json['farm_name'] ?? '').toString(),
      location: (json['location'] ?? '').toString(),
      pictureUrl: (json['picture_url'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'first_name': firstName,
      'last_name': lastName,
      'farm_name': farmName,
      'location': location,
      'picture_url': pictureUrl,
    };
  }
}
