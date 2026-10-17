import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_config.dart';

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;
  ApiClient._internal();

  String? _authToken;

  void setAuthToken(String? token) {
    _authToken = token;
  }

  String? get authToken => _authToken;

  Map<String, String> get _headers {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (_authToken != null && _authToken!.isNotEmpty) {
      headers['Authorization'] = 'Bearer $_authToken';
    }
    return headers;
  }

  Future<dynamic> get(String path, {Map<String, String>? queryParams}) async {
    try {
      Uri uri = Uri.parse('${ApiConfig.baseUrl}$path');
      if (queryParams != null && queryParams.isNotEmpty) {
        uri = uri.replace(queryParameters: queryParams);
      }
      final response = await http.get(uri, headers: _headers);
      return _processResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Không thể kết nối máy chủ backend: $e'};
    }
  }

  Future<dynamic> post(String path, Map<String, dynamic> body) async {
    try {
      final uri = Uri.parse('${ApiConfig.baseUrl}$path');
      final response = await http.post(
        uri,
        headers: _headers,
        body: jsonEncode(body),
      );
      return _processResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Lỗi kết nối máy chủ: $e'};
    }
  }

  Future<dynamic> patch(String path, Map<String, dynamic> body) async {
    try {
      final uri = Uri.parse('${ApiConfig.baseUrl}$path');
      final response = await http.patch(
        uri,
        headers: _headers,
        body: jsonEncode(body),
      );
      return _processResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Lỗi kết nối máy chủ: $e'};
    }
  }

  Future<dynamic> put(String path, Map<String, dynamic> body) async {
    try {
      final uri = Uri.parse('${ApiConfig.baseUrl}$path');
      final response = await http.put(
        uri,
        headers: _headers,
        body: jsonEncode(body),
      );
      return _processResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Lỗi kết nối máy chủ: $e'};
    }
  }

  Future<dynamic> delete(String path, {Map<String, dynamic>? body}) async {
    try {
      final uri = Uri.parse('${ApiConfig.baseUrl}$path');
      final response = await http.delete(
        uri,
        headers: _headers,
        body: body != null ? jsonEncode(body) : null,
      );
      return _processResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Lỗi kết nối máy chủ: $e'};
    }
  }

  dynamic _processResponse(http.Response response) {
    try {
      final body = jsonDecode(utf8.decode(response.bodyBytes));
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return body;
      } else {
        final msg = body['message'] ?? 'Thao tác không thành công (${response.statusCode})';
        return {
          'success': false,
          'message': msg,
          'error': body['error'],
        };
      }
    } catch (e) {
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return {'success': true, 'data': response.body};
      }
      return {
        'success': false,
        'message': 'Lỗi phản hồi máy chủ (${response.statusCode})',
      };
    }
  }
}
