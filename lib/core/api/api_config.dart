import 'dart:io';
import 'package:flutter/foundation.dart';

class ApiConfig {
  // Default Base URL for Android Emulator vs Localhost vs Physical Device
  static String get baseUrl {
    if (kIsWeb) {
      return 'http://localhost:3000/api';
    }
    if (Platform.isAndroid) {
      return 'http://10.0.2.2:3000/api'; // Android Emulator default
    }
    return 'http://localhost:3000/api';
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
  static const String staffVerifyQr = '/staff/tickets/verify-qr';
  static const String staffCheckInQr = '/staff/tickets/check-in/qr';
  static const String staffSearchTickets = '/staff/tickets/search';
  static const String staffAssignedEvents = '/operations/staff/events';

  // AI Assistant
  static const String aiChat = '/ai-assistant/chat';
  static const String aiSessions = '/ai-assistant/sessions';
  static String deleteAiSession(String sessionId) => '/ai-assistant/sessions/$sessionId';
}
