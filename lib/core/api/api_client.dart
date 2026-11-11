import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'api_config.dart';

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;
  ApiClient._internal();

  http.Client _httpClient = http.Client();
  String? _token;
  String? _refreshToken;
  Future<bool>? _refreshFuture;
  void Function(String? accessToken, String? refreshToken)? _onTokensUpdated;
  Future<void> Function()? _onAuthExpired;

  static const Duration _timeout = Duration(seconds: 15);
  static const String _refreshEndpoint = '/auth/refresh';
  static const String _logoutEndpoint = '/auth/logout';

  String? get authToken => _token;
  String? get refreshToken => _refreshToken;

  void setToken(String? token) {
    _token = token;
  }

  void setAuthToken(String? token) {
    _token = token;
  }

  void setRefreshToken(String? refreshToken) {
    _refreshToken = (refreshToken != null && refreshToken.trim().isNotEmpty)
        ? refreshToken.trim()
        : null;
  }

  void setAuthTokens({String? accessToken, String? refreshToken}) {
    _token = (accessToken != null && accessToken.trim().isNotEmpty)
        ? accessToken.trim()
        : null;
    if (refreshToken != null) {
      setRefreshToken(refreshToken);
    }
  }

  void clearToken() {
    _token = null;
  }

  void clearSession() {
    _token = null;
    _refreshToken = null;
  }

  void setSessionCallbacks({
    void Function(String? accessToken, String? refreshToken)? onTokensUpdated,
    Future<void> Function()? onAuthExpired,
  }) {
    _onTokensUpdated = onTokensUpdated;
    _onAuthExpired = onAuthExpired;
  }

  @visibleForTesting
  void setHttpClientForTesting(http.Client client) {
    _httpClient = client;
  }

  @visibleForTesting
  void resetForTesting() {
    _httpClient = http.Client();
    _token = null;
    _refreshToken = null;
    _refreshFuture = null;
    _onTokensUpdated = null;
    _onAuthExpired = null;
  }

  /// Extracts `refresh_token` value from an HTTP `Set-Cookie` header.
  static String? extractRefreshTokenFromSetCookie(String? setCookieHeader) {
    if (setCookieHeader == null || setCookieHeader.isEmpty) return null;
    final match = RegExp(
      r'(?:^|,\s*|\s)refresh_token=([^;\s,]+)',
      caseSensitive: false,
    ).firstMatch(setCookieHeader);
    final value = match?.group(1)?.trim();
    if (value == null || value.isEmpty) return null;
    try {
      return Uri.decodeComponent(value);
    } catch (_) {
      return value;
    }
  }

  /// Checks whether a JWT access token is expired (comparing `exp` against `now + skew`).
  static bool isJwtExpired(
    String? token, {
    Duration skew = Duration.zero,
    DateTime? now,
  }) {
    if (token == null || token.trim().isEmpty) return false;
    try {
      final parts = token.trim().split('.');
      if (parts.length != 3) return false;
      final normalized = base64Url.normalize(parts[1]);
      final payloadJson = utf8.decode(base64Url.decode(normalized));
      final payload = jsonDecode(payloadJson);
      if (payload is! Map || payload['exp'] == null) return false;
      final expRaw = payload['exp'];
      final expSeconds = expRaw is num
          ? expRaw.toInt()
          : int.tryParse(expRaw.toString());
      if (expSeconds == null) return false;
      final expiry = DateTime.fromMillisecondsSinceEpoch(expSeconds * 1000, isUtc: true);
      final current = (now ?? DateTime.now()).toUtc().add(skew);
      return !current.isBefore(expiry);
    } catch (_) {
      return false;
    }
  }

  static String _normalizePath(String path) {
    String clean = path.trim();
    if (clean.startsWith('/api/')) {
      clean = clean.substring(4);
    } else if (clean == '/api') {
      clean = '';
    } else if (clean.startsWith('api/')) {
      clean = clean.substring(3);
    }
    if (clean.isNotEmpty && !clean.startsWith('/')) {
      clean = '/$clean';
    }
    final qIndex = clean.indexOf('?');
    return qIndex >= 0 ? clean.substring(0, qIndex) : clean;
  }

  static bool _isCookieIssuingAuthPath(String path) {
    final normalized = _normalizePath(path);
    return normalized == '/auth/login' ||
        normalized == '/auth/google' ||
        normalized == '/auth/refresh' ||
        normalized == '/auth/verify-login-otp' ||
        normalized == '/auth/verify-admin-otp';
  }

  static bool _isAuthNoRefreshPath(String path) {
    final normalized = _normalizePath(path);
    return _isCookieIssuingAuthPath(normalized) ||
        normalized == '/auth/register' ||
        normalized == '/auth/logout' ||
        normalized == '/auth/forgot-password' ||
        normalized == '/auth/reset-password' ||
        normalized == '/auth/verify-email';
  }

  Map<String, String> _buildHeaders({bool includeAuth = true, bool includeRefreshCookie = false}) {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (includeAuth && _token != null && _token!.isNotEmpty) {
      headers['Authorization'] = 'Bearer $_token';
    }
    if (includeRefreshCookie && _refreshToken != null && _refreshToken!.isNotEmpty) {
      headers['Cookie'] = 'refresh_token=$_refreshToken';
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
      final merged = <String, String>{...uri.queryParameters, ...queryParams};
      uri = uri.replace(queryParameters: merged);
    }
    return uri;
  }

  void _captureAuthTokensFromResponse(http.Response response, {dynamic decodedBody}) {
    final setCookie = response.headers['set-cookie'];
    final extractedCookie = extractRefreshTokenFromSetCookie(setCookie);
    String? newRefresh = extractedCookie;
    String? newAccess;

    if (decodedBody is Map && decodedBody['data'] is Map) {
      final data = decodedBody['data'] as Map;
      final token = data['accessToken']?.toString();
      if (token != null && token.isNotEmpty) {
        newAccess = token;
      }
      final bodyRefresh = data['refreshToken']?.toString();
      if (newRefresh == null && bodyRefresh != null && bodyRefresh.isNotEmpty) {
        newRefresh = bodyRefresh;
      }
    }

    if (newAccess != null || newRefresh != null) {
      if (newAccess != null) _token = newAccess;
      if (newRefresh != null) _refreshToken = newRefresh;
      _onTokensUpdated?.call(_token, _refreshToken);
    }
  }

  /// Refreshes the JWT access token using the stored `refresh_token` cookie (coalescing concurrent calls).
  Future<bool> refreshAccessToken() async {
    if (_refreshToken == null || _refreshToken!.isEmpty) {
      return false;
    }

    if (_refreshFuture != null) {
      return _refreshFuture!;
    }

    final completer = Completer<bool>();
    _refreshFuture = completer.future;

    try {
      final uri = _buildUri(_refreshEndpoint);
      final response = await _httpClient
          .post(
            uri,
            headers: _buildHeaders(includeAuth: false, includeRefreshCookie: true),
            body: jsonEncode({}),
          )
          .timeout(_timeout);

      dynamic decoded;
      try {
        decoded = jsonDecode(utf8.decode(response.bodyBytes));
      } catch (_) {}

      if (response.statusCode >= 200 &&
          response.statusCode < 300 &&
          decoded is Map &&
          decoded['data'] is Map &&
          decoded['data']['accessToken'] != null) {
        _captureAuthTokensFromResponse(response, decodedBody: decoded);
        debugPrint('[ApiClient] Access token refreshed cleanly.');
        completer.complete(true);
        return true;
      }

      debugPrint('[ApiClient] POST $_refreshEndpoint -> ${response.statusCode} failed.');
      if (response.statusCode == 401 || response.statusCode == 403) {
        clearSession();
        if (_onAuthExpired != null) {
          await _onAuthExpired!();
        }
      }
      completer.complete(false);
      return false;
    } catch (e) {
      debugPrint('[ApiClient] refreshAccessToken error: $e');
      completer.complete(false);
      return false;
    } finally {
      _refreshFuture = null;
    }
  }

  Future<http.Response> _dispatchHttp(
    String method,
    Uri uri,
    Map<String, String> headers,
    Map<String, dynamic>? body,
  ) {
    switch (method) {
      case 'GET':
        return _httpClient.get(uri, headers: headers).timeout(_timeout);
      case 'POST':
        return _httpClient
            .post(uri, headers: headers, body: jsonEncode(body ?? const {}))
            .timeout(_timeout);
      case 'PATCH':
        return _httpClient
            .patch(uri, headers: headers, body: jsonEncode(body ?? const {}))
            .timeout(_timeout);
      case 'PUT':
        return _httpClient
            .put(uri, headers: headers, body: jsonEncode(body ?? const {}))
            .timeout(_timeout);
      case 'DELETE':
        return _httpClient
            .delete(uri, headers: headers, body: body != null ? jsonEncode(body) : null)
            .timeout(_timeout);
      default:
        throw ArgumentError('Unsupported HTTP method: $method');
    }
  }

  Future<dynamic> _sendRequest(
    String method,
    String path, {
    Map<String, String>? queryParams,
    Map<String, dynamic>? body,
    bool retryOnUnauthorized = true,
  }) async {
    final isAuthEndpoint = _isAuthNoRefreshPath(path);
    final normalizedPath = _normalizePath(path);
    final includeCookie = normalizedPath == _refreshEndpoint || normalizedPath == _logoutEndpoint;

    // Proactively refresh expired access token before hitting protected routes
    if (!isAuthEndpoint &&
        _token != null &&
        _token!.isNotEmpty &&
        _refreshToken != null &&
        _refreshToken!.isNotEmpty &&
        isJwtExpired(_token, skew: const Duration(seconds: 30))) {
      await refreshAccessToken();
    }

    try {
      final uri = _buildUri(path, queryParams);
      final hadAuthToken = _token != null && _token!.isNotEmpty;

      http.Response response = await _dispatchHttp(
        method,
        uri,
        _buildHeaders(includeAuth: true, includeRefreshCookie: includeCookie),
        body,
      );

      if (response.statusCode == 401 && retryOnUnauthorized && !isAuthEndpoint && hadAuthToken) {
        final refreshed = await refreshAccessToken();
        if (refreshed) {
          response = await _dispatchHttp(
            method,
            uri,
            _buildHeaders(includeAuth: true, includeRefreshCookie: includeCookie),
            body,
          );
        } else if (_onAuthExpired != null) {
          clearSession();
          await _onAuthExpired!();
        }
      }

      return _processResponse(
        response,
        method: method,
        path: path,
        captureCookies: _isCookieIssuingAuthPath(path),
      );
    } catch (e) {
      final isTimeout = e is TimeoutException;
      debugPrint('[ApiClient] $method $path exception: $e');
      if (isTimeout) {
        return {'success': false, 'message': 'Kết nối máy chủ quá thời gian (Timeout)'};
      }
      return {
        'success': false,
        'message': method == 'GET' ? 'Không thể kết nối máy chủ backend: $e' : 'Lỗi kết nối máy chủ: $e',
      };
    }
  }

  Future<dynamic> get(String path, {Map<String, String>? queryParams}) =>
      _sendRequest('GET', path, queryParams: queryParams);

  Future<dynamic> post(String path, Map<String, dynamic> body) =>
      _sendRequest('POST', path, body: body);

  Future<dynamic> patch(String path, Map<String, dynamic> body) =>
      _sendRequest('PATCH', path, body: body);

  Future<dynamic> put(String path, Map<String, dynamic> body) =>
      _sendRequest('PUT', path, body: body);

  Future<dynamic> delete(String path, {Map<String, dynamic>? body}) =>
      _sendRequest('DELETE', path, body: body);

  dynamic _processResponse(
    http.Response response, {
    String? method,
    String? path,
    bool captureCookies = false,
  }) {
    try {
      final body = jsonDecode(utf8.decode(response.bodyBytes));
      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (captureCookies) {
          _captureAuthTokensFromResponse(response, decodedBody: body);
        }
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
        final errCode = body is Map ? body['errorCode'] : null;
        debugPrint('[ApiClient] ${method ?? 'HTTP'} ${path ?? ''} -> ${response.statusCode} ($errCode): $msg');
        return {
          'success': false,
          'statusCode': response.statusCode,
          'message': msg,
          'errorCode': errCode,
          'data': body is Map ? body['data'] : null,
          'error': body is Map ? body['error'] : null,
        };
      }
    } catch (e) {
      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (captureCookies) {
          _captureAuthTokensFromResponse(response);
        }
        return {'success': true, 'data': response.body};
      }
      debugPrint('[ApiClient] ${method ?? 'HTTP'} ${path ?? ''} -> ${response.statusCode} non-JSON response');
      return {
        'success': false,
        'statusCode': response.statusCode,
        'message': 'Lỗi phản hồi máy chủ (${response.statusCode})',
      };
    }
  }
}
