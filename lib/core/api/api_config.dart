class ApiConfig {
  // Fixed backend configuration for EventHub
  static const String defaultHost = 'api.eventhub.id.vn';
  static const String defaultBaseUrl = 'https://api.eventhub.id.vn/api';

  // Environment overrides via --dart-define if explicitly provided
  static const String _envBaseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: '');
  static const String _envHost = String.fromEnvironment('API_HOST', defaultValue: '');
  static String? _customBaseUrl;

  /// Dynamically set custom base URL (e.g. for local testing with web backend)
  static void setCustomBaseUrl(String? url) {
    if (url == null || url.trim().isEmpty) {
      _customBaseUrl = null;
      return;
    }
    var normalized = url.trim();
    while (normalized.endsWith('/')) {
      normalized = normalized.substring(0, normalized.length - 1);
    }
    if (!normalized.endsWith('/api')) {
      normalized = '$normalized/api';
    }
    _customBaseUrl = normalized;
  }

  static String get apiHost {
    if (_customBaseUrl != null && _customBaseUrl!.isNotEmpty) {
      final uri = Uri.tryParse(_customBaseUrl!);
      if (uri != null && uri.host.isNotEmpty) return uri.host;
    }
    if (_envHost.trim().isNotEmpty) return _envHost.trim();
    return defaultHost;
  }

  static String get baseUrl {
    if (_customBaseUrl != null && _customBaseUrl!.isNotEmpty) {
      return _customBaseUrl!;
    }
    if (_envBaseUrl.trim().isNotEmpty) {
      var normalized = _envBaseUrl.trim();
      while (normalized.endsWith('/')) {
        normalized = normalized.substring(0, normalized.length - 1);
      }
      if (!normalized.endsWith('/api')) {
        normalized = '$normalized/api';
      }
      return normalized;
    }
    return defaultBaseUrl;
  }

  static int get apiPort => 443;
  static String get apiProtocol => 'https';

  static bool get hasResolvedHost => true;

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

  // Virtual Waiting Room (Phòng chờ ảo)
  static String queueJoin(String eventId) => '/events/$eventId/queue/join';
  static String queueStatus(String eventId) => '/events/$eventId/queue/status';
  static String queueLeave(String eventId) => '/events/$eventId/queue/leave';
  static String queueAdmission(String eventId) => '/events/$eventId/queue/admission';
  static String queueStream(String eventId) => '/events/$eventId/queue/stream';

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
          ? '/operations/staff/check-in-report?event_id=$eventId'
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
