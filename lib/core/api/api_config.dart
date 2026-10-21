import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';

class ApiConfig {
  // Environment overrides via --dart-define
  static const String _envBaseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: '');
  static const String _envHost = String.fromEnvironment('API_HOST', defaultValue: '');
  static const String _envPort = String.fromEnvironment('API_PORT', defaultValue: '3000');
  static const String _envProtocol = String.fromEnvironment('API_PROTOCOL', defaultValue: 'http');

  // Dynamic host override if detected or switched at runtime
  static String? _dynamicHost;
  static void setDynamicHost(String? host) {
    _dynamicHost = host;
  }

  static bool get hasResolvedHost => (_dynamicHost != null && _dynamicHost!.isNotEmpty) || _envHost.trim().isNotEmpty;

  /// List of candidate backend hosts for auto-fallback on physical devices or emulators
  static List<String> get candidateHosts {
    final list = <String>[];
    if (_dynamicHost != null && _dynamicHost!.isNotEmpty) {
      list.add(_dynamicHost!);
    }
    if (_envHost.trim().isNotEmpty) {
      final h = apiHost;
      if (!list.contains(h)) list.add(h);
    }
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      // 1. USB with adb reverse tcp:3000 tcp:3000 (Physical Android)
      if (!list.contains('127.0.0.1')) list.add('127.0.0.1');
      // 2. Android Studio Emulator host loopback to PC
      if (!list.contains('10.0.2.2')) list.add('10.0.2.2');
      // 3. Local Wi-Fi network host IP (Direct PC connection)
      if (!list.contains('192.168.1.174')) list.add('192.168.1.174');
    } else {
      if (!list.contains('localhost')) list.add('localhost');
      if (!list.contains('127.0.0.1')) list.add('127.0.0.1');
    }
    return list;
  }

  static bool _isDetecting = false;

  /// Parallel probe across candidate hosts:
  /// - Detects 10.0.2.2 on Android Studio Emulator in ~5ms
  /// - Detects 127.0.0.1 on USB with adb reverse in ~2ms
  /// - Detects 192.168.1.174 on local Wi-Fi in ~15ms
  static Future<String?> autoDetectWorkingHost({bool forceRefresh = false}) async {
    if (kIsWeb) return 'localhost';
    if (_envHost.trim().isNotEmpty) {
      return apiHost;
    }
    if (!forceRefresh && _dynamicHost != null && _dynamicHost!.isNotEmpty) {
      return _dynamicHost;
    }
    if (_isDetecting) return _dynamicHost;
    _isDetecting = true;

    try {
      final candidates = candidateHosts;
      final port = apiPort;

      final completer = Completer<String?>();
      int pending = candidates.length;

      for (final host in candidates) {
        Socket.connect(host, port, timeout: const Duration(milliseconds: 1200)).then((socket) {
          socket.destroy();
          if (!completer.isCompleted) {
            _dynamicHost = host;
            completer.complete(host);
          }
        }).catchError((_) {
          pending--;
          if (pending <= 0 && !completer.isCompleted) {
            completer.complete(null);
          }
        });
      }

      final result = await completer.future.timeout(
        const Duration(milliseconds: 1400),
        onTimeout: () => null,
      );
      return result ?? _dynamicHost;
    } catch (_) {
      return _dynamicHost;
    } finally {
      _isDetecting = false;
    }
  }

  /// Resolves the active backend host:
  /// - flutter run -d 9887bc424b565a3853 --dart-define=API_HOST=192.168.1.174
  /// - Takes dynamic runtime host if set
  /// - Takes value from --dart-define=API_HOST if provided (e.g. 10.0.2.2, 127.0.0.1)
  /// - Defaults to 'localhost' on Web or Desktop
  /// - Defaults to '10.0.2.2' on Android (Android Emulator host alias)
  static String get apiHost {
    if (_dynamicHost != null && _dynamicHost!.isNotEmpty) {
      return _dynamicHost!;
    }
    final rawHost = _envHost.trim();
    if (rawHost.isNotEmpty) {
      String clean = rawHost;
      if (clean.startsWith('http://')) {
        clean = clean.substring(7);
      } else if (clean.startsWith('https://')) {
        clean = clean.substring(8);
      }
      if (clean.contains(':')) {
        clean = clean.split(':').first;
      }
      if (clean.contains('/')) {
        clean = clean.split('/').first;
      }
      return clean.trim();
    }

    if (kIsWeb) {
      return 'localhost';
    }
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return '127.0.0.1'; // USB default host; auto-probes 192.168.1.174 & 10.0.2.2 if unreachable
    }
    return 'localhost';
  }

  /// Resolves the active backend port (defaults to 3000)
  static int get apiPort {
    final rawHost = _envHost.trim();
    if (rawHost.contains(':')) {
      final sanitized = rawHost.replaceAll('http://', '').replaceAll('https://', '').split('/');
      final hostPort = sanitized.first.split(':');
      if (hostPort.length > 1) {
        final parsed = int.tryParse(hostPort[1]);
        if (parsed != null && parsed > 0) return parsed;
      }
    }
    return int.tryParse(_envPort) ?? 3000;
  }

  /// Resolves the active backend protocol (http or https)
  static String get apiProtocol {
    final rawHost = _envHost.trim();
    if (rawHost.startsWith('https://') || _envBaseUrl.trim().startsWith('https://')) {
      return 'https';
    }
    return _envProtocol.trim().isNotEmpty ? _envProtocol.trim() : 'http';
  }

  /// Base URL for backend API requests, always ending with '/api' without trailing slash.
  /// Example:
  /// - Android Emulator default: http://10.0.2.2:3000/api
  /// - Physical device (Samsung S8 with adb reverse): http://127.0.0.1:3000/api
  /// - Web default: http://localhost:3000/api
  static String get baseUrl {
    final customUrl = _envBaseUrl.trim();
    if (customUrl.isNotEmpty) {
      var normalized = customUrl;
      while (normalized.endsWith('/')) {
        normalized = normalized.substring(0, normalized.length - 1);
      }
      if (!normalized.endsWith('/api')) {
        normalized = '$normalized/api';
      }
      return normalized;
    }

    return '$apiProtocol://$apiHost:$apiPort/api';
  }

  // Endpoints
  static const String login = '/auth/login';
  static const String register = '/auth/register';
  static const String verifyEmail = '/auth/verify-email';
  static const String forgotPassword = '/auth/forgot-password';
  static const String resetPassword = '/auth/reset-password';
  static const String googleLogin = '/auth/google';
  static const String logout = '/auth/logout';
  static const String userProfile = '/users/me';
  static const String userPassword = '/users/me/password';

  // Google OAuth Web Client ID (configured in backend GOOGLE_CLIENT_ID)
  static const String googleServerClientId = '872381042707-han4prvt3866lm00e9tsakad4oerhtoj.apps.googleusercontent.com';

  // Events & Categories & Favorites & Organizers
  static const String events = '/events';
  static const String categories = '/events/categories';
  static const String organizers = '/events/organizers';
  static const String favoriteEvents = '/events/favorites/me';
  static String toggleFavorite(String eventId) => '/events/$eventId/favorite/toggle';

  // Orders & Booking (PayOS)
  static const String orders = '/orders';
  static const String checkout = '/orders/checkout';
  static String orderStatus(String orderId) => '/orders/$orderId/status';
  static String cancelOrder(String orderId) => '/orders/$orderId/cancel';
  static String availablePromotions(String eventId) => '/promotions/public/events/$eventId/available';

  // Tickets
  static const String myTickets = '/tickets/me';
  static String ticketDetail(String ticketId) => '/tickets/$ticketId';
  static String ticketDownload(String ticketId) => '/tickets/$ticketId/download';

  // Refunds
  static const String refunds = '/refunds';
  static const String refundPreview = '/refunds/preview';
  static const String myRefunds = '/refunds/my-requests';
  static String refundDetail(String id) => '/refunds/$id';

  // Feedbacks
  static const String feedbacks = '/feedbacks';
  static const String feedbackEligible = '/feedbacks/eligible-events';

  // Notifications
  static const String notifications = '/notifications';
  static const String notificationsUnreadCount = '/notifications/unread-count';
  static const String notificationsReadAll = '/notifications/read-all';
  static String markNotificationRead(String id) => '/notifications/$id/read';

  // Staff Portal
  static const String staffOverview = '/operations/staff/overview';
  static const String staffAssignedEvents = '/operations/staff/events';
  static String staffCheckInReport([String? eventId]) =>
      eventId != null && eventId.isNotEmpty
          ? '/operations/staff/check-in-report?eventId=$eventId'
          : '/operations/staff/check-in-report';
  static const String staffVerifyQr = '/staff/tickets/verify-qr';
  static const String staffCheckInQr = '/staff/tickets/check-in/qr';
  static const String staffSearchTickets = '/staff/tickets/search';
  static String staffTicketDetail(String ticketId) => '/staff/tickets/$ticketId';
  static String staffCheckInTicket(String ticketId) => '/staff/tickets/$ticketId/check-in';
  static const String staffDirectBookingEvents = '/orders/staff/direct-booking/events';
  static const String staffDirectBooking = '/orders/staff/direct-booking';
  static String staffDirectBookingStatus(String orderId) => '/orders/staff/direct-booking/$orderId/status';

  // AI Assistant
  static const String aiChat = '/ai-assistant/chat';
  static const String aiSessions = '/ai-assistant/sessions';
  static String deleteAiSession(String sessionId) => '/ai-assistant/sessions/$sessionId';
}
