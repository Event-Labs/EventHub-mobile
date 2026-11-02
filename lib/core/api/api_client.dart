import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_config.dart';

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;
  ApiClient._internal();

  String? _token;
  static const Duration _timeout = Duration(seconds: 15);

  String? get authToken => _token;

  void setToken(String? token) {
    _token = token;
  }

  void setAuthToken(String? token) {
    _token = token;
  }

  void clearToken() {
    _token = null;
  }

  Map<String, String> get _headers {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (_token != null && _token!.isNotEmpty) {
      headers['Authorization'] = 'Bearer $_token';
    }
    return headers;
  }

  Uri _buildUri(String path, [Map<String, String>? queryParams]) {
    final base = ApiConfig.baseUrl;
    String cleanPath = path.trim();

    if (cleanPath.startsWith('/api/')) {
      cleanPath = cleanPath.substring(4);
    } else if (cleanPath == '/api') {
      cleanPath = '';
    } else if (cleanPath.startsWith('api/')) {
      cleanPath = cleanPath.substring(3);
    }

    if (cleanPath.isNotEmpty && !cleanPath.startsWith('/')) {
      cleanPath = '/$cleanPath';
    }

    Uri uri = Uri.parse('$base$cleanPath');
    if (queryParams != null && queryParams.isNotEmpty) {
      uri = uri.replace(queryParameters: queryParams);
    }
    return uri;
  }

  Future<dynamic> get(String path, {Map<String, String>? queryParams}) async {
    try {
      final uri = _buildUri(path, queryParams);
      final response = await http.get(uri, headers: _headers).timeout(_timeout);
      return _processResponse(response);
    } catch (e) {
      if (e is TimeoutException) {
        return {'success': false, 'message': 'Kết nối máy chủ quá thời gian (Timeout)'};
      }
      return {'success': false, 'message': 'Không thể kết nối máy chủ backend: $e'};
    }
  }

  Future<dynamic> post(String path, Map<String, dynamic> body) async {
    try {
      final uri = _buildUri(path);
      final response = await http.post(
        uri,
        headers: _headers,
        body: jsonEncode(body),
      ).timeout(_timeout);
      return _processResponse(response);
    } catch (e) {
      if (e is TimeoutException) {
        return {'success': false, 'message': 'Kết nối máy chủ quá thời gian (Timeout)'};
      }
      return {'success': false, 'message': 'Lỗi kết nối máy chủ: $e'};
    }
  }

  Future<dynamic> patch(String path, Map<String, dynamic> body) async {
    try {
      final uri = _buildUri(path);
      final response = await http.patch(
        uri,
        headers: _headers,
        body: jsonEncode(body),
      ).timeout(_timeout);
      return _processResponse(response);
    } catch (e) {
      if (e is TimeoutException) {
        return {'success': false, 'message': 'Kết nối máy chủ quá thời gian (Timeout)'};
      }
      return {'success': false, 'message': 'Lỗi kết nối máy chủ: $e'};
    }
  }

  Future<dynamic> put(String path, Map<String, dynamic> body) async {
    try {
      final uri = _buildUri(path);
      final response = await http.put(
        uri,
        headers: _headers,
        body: jsonEncode(body),
      ).timeout(_timeout);
      return _processResponse(response);
    } catch (e) {
      if (e is TimeoutException) {
        return {'success': false, 'message': 'Kết nối máy chủ quá thời gian (Timeout)'};
      }
      return {'success': false, 'message': 'Lỗi kết nối máy chủ: $e'};
    }
  }

  Future<dynamic> delete(String path, {Map<String, dynamic>? body}) async {
    try {
      final uri = _buildUri(path);
      final response = await http.delete(
        uri,
        headers: _headers,
        body: body != null ? jsonEncode(body) : null,
      ).timeout(_timeout);
      return _processResponse(response);
    } catch (e) {
      if (e is TimeoutException) {
        return {'success': false, 'message': 'Kết nối máy chủ quá thời gian (Timeout)'};
      }
      return {'success': false, 'message': 'Lỗi kết nối máy chủ: $e'};
    }
  }

  dynamic _processResponse(http.Response response) {
    try {
      final body = jsonDecode(utf8.decode(response.bodyBytes));
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return body;
      } else {
        String msg = 'Thao tác không thành công (${response.statusCode})';
        if (body is Map) {
          if (body['message'] is String && (body['message'] as String).isNotEmpty) {
            msg = body['message'];
          } else if (body['message'] is List) {
            msg = (body['message'] as List).join(', ');
          }
          if (body['error'] is Map && body['error']['details'] is List && (body['error']['details'] as List).isNotEmpty) {
            final firstDetail = (body['error']['details'] as List).first;
            if (firstDetail is Map && firstDetail['message'] != null) {
              msg = firstDetail['message'].toString();
            }
          }
        }
        return {
          'success': false,
          'message': msg,
          'error': body is Map ? body['error'] : null,
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
