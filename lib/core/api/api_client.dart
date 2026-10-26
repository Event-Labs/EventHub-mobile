import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_config.dart';

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;
  ApiClient._internal();

  static const Duration _timeout = Duration(seconds: 10);

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

  Future<void> _ensureHostResolved() async {
    if (!ApiConfig.hasResolvedHost) {
      await ApiConfig.autoDetectWorkingHost();
    }
  }

  Future<bool> _tryFindWorkingHost() async {
    final host = await ApiConfig.autoDetectWorkingHost(forceRefresh: true);
    return host != null && host.isNotEmpty;
  }

  Future<dynamic> get(String path, {Map<String, String>? queryParams}) async {
    await _ensureHostResolved();
    try {
      final uri = _buildUri(path, queryParams);
      final response = await http.get(uri, headers: _headers).timeout(_timeout);
      return _processResponse(response);
    } catch (e) {
      if (await _tryFindWorkingHost()) {
        try {
          final retryUri = _buildUri(path, queryParams);
          final retryResp = await http.get(retryUri, headers: _headers).timeout(_timeout);
          return _processResponse(retryResp);
        } catch (retryErr) {
          return {'success': false, 'message': 'Không thể kết nối máy chủ backend (${ApiConfig.baseUrl}): $retryErr'};
        }
      }
      if (e is TimeoutException) {
        return {'success': false, 'message': 'Kết nối máy chủ quá thời gian (Timeout)'};
      }
      return {'success': false, 'message': 'Không thể kết nối máy chủ backend (${ApiConfig.baseUrl}): $e'};
    }
  }

  Future<dynamic> post(String path, Map<String, dynamic> body) async {
    await _ensureHostResolved();
    try {
      final uri = _buildUri(path);
      final response = await http.post(
        uri,
        headers: _headers,
        body: jsonEncode(body),
      ).timeout(_timeout);
      return _processResponse(response);
    } catch (e) {
      if (await _tryFindWorkingHost()) {
        try {
          final retryUri = _buildUri(path);
          final retryResp = await http.post(
            retryUri,
            headers: _headers,
            body: jsonEncode(body),
          ).timeout(_timeout);
          return _processResponse(retryResp);
        } catch (retryErr) {
          return {'success': false, 'message': 'Lỗi kết nối máy chủ (${ApiConfig.baseUrl}): $retryErr'};
        }
      }
      if (e is TimeoutException) {
        return {'success': false, 'message': 'Kết nối máy chủ quá thời gian (Timeout)'};
      }
      return {'success': false, 'message': 'Lỗi kết nối máy chủ (${ApiConfig.baseUrl}): $e'};
    }
  }

  Future<dynamic> patch(String path, Map<String, dynamic> body) async {
    await _ensureHostResolved();
    try {
      final uri = _buildUri(path);
      final response = await http.patch(
        uri,
        headers: _headers,
        body: jsonEncode(body),
      ).timeout(_timeout);
      return _processResponse(response);
    } catch (e) {
      if (await _tryFindWorkingHost()) {
        try {
          final retryUri = _buildUri(path);
          final retryResp = await http.patch(
            retryUri,
            headers: _headers,
            body: jsonEncode(body),
          ).timeout(_timeout);
          return _processResponse(retryResp);
        } catch (retryErr) {
          return {'success': false, 'message': 'Lỗi kết nối máy chủ (${ApiConfig.baseUrl}): $retryErr'};
        }
      }
      if (e is TimeoutException) {
        return {'success': false, 'message': 'Kết nối máy chủ quá thời gian (Timeout)'};
      }
      return {'success': false, 'message': 'Lỗi kết nối máy chủ (${ApiConfig.baseUrl}): $e'};
    }
  }

  Future<dynamic> put(String path, Map<String, dynamic> body) async {
    await _ensureHostResolved();
    try {
      final uri = _buildUri(path);
      final response = await http.put(
        uri,
        headers: _headers,
        body: jsonEncode(body),
      ).timeout(_timeout);
      return _processResponse(response);
    } catch (e) {
      if (await _tryFindWorkingHost()) {
        try {
          final retryUri = _buildUri(path);
          final retryResp = await http.put(
            retryUri,
            headers: _headers,
            body: jsonEncode(body),
          ).timeout(_timeout);
          return _processResponse(retryResp);
        } catch (retryErr) {
          return {'success': false, 'message': 'Lỗi kết nối máy chủ (${ApiConfig.baseUrl}): $retryErr'};
        }
      }
      if (e is TimeoutException) {
        return {'success': false, 'message': 'Kết nối máy chủ quá thời gian (Timeout)'};
      }
      return {'success': false, 'message': 'Lỗi kết nối máy chủ (${ApiConfig.baseUrl}): $e'};
    }
  }

  Future<dynamic> delete(String path, {Map<String, dynamic>? body}) async {
    await _ensureHostResolved();
    try {
      final uri = _buildUri(path);
      final response = await http.delete(
        uri,
        headers: _headers,
        body: body != null ? jsonEncode(body) : null,
      ).timeout(_timeout);
      return _processResponse(response);
    } catch (e) {
      if (await _tryFindWorkingHost()) {
        try {
          final retryUri = _buildUri(path);
          final retryResp = await http.delete(
            retryUri,
            headers: _headers,
            body: body != null ? jsonEncode(body) : null,
          ).timeout(_timeout);
          return _processResponse(retryResp);
        } catch (retryErr) {
          return {'success': false, 'message': 'Lỗi kết nối máy chủ (${ApiConfig.baseUrl}): $retryErr'};
        }
      }
      if (e is TimeoutException) {
        return {'success': false, 'message': 'Kết nối máy chủ quá thời gian (Timeout)'};
      }
      return {'success': false, 'message': 'Lỗi kết nối máy chủ (${ApiConfig.baseUrl}): $e'};
    }
  }

  dynamic _processResponse(http.Response response) {
    try {
      final body = jsonDecode(utf8.decode(response.bodyBytes));
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return body;
      } else {
        String msg = body['message'] ?? 'Thao tác không thành công (${response.statusCode})';
        if (body['error'] is Map && body['error']['details'] is List && (body['error']['details'] as List).isNotEmpty) {
          final firstDetail = (body['error']['details'] as List).first;
          if (firstDetail is Map && firstDetail['message'] != null) {
            msg = firstDetail['message'].toString();
          }
        }
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
