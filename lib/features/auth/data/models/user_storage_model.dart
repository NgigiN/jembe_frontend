class UserStorageModel {
  final String email;
  final String farmName;
  final String id;
  final String location;
  final String name;
  final String token;

  UserStorageModel({
    required this.email,
    required this.farmName,
    required this.id,
    required this.location,
    required this.name,
    required this.token,
  });

  factory UserStorageModel.fromJson(Map<String, dynamic> json) {
    return UserStorageModel(
      email: json['email'] ?? '',
      farmName: json['farm_name'] ?? '',
      id: json['id'] ?? '',
      location: json['location'] ?? '',
      name: json['name'] ?? '',
      token: json['token'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'email': email,
      'farm_name': farmName,
      'id': id,
      'location': location,
      'name': name,
      'token': token,
    };
  }

  factory UserStorageModel.fromAuthResponse(
    Map<String, dynamic> record,
    String token,
  ) {
    return UserStorageModel(
      email: record['email'] ?? '',
      farmName: record['farm_name'] ?? '',
      id: record['id'] ?? '',
      location: record['location'] ?? '',
      name: record['name'] ?? '',
      token: token,
    );
  }
}
