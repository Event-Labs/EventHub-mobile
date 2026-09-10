class UserModel {
  final String id;
  final String email;
  final String fullName;
  final String? phone;
  final String role;
  final String? avatarUrl;

  UserModel({
    required this.id,
    required this.email,
    required this.fullName,
    this.phone,
    required this.role,
    this.avatarUrl,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      fullName: json['full_name']?.toString() ?? json['fullName']?.toString() ?? 'Khách hàng',
      phone: json['phone']?.toString(),
      role: json['role']?.toString() ?? 'CUSTOMER',
      avatarUrl: json['avatar_url']?.toString() ?? json['avatarUrl']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'full_name': fullName,
      'phone': phone,
      'role': role,
      'avatar_url': avatarUrl,
    };
  }

  bool get isStaff => role == 'STAFF' || role == 'ORGANIZER' || role == 'ADMIN';
}
