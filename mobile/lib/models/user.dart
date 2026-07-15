class AppUser {
  final String id;
  final String fullName;
  final String email;
  final String role;

  AppUser({required this.id, required this.fullName, required this.email, required this.role});

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'] ?? json['_id'] ?? '',
      fullName: json['fullName'] ?? '',
      email: json['email'] ?? '',
      role: json['role'] ?? 'user',
    );
  }

  Map<String, dynamic> toJson() => {'id': id, 'fullName': fullName, 'email': email, 'role': role};
}
