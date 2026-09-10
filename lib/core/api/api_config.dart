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
  static const String forgotPassword = '/auth/forgot-password';
  static const String logout = '/auth/logout';

  static const String events = '/events';
  static const String categories = '/events/categories';

  static const String orders = '/orders';
  static const String myTickets = '/tickets/my-tickets';

  static const String staffVerifyQr = '/staff/tickets/verify-qr';
  static const String staffCheckInQr = '/staff/tickets/check-in/qr';
  static const String staffSearchTickets = '/staff/tickets/search';

  static const String aiFaq = '/ai-faq/chat';
}
