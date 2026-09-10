import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/pages/login_page.dart';

void main() {
  runApp(const EventHubApp());
}

class EventHubApp extends StatelessWidget {
  const EventHubApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EventHub',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const LoginPage(),
    );
  }
}
