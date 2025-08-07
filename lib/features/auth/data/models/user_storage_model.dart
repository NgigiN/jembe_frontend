class UserStorageModel {
  final String email;
  final String farmName;
  final String id;
  final String location;
  final String name;
  final String token;
  final DateTime loginTime;

  UserStorageModel({
    required this.email,
    required this.farmName,
    required this.id,
    required this.location,
    required this.name,
    required this.token,
    required this.loginTime,
  });

  factory UserStorageModel.fromJson(Map<String, dynamic> json) {
    return UserStorageModel(
      email: json['email'] ?? '',
      farmName: json['farm_name'] ?? '',
      id: json['id'] ?? '',
      location: json['location'] ?? '',
      name: json['name'] ?? '',
      token: json['token'] ?? '',
      loginTime: json['login_time'] != null
          ? DateTime.parse(json['login_time'])
          : DateTime.now(),
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
      'login_time': loginTime.toIso8601String(),
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
      loginTime: DateTime.now(),
    );
  }
}
