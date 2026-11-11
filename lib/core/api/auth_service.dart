import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import 'api_client.dart';
import 'api_config.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal() {
    _ensureSessionCallbacks();
  }

  static const String _keyAuthToken = 'auth_token';
  static const String _keyRefreshToken = 'refresh_token';
  static const String _keyUserData = 'user_data';

  UserModel? _currentUser;

  UserModel? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;
  void setDemoUser({required bool isStaff}) {}

  void _ensureSessionCallbacks() {
    ApiClient().setSessionCallbacks(
      onTokensUpdated: (accessToken, refreshToken) async {
        await _persistTokens(accessToken, refreshToken);
        if (_currentUser != null && accessToken != null) {
          _currentUser = UserModel.fromJson(_currentUser!.toJson(), accessToken);
          await _saveSession(_currentUser!, accessToken, refreshToken: refreshToken);
        }
      },
      onAuthExpired: () async {
        _currentUser = null;
        await _clearSession();
      },
    );
  }

  Future<void> _persistTokens(String? accessToken, String? refreshToken) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (accessToken != null && accessToken.isNotEmpty) {
        await prefs.setString(_keyAuthToken, accessToken);
      }
      if (refreshToken != null && refreshToken.isNotEmpty) {
        await prefs.setString(_keyRefreshToken, refreshToken);
      }
    } catch (e) {
      debugPrint('Error persisting tokens: $e');
    }
  }

  /// Restores saved login session on app startup
  Future<UserModel?> restoreSession() async {
    _ensureSessionCallbacks();
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(_keyAuthToken);
      final refreshToken = prefs.getString(_keyRefreshToken);
      final userJson = prefs.getString(_keyUserData);

      if (token != null && token.isNotEmpty) {
        ApiClient().setAuthTokens(accessToken: token, refreshToken: refreshToken);

        UserModel? cachedUser;
        if (userJson != null && userJson.isNotEmpty) {
          try {
            final Map<String, dynamic> data = jsonDecode(userJson);
            cachedUser = UserModel.fromJson(data, token);
          } catch (e) {
            debugPrint('Failed to parse cached user json: $e');
          }
        }

        // If the saved JWT is already expired, refresh immediately or clear session
        if (ApiClient.isJwtExpired(token)) {
          if (refreshToken != null && refreshToken.isNotEmpty) {
            final refreshed = await ApiClient().refreshAccessToken();
            if (!refreshed) {
              await logout();
              return null;
            }
          } else {
            debugPrint('[AuthService] Stored JWT expired without refresh_token; clearing session.');
            await logout();
            return null;
          }
        }

        // Validate token and load fresh roles from server
        try {
          final res = await fetchProfile().timeout(const Duration(seconds: 5));
          if (res['success'] == true && res['user'] is UserModel) {
            var user = res['user'] as UserModel;
            final currentToken = ApiClient().authToken ?? token;
            final jwtRoles = UserModel.extractRolesFromJwt(currentToken);
            final dbNeedsStaffJwt = user.canAccessStaff && !jwtRoles.contains('STAFF');

            // Refresh JWT if DB roles changed (e.g. invited as Staff after login)
            if (dbNeedsStaffJwt && (ApiClient().refreshToken?.isNotEmpty ?? false)) {
              final refreshed = await ApiClient().refreshAccessToken();
              if (refreshed && ApiClient().authToken != null) {
                user = UserModel.fromJson(user.toJson(), ApiClient().authToken);
              }
            }

            _currentUser = user;
            await _saveSession(
              user,
              ApiClient().authToken ?? token,
              refreshToken: ApiClient().refreshToken,
            );
            return _currentUser;
          }

          final statusCode = res['statusCode'];
          final errorCode = res['errorCode']?.toString() ?? '';
          final msg = res['message']?.toString().toLowerCase() ?? '';
          if (statusCode == 401 ||
              errorCode.startsWith('AUTH_') ||
              msg.contains('401') ||
              msg.contains('unauthorized')) {
            await logout();
            return null;
          }
        } catch (e) {
          debugPrint('[AuthService] restoreSession fetchProfile warning: $e');
        }

        // Offline / timeout fallback only if JWT is still valid locally
        final activeToken = ApiClient().authToken;
        if (activeToken != null && !ApiClient.isJwtExpired(activeToken) && cachedUser != null) {
          _currentUser = cachedUser;
          return _currentUser;
        }

        await logout();
        return null;
      }
    } catch (e) {
      debugPrint('Error restoring session: $e');
    }
    return null;
  }

  Future<void> _saveSession(
    UserModel user,
    String token, {
    String? refreshToken,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyAuthToken, token);
      final effectiveRefresh = refreshToken ?? ApiClient().refreshToken;
      if (effectiveRefresh != null && effectiveRefresh.isNotEmpty) {
        await prefs.setString(_keyRefreshToken, effectiveRefresh);
      }
      await prefs.setString(_keyUserData, jsonEncode(user.toJson()));
    } catch (e) {
      debugPrint('Error saving session: $e');
    }
  }

  Future<void> _clearSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyAuthToken);
      await prefs.remove(_keyRefreshToken);
      await prefs.remove(_keyUserData);
    } catch (e) {
      debugPrint('Error clearing session: $e');
    }
  }

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    _ensureSessionCallbacks();
    final response = await ApiClient().post(ApiConfig.login, {
      'email': email,
      'password': password,
    });

    if (response['success'] == true && response['data'] != null) {
      final data = response['data'];
      if (data is Map && data['requiresTwoFactor'] == true) {
        return {
          'success': false,
          'requiresTwoFactor': true,
          'message': 'Tài khoản yêu cầu xác thực OTP hai bước khi đăng nhập.',
        };
      }
      final token = data['accessToken']?.toString();
      if (token != null) {
        ApiClient().setAuthToken(token);
      }
      if (data['user'] != null) {
        _currentUser = UserModel.fromJson(data['user'], token);
        if (token != null && _currentUser != null) {
          await _saveSession(
            _currentUser!,
            token,
            refreshToken: ApiClient().refreshToken,
          );
        }
      }
      return {'success': true, 'user': _currentUser, 'message': response['message'] ?? 'Đăng nhập thành công'};
    }

    return {'success': false, 'message': response['message'] ?? 'Đăng nhập thất bại'};
  }

  Future<Map<String, dynamic>> loginWithGoogle() async {
    _ensureSessionCallbacks();
    try {
      final GoogleSignIn googleSignIn = GoogleSignIn(
        serverClientId: ApiConfig.googleServerClientId,
        scopes: ['email', 'profile'],
      );

      // Sign out first to allow account picker
      try {
        await googleSignIn.signOut();
      } catch (_) {}

      final GoogleSignInAccount? googleAccount = await googleSignIn.signIn();
      if (googleAccount == null) {
        return {'success': false, 'cancelled': true, 'message': 'Đã hủy đăng nhập Google'};
      }

      final GoogleSignInAuthentication auth = await googleAccount.authentication;
      final String? idToken = auth.idToken;

      if (idToken == null || idToken.isEmpty) {
        return {
          'success': false,
          'message': 'Không thể lấy ID Token từ Google. Vui lòng kiểm tra cấu hình OAuth (Package Name & SHA-1).'
        };
      }

      final response = await ApiClient().post(ApiConfig.googleLogin, {
        'credential': idToken,
      });

      if (response['success'] == true && response['data'] != null) {
        final data = response['data'];
        if (data is Map && data['requiresTwoFactor'] == true) {
          return {
            'success': false,
            'requiresTwoFactor': true,
            'message': 'Tài khoản yêu cầu xác thực OTP hai bước khi đăng nhập.',
          };
        }
        final token = data['accessToken']?.toString();
        if (token != null) {
          ApiClient().setAuthToken(token);
        }
        if (data['user'] != null) {
          _currentUser = UserModel.fromJson(data['user'], token);
          if (token != null && _currentUser != null) {
            await _saveSession(
              _currentUser!,
              token,
              refreshToken: ApiClient().refreshToken,
            );
          }
        }
        return {
          'success': true,
          'user': _currentUser,
          'message': response['message'] ?? 'Đăng nhập Google thành công',
        };
      }

      return {
        'success': false,
        'message': response['message'] ?? 'Đăng nhập Google thất bại'
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Lỗi khi kết nối Google: $e',
      };
    }
  }

  Future<Map<String, dynamic>> register({
    required String fullName,
    required String email,
    required String password,
    String? phone,
  }) async {
    final Map<String, dynamic> body = {
      'full_name': fullName,
      'email': email,
      'password': password,
    };
    if (phone != null && phone.trim().isNotEmpty) {
      body['phone'] = phone.trim();
    }

    final response = await ApiClient().post(ApiConfig.register, body);

    if (response['success'] == true) {
      return {'success': true, 'message': response['message'] ?? 'Đăng ký tài khoản thành công'};
    }

    return {'success': false, 'message': response['message'] ?? 'Đăng ký thất bại'};
  }

  Future<Map<String, dynamic>> verifyEmail(String token) async {
    final response = await ApiClient().get(
      ApiConfig.verifyEmail,
      queryParams: {'token': token.trim()},
    );

    if (response['success'] == true) {
      return {
        'success': true,
        'message': response['message'] ?? 'Xác thực email thành công',
      };
    }

    return {
      'success': false,
      'message': response['message'] ?? 'Mã xác thực không hợp lệ hoặc đã hết hạn',
    };
  }

  Future<Map<String, dynamic>> forgotPassword(String email) async {
    final response = await ApiClient().post(ApiConfig.forgotPassword, {
      'email': email,
    });

    if (response['success'] == true) {
      return {'success': true, 'message': 'Đã gửi yêu cầu đặt lại mật khẩu đến $email'};
    }
    return {'success': false, 'message': response['message'] ?? 'Không thể gửi yêu cầu'};
  }

  Future<Map<String, dynamic>> resetPassword({
    required String token,
    required String newPassword,
  }) async {
    final response = await ApiClient().post(ApiConfig.resetPassword, {
      'token': token.trim(),
      'newPassword': newPassword,
    });

    if (response['success'] == true) {
      return {
        'success': true,
        'message': response['message'] ?? 'Đặt lại mật khẩu thành công',
      };
    }

    return {
      'success': false,
      'message': response['message'] ?? 'Mã đặt lại mật khẩu không hợp lệ hoặc đã hết hạn',
    };
  }

  Future<Map<String, dynamic>> fetchProfile() async {
    final response = await ApiClient().get('/users/me');
    if (response['success'] == true && response['data'] != null) {
      _currentUser = UserModel.fromJson(response['data'], ApiClient().authToken);
      final token = ApiClient().authToken;
      if (token != null && _currentUser != null) {
        await _saveSession(
          _currentUser!,
          token,
          refreshToken: ApiClient().refreshToken,
        );
      }
      return {'success': true, 'user': _currentUser};
    }
    return {
      'success': false,
      'statusCode': response['statusCode'],
      'errorCode': response['errorCode'],
      'message': response['message'] ?? 'Không thể tải thông tin trang cá nhân'
    };
  }

  Future<Map<String, dynamic>> updateProfile({
    String? fullName,
    String? phone,
    String? address,
    String? dob,
    String? city,
    String? avatarUrl,
    String? bio,
  }) async {
    final Map<String, dynamic> body = {};
    if (fullName != null) body['full_name'] = fullName;
    if (phone != null) body['phone'] = phone;
    if (address != null) body['address'] = address;
    if (dob != null) body['dob'] = dob;
    if (city != null) body['city'] = city;
    if (avatarUrl != null) body['avatar_url'] = avatarUrl;
    if (bio != null) body['bio'] = bio;

    final response = await ApiClient().patch('/users/me', body);

    if (response['success'] == true && response['data'] != null) {
      _currentUser = UserModel.fromJson(response['data'], ApiClient().authToken);
      final token = ApiClient().authToken;
      if (token != null && _currentUser != null) {
        await _saveSession(_currentUser!, token);
      }
      return {
        'success': true,
        'user': _currentUser,
        'message': response['message'] ?? 'Cập nhật hồ sơ thành công'
      };
    }

    return {
      'success': false,
      'message': response['message'] ?? 'Cập nhật hồ sơ thất bại'
    };
  }

  /// Uploads avatar image file (bytes) to Cloudinary using server-side signature
  Future<Map<String, dynamic>> uploadAvatarImage({
    required List<int> imageBytes,
    required String fileName,
  }) async {
    try {
      // 1. Request signature from backend
      final sigRes = await ApiClient().post('/uploads/cloudinary/avatar/signature', {});
      if (sigRes['success'] != true || sigRes['data'] == null) {
        return {
          'success': false,
          'message': sigRes['message'] ?? 'Không thể lấy chữ ký xác thực tải ảnh từ máy chủ',
        };
      }

      final data = sigRes['data'];
      final uploadUrl = data['upload_url']?.toString();
      final fields = data['fields'] as Map<String, dynamic>?;

      if (uploadUrl == null || fields == null) {
        return {
          'success': false,
          'message': 'Cấu hình tải ảnh từ máy chủ không hợp lệ',
        };
      }

      // 2. Perform multipart upload directly to Cloudinary
      final request = http.MultipartRequest('POST', Uri.parse(uploadUrl));
      fields.forEach((key, val) {
        request.fields[key] = val.toString();
      });

      request.files.add(http.MultipartFile.fromBytes(
        'file',
        imageBytes,
        filename: fileName.isNotEmpty ? fileName : 'avatar.jpg',
      ));

      final streamedRes = await request.send().timeout(const Duration(seconds: 30));
      final responseBody = await streamedRes.stream.bytesToString();

      if (streamedRes.statusCode >= 200 && streamedRes.statusCode < 300) {
        final Map<String, dynamic> cldResult = jsonDecode(responseBody);
        final String? secureUrl = cldResult['secure_url'] ?? cldResult['url'];
        if (secureUrl != null && secureUrl.isNotEmpty) {
          return {
            'success': true,
            'url': secureUrl,
            'public_id': cldResult['public_id'],
          };
        }
      }

      try {
        final errJson = jsonDecode(responseBody);
        final errMsg = errJson['error']?['message'] ?? 'Không thể tải ảnh lên máy chủ lưu trữ';
        return {'success': false, 'message': errMsg};
      } catch (_) {
        return {'success': false, 'message': 'Lỗi tải ảnh (${streamedRes.statusCode})'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Lỗi khi kết nối tải ảnh: $e'};
    }
  }

  /// Uploads avatar image file and immediately saves it to user profile
  Future<Map<String, dynamic>> updateAvatarFromBytes({
    required List<int> imageBytes,
    required String fileName,
  }) async {
    final uploadRes = await uploadAvatarImage(imageBytes: imageBytes, fileName: fileName);
    if (uploadRes['success'] != true || uploadRes['url'] == null) {
      return uploadRes;
    }

    final newUrl = uploadRes['url'] as String;
    final updateRes = await updateProfile(avatarUrl: newUrl);
    if (updateRes['success'] == true) {
      return {
        'success': true,
        'url': newUrl,
        'user': updateRes['user'],
        'message': 'Cập nhật ảnh đại diện thành công!',
      };
    }
    return updateRes;
  }

  Future<Map<String, dynamic>> changePassword({
    String? currentPassword,
    required String newPassword,
  }) async {
    final Map<String, dynamic> body = {
      'newPassword': newPassword,
    };
    if (currentPassword != null && currentPassword.trim().isNotEmpty) {
      body['currentPassword'] = currentPassword.trim();
    }

    final response = await ApiClient().patch('/users/me/password', body);

    if (response['success'] == true) {
      if (_currentUser != null) {
        _currentUser = _currentUser!.copyWith(hasPassword: true);
        final token = ApiClient().authToken;
        if (token != null) {
          await _saveSession(_currentUser!, token);
        }
      }
      return {
        'success': true,
        'message': response['message'] ?? 'Đổi mật khẩu thành công'
      };
    }

    return {
      'success': false,
      'message': response['message'] ?? 'Đổi mật khẩu thất bại'
    };
  }

  Future<void> logout() async {
    try {
      if (ApiClient().refreshToken != null) {
        await ApiClient().post('/auth/logout', {}).timeout(const Duration(seconds: 3));
      }
    } catch (_) {}
    _currentUser = null;
    ApiClient().clearSession();
    await _clearSession();
    try {
      final GoogleSignIn googleSignIn = GoogleSignIn(
        serverClientId: ApiConfig.googleServerClientId,
      );
      await googleSignIn.signOut();
    } catch (_) {}
  }
}
