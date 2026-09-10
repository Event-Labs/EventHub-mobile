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

  Future<Map<String, dynamic>> register({
    required String fullName,
    required String email,
    required String password,
    String? phone,
  }) async {
    final response = await ApiClient().post(ApiConfig.register, {
      'full_name': fullName,
      'email': email,
      'password': password,
      'phone': phone,
    });

    if (response['success'] == true) {
      return {'success': true, 'message': response['message'] ?? 'Đăng ký tài khoản thành công'};
    }

    return {'success': false, 'message': response['message'] ?? 'Đăng ký thất bại'};
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

  void logout() {
    _currentUser = null;
    ApiClient().setAuthToken(null);
  }
}
