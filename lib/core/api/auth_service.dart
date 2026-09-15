import 'package:google_sign_in/google_sign_in.dart';
import '../models/user_model.dart';
import 'api_client.dart';
import 'api_config.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  UserModel? _currentUser;

  UserModel? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final response = await ApiClient().post(ApiConfig.login, {
      'email': email,
      'password': password,
    });

    if (response['success'] == true && response['data'] != null) {
      final data = response['data'];
      final token = data['accessToken']?.toString();
      if (token != null) {
        ApiClient().setAuthToken(token);
      }
      if (data['user'] != null) {
        _currentUser = UserModel.fromJson(data['user']);
      }
      return {'success': true, 'user': _currentUser, 'message': response['message'] ?? 'Đăng nhập thành công'};
    }

    return {'success': false, 'message': response['message'] ?? 'Đăng nhập thất bại'};
  }

  Future<Map<String, dynamic>> loginWithGoogle() async {
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
        final token = data['accessToken']?.toString();
        if (token != null) {
          ApiClient().setAuthToken(token);
        }
        if (data['user'] != null) {
          _currentUser = UserModel.fromJson(data['user']);
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
      _currentUser = UserModel.fromJson(response['data']);
      return {'success': true, 'user': _currentUser};
    }
    return {
      'success': false,
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
      _currentUser = UserModel.fromJson(response['data']);
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

  Future<Map<String, dynamic>> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final response = await ApiClient().patch('/users/me/password', {
      'currentPassword': currentPassword,
      'newPassword': newPassword,
    });

    if (response['success'] == true) {
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
    _currentUser = null;
    ApiClient().setAuthToken(null);
    try {
      final GoogleSignIn googleSignIn = GoogleSignIn(
        serverClientId: ApiConfig.googleServerClientId,
      );
      await googleSignIn.signOut();
    } catch (_) {}
  }
}

