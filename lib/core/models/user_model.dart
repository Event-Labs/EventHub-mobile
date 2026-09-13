class UserModel {
  final String id;
  final String email;
  final String fullName;
  final String? phone;
  final String? address;
  final String? dob;
  final String? city;
  final String role;
  final List<String> roles;
  final String? avatarUrl;
  final String? bio;
  final bool hasPassword;

  UserModel({
    required this.id,
    required this.email,
    required this.fullName,
    this.phone,
    this.address,
    this.dob,
    this.city,
    required this.role,
    this.roles = const [],
    this.avatarUrl,
    this.bio,
    this.hasPassword = true,
  });

  static String? parseDob(dynamic value) {
    if (value == null) return null;
    final str = value.toString().trim();
    if (str.isEmpty) return null;
    final parsed = DateTime.tryParse(str);
    if (parsed != null) {
      final local = parsed.isUtc ? parsed.toLocal() : parsed;
      return "${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}";
    }
    if (str.contains('T')) {
      return str.split('T')[0];
    }
    return str;
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    List<String> parsedRoles = [];
    if (json['roles'] != null) {
      if (json['roles'] is List) {
        parsedRoles = (json['roles'] as List).map((e) => e.toString().trim()).toList();
      }
    }

    final rolesUpper = parsedRoles.map((r) => r.toUpperCase()).toList();
    String primaryRole;
    if (json['role'] != null && json['role'].toString().trim().isNotEmpty) {
      primaryRole = json['role'].toString().trim().toUpperCase();
    } else if (rolesUpper.contains('ADMIN') || rolesUpper.contains('SUPER_ADMIN') || rolesUpper.contains('ADMINISTRATOR')) {
      primaryRole = 'ADMIN';
    } else if (rolesUpper.contains('ORGANIZER')) {
      primaryRole = 'ORGANIZER';
    } else if (rolesUpper.contains('STAFF')) {
      primaryRole = 'STAFF';
    } else if (rolesUpper.isNotEmpty) {
      primaryRole = rolesUpper.first;
    } else {
      primaryRole = 'CUSTOMER';
    }

    return UserModel(
      id: json['id']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      fullName: json['full_name']?.toString() ?? json['fullName']?.toString() ?? 'Khách hàng',
      phone: json['phone']?.toString(),
      address: json['address']?.toString(),
      dob: parseDob(json['dob']),
      city: json['city']?.toString(),
      role: primaryRole,
      roles: parsedRoles,
      avatarUrl: json['avatar_url']?.toString() ?? json['avatarUrl']?.toString(),
      bio: json['bio']?.toString(),
      hasPassword: json['hasPassword'] ?? json['has_password'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'full_name': fullName,
      'phone': phone,
      'address': address,
      'dob': dob,
      'city': city,
      'role': role,
      'roles': roles,
      'avatar_url': avatarUrl,
      'bio': bio,
      'has_password': hasPassword,
    };
  }

  UserModel copyWith({
    String? id,
    String? email,
    String? fullName,
    String? phone,
    String? address,
    String? dob,
    String? city,
    String? role,
    List<String>? roles,
    String? avatarUrl,
    String? bio,
    bool? hasPassword,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      dob: dob != null ? parseDob(dob) : this.dob,
      city: city ?? this.city,
      role: role ?? this.role,
      roles: roles ?? this.roles,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      bio: bio ?? this.bio,
      hasPassword: hasPassword ?? this.hasPassword,
    );
  }

  String get formattedDob {
    if (dob == null || dob!.trim().isEmpty) return 'Chưa cập nhật';
    final parsed = DateTime.tryParse(dob!);
    if (parsed != null) {
      final local = parsed.isUtc ? parsed.toLocal() : parsed;
      return "${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${local.year}";
    }
    return dob!;
  }

  bool hasRole(String targetRole) {
    final upper = targetRole.toUpperCase();
    if (role.toUpperCase() == upper) return true;
    return roles.any((r) => r.toUpperCase() == upper);
  }

  bool get isAdmin => hasRole('ADMIN') || hasRole('SUPER_ADMIN') || hasRole('ADMINISTRATOR');
  bool get isOrganizer => hasRole('ORGANIZER');
  bool get isStaff => hasRole('STAFF') || isOrganizer || isAdmin;
  bool get isCustomer => hasRole('CUSTOMER');

  String get roleDisplayName {
    if (isAdmin) return 'Quản trị viên';
    if (isOrganizer) return 'Ban tổ chức';
    if (hasRole('STAFF')) return 'Nhân viên';
    return 'Khách hàng';
  }
}


