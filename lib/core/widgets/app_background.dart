import 'package:flutter/material.dart';

/// Reusable application background widget featuring the static celestial ribbon image.
class AppBackground extends StatelessWidget {
  final Widget child;

  const AppBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Static high-resolution celestial ribbon background
        Positioned.fill(
          child: Image.asset(
            'assets/splash/app_background.png',
            fit: BoxFit.cover,
          ),
        ),

        // Child Screen Content
        Positioned.fill(
          child: child,
        ),
      ],
    );
  }
}
