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
    final firstName = (json['first_name'] ?? '').toString();
    final lastName = (json['last_name'] ?? '').toString();
    final fullName = '$firstName $lastName'.trim();
    return UserStorageModel(
      email: (json['email'] ?? '').toString(),
      farmName: (json['farm_name'] ?? '').toString(),
      id: (json['id'] ?? '').toString(),
      location: (json['location'] ?? '').toString(),
      name: (json['name'] ?? fullName).toString(),
      token: (json['token'] ?? '').toString(),
      loginTime: json['login_time'] != null
          ? DateTime.parse(json['login_time'].toString())
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
    final firstName = (record['first_name'] ?? '').toString();
    final lastName = (record['last_name'] ?? '').toString();
    final fullName = '$firstName $lastName'.trim();
    return UserStorageModel(
      email: (record['email'] ?? '').toString(),
      farmName: (record['farm_name'] ?? '').toString(),
      id: (record['id'] ?? '').toString(),
      location: (record['location'] ?? '').toString(),
      name: fullName.isNotEmpty ? fullName : (record['name'] ?? '').toString(),
      token: token,
      loginTime: DateTime.now(),
    );
  }
}
