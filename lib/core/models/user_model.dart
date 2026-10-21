import 'dart:convert';
import '../api/api_client.dart';

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

  static List<String> _extractRolesFromJwt(String? token) {
    if (token == null || token.isEmpty) return [];
    try {
      final parts = token.split('.');
      if (parts.length != 3) return [];
      String normalized = base64Url.normalize(parts[1]);
      String payload = utf8.decode(base64Url.decode(normalized));
      final Map<String, dynamic> data = jsonDecode(payload);
      final List<String> extracted = [];
      if (data['roles'] is List) {
        for (final r in data['roles']) {
          if (r != null) extracted.add(r.toString());
        }
      } else if (data['role'] != null) {
        extracted.add(data['role'].toString());
      }
      return extracted;
    } catch (_) {
      return [];
    }
  }

  factory UserModel.fromJson(Map<String, dynamic> json, [String? authToken]) {
    final Set<String> collectedRoles = {};

    // 1. Roles list from API response
    if (json['roles'] != null) {
      if (json['roles'] is List) {
        for (final item in json['roles'] as List) {
          if (item is String && item.trim().isNotEmpty) {
            collectedRoles.add(item.trim().toUpperCase());
          } else if (item is Map) {
            final name = item['name'] ?? item['role'] ?? item['code'];
            if (name != null && name.toString().trim().isNotEmpty) {
              collectedRoles.add(name.toString().trim().toUpperCase());
            }
          }
        }
      } else if (json['roles'] is String && json['roles'].toString().trim().isNotEmpty) {
        collectedRoles.add(json['roles'].toString().trim().toUpperCase());
      }
    }

    // 2. Single role field from user object
    final rawRole = json['role'] ?? json['role_name'] ?? json['roleName'];
    if (rawRole != null) {
      if (rawRole is String && rawRole.trim().isNotEmpty) {
        collectedRoles.add(rawRole.trim().toUpperCase());
      } else if (rawRole is Map) {
        final name = rawRole['name'] ?? rawRole['code'];
        if (name != null && name.toString().trim().isNotEmpty) {
          collectedRoles.add(name.toString().trim().toUpperCase());
        }
      }
    }

    // 3. Fallback / supplementary check with JWT token (just like web auth.js does)
    final tokenToInspect = authToken ?? ApiClient().authToken;
    final jwtRoles = _extractRolesFromJwt(tokenToInspect);
    for (final r in jwtRoles) {
      if (r.trim().isNotEmpty) {
        collectedRoles.add(r.trim().toUpperCase());
      }
    }

    // Default to CUSTOMER if no role found
    if (collectedRoles.isEmpty) {
      collectedRoles.add('CUSTOMER');
    }

    final parsedRoles = collectedRoles.toList();

    // Determine primaryRole
    String primaryRole;
    if (json['role'] != null && json['role'] is String && json['role'].toString().trim().isNotEmpty) {
      primaryRole = json['role'].toString().trim().toUpperCase();
    } else if (collectedRoles.contains('ADMIN') ||
        collectedRoles.contains('SUPER_ADMIN') ||
        collectedRoles.contains('ADMINISTRATOR')) {
      primaryRole = 'ADMIN';
    } else if (collectedRoles.contains('ORGANIZER')) {
      primaryRole = 'ORGANIZER';
    } else if (collectedRoles.contains('STAFF')) {
      primaryRole = 'STAFF';
    } else if (collectedRoles.isNotEmpty) {
      primaryRole = collectedRoles.first;
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
  bool get isStaff => hasRole('STAFF');
  bool get isCustomer => hasRole('CUSTOMER') || (!isAdmin && !isOrganizer && !hasRole('STAFF'));

  /// True when user ONLY has customer role without any staff/organizer/admin permissions
  bool get isCustomerOnly => !hasRole('STAFF') && !isAdmin && !isOrganizer;

  /// True when user has both Customer and Staff privileges and can switch between them
  bool get canSwitchRoles => hasRole('STAFF') && isCustomer;

  /// True when user has permission to enter Staff Portal (strictly role STAFF)
  bool get canAccessStaff => hasRole('STAFF');

  String get roleDisplayName {
    if (isAdmin) return 'Quản trị viên';
    if (isOrganizer) return 'Ban tổ chức';
    if (hasRole('STAFF') && hasRole('CUSTOMER')) return 'Khách hàng & Nhân viên';
    if (hasRole('STAFF')) return 'Nhân viên';
    return 'Khách hàng';
  }
}


