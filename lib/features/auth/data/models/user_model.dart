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

  factory UserModel.empty() {
    return const UserModel(
      id: '',
      email: '',
      firstName: '',
      lastName: '',
      farmName: '',
      location: '',
      pictureUrl: '',
    );
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: (json['id'] ?? json['ID'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      firstName: (json['first_name'] ?? json['firstName'] ?? '').toString(),
      lastName: (json['last_name'] ?? json['lastName'] ?? '').toString(),
      farmName: (json['farm_name'] ?? json['farmName'] ?? '').toString(),
      location: (json['location'] ?? '').toString(),
      pictureUrl: (json['picture_url'] ?? json['profile_picture'] ?? json['pictureUrl'] ?? '').toString(),
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
