import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../../../../core/api/auth_service.dart';
import '../../../../core/api/staff_service.dart';
import '../../../../core/models/user_model.dart';
import '../../../../main.dart';
import '../../../auth/presentation/pages/login_page.dart';
import '../../../home/presentation/pages/home_discovery_page.dart';
import '../../../staff/presentation/pages/staff_dashboard_page.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> with TickerProviderStateMixin {
  // 1. Twinkling stars continuous controller
  late final AnimationController _starsController;

  // 2. Logo subtle breathing pulse controller
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  Timer? _fallbackTimer;
  bool _isNavigated = false;
  late final Future<UserModel?> _sessionFuture;

  // Normalized star coordinates and sizes matching the cosmos design
  // (xNorm, yNorm, size, phaseOffset)
  static const List<_StarSpec> _stars = [
    _StarSpec(0.278, 0.047, 18, 0.0),
    _StarSpec(0.496, 0.047, 24, 1.2),
    _StarSpec(0.835, 0.081, 16, 2.7),
    _StarSpec(0.118, 0.123, 26, 0.8),
    _StarSpec(0.405, 0.174, 24, 3.4),
    _StarSpec(0.623, 0.281, 14, 1.9),
    _StarSpec(0.136, 0.490, 16, 0.5),
    _StarSpec(0.209, 0.561, 18, 4.1),
    _StarSpec(0.543, 0.689, 16, 2.2),
    _StarSpec(0.762, 0.620, 14, 3.8),
    _StarSpec(0.390, 0.779, 16, 1.5),
    _StarSpec(0.078, 0.910, 22, 0.3),
    _StarSpec(0.814, 0.916, 20, 2.9),
    // Additional ambient twinkling dust stars
    _StarSpec(0.350, 0.110, 10, 4.8),
    _StarSpec(0.680, 0.190, 9, 3.1),
    _StarSpec(0.880, 0.320, 11, 1.7),
    _StarSpec(0.050, 0.360, 10, 5.2),
    _StarSpec(0.310, 0.610, 9, 0.9),
    _StarSpec(0.670, 0.530, 10, 2.4),
    _StarSpec(0.920, 0.730, 11, 4.3),
    _StarSpec(0.170, 0.840, 9, 3.6),
    _StarSpec(0.580, 0.850, 10, 1.1),
  ];

  @override
  void initState() {
    super.initState();

    // Restore saved session in parallel with splash animation
    _sessionFuture = AuthService().restoreSession();

    // 1. Continuous stars twinkling loop
    _starsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();

    // 2. Subtle logo breathing pulse
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.97, end: 1.03).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Start background app loading and navigate when ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAppAndNavigate();
    });

    // Fallback timer: guarantees automatic navigation after 2.5s maximum
    _fallbackTimer = Timer(const Duration(milliseconds: 2500), () {
      _navigateToNextScreen();
    });
  }

  Future<void> _loadAppAndNavigate() async {
    final startTime = DateTime.now();

    // 1. Precache background image
    if (mounted) {
      try {
        await precacheImage(const AssetImage('assets/splash/app_background.png'), context);
      } catch (_) {}
    }

    // 2. Wait for session restoration
    UserModel? user;
    try {
      user = await _sessionFuture.timeout(const Duration(milliseconds: 1500));
    } catch (_) {}

    // 3. Ensure a minimum display time of 800ms so the user sees the launch screen smoothly
    final elapsed = DateTime.now().difference(startTime).inMilliseconds;
    if (elapsed < 800) {
      await Future.delayed(Duration(milliseconds: 800 - elapsed));
    }

    if (!mounted) return;
    _navigateToNextScreen(preloadedUser: user);
  }

  @override
  void reassemble() {
    super.reassemble();
    _loadAppAndNavigate();
  }

  @override
  void dispose() {
    _fallbackTimer?.cancel();
    _starsController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _navigateToNextScreen({UserModel? preloadedUser}) async {
    if (_isNavigated || !mounted) return;
    _isNavigated = true;
    _fallbackTimer?.cancel();

    UserModel? user = preloadedUser ?? AuthService().currentUser;
    if (user == null) {
      try {
        user = await _sessionFuture.timeout(const Duration(milliseconds: 600));
      } catch (_) {}
    }

    Widget destination;
    if (user != null) {
      if (user.canAccessStaff) {
        bool hasActive = false;
        try {
          hasActive = await StaffService()
              .hasActiveOrUpcomingEvents()
              .timeout(const Duration(milliseconds: 1500));
        } catch (_) {}
        destination = hasActive ? const StaffDashboardPage() : const HomeDiscoveryPage();
      } else {
        destination = const HomeDiscoveryPage();
      }
    } else {
      destination = const LoginPage();
    }

    if (!mounted) return;
    final nav = navigatorKey.currentState ?? Navigator.of(context);
    nav.pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => destination,
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF020716),
      body: GestureDetector(
        onTap: () => _navigateToNextScreen(), // Allows tapping to skip splash screen immediately
        behavior: HitTestBehavior.translucent,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth;
            final h = constraints.maxHeight;

            // Logo dimensions & vertical centering
            final logoWidth = w * 0.76;
            const logoAspectRatio = 535.0 / 120.0;
            final logoHeight = logoWidth / logoAspectRatio;

            // Total splash block height including indicator
            const blockExtraHeight = 60.0;
            final logoTop = (h - (logoHeight + blockExtraHeight)) / 2;

            return Stack(
              fit: StackFit.expand,
              children: [
                // Layer 0: Pristine Deep Cosmic Space Background
                Positioned.fill(
                  child: Image.asset(
                    'assets/splash/space_bg_clean.png',
                    fit: BoxFit.cover,
                    alignment: Alignment.center,
                  ),
                ),

                // Layer 1: Animated Twinkling Golden Stars
                ..._buildTwinklingStars(w, h),

                // Layer 2: 3D Rotating Planets (framing the centered logo)
                ..._buildRotatingPlanets(w, h),

                // Layer 3: Main Centered Logo + Subtle Cosmic Loader (Immediately visible!)
                Positioned(
                  top: logoTop,
                  left: (w - logoWidth) / 2,
                  width: logoWidth,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ScaleTransition(
                        scale: _pulseAnimation,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // Neon cyan flare beam behind logo
                            Container(
                              height: 2,
                              margin: const EdgeInsets.symmetric(horizontal: 16),
                              decoration: BoxDecoration(
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF00E5FF).withValues(alpha: 0.85),
                                    blurRadius: 18,
                                    spreadRadius: 3,
                                  ),
                                  BoxShadow(
                                    color: const Color(0xFF0088FF).withValues(alpha: 0.65),
                                    blurRadius: 32,
                                    spreadRadius: 6,
                                  ),
                                ],
                              ),
                            ),
                            // Logo Image (includes EVENTHUB and tagline)
                            Image.asset(
                              'assets/splash/logo_isolated.png',
                              width: logoWidth,
                              fit: BoxFit.contain,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 28),
                      // Smooth cosmic loading indicator
                      SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            const Color(0xFF00E5FF).withValues(alpha: 0.85),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Đang tải dữ liệu...',
                        style: TextStyle(
                          color: const Color(0xFFB0CADD).withValues(alpha: 0.75),
                          fontSize: 12,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // 3D Rotating planets moving from left to right around their tilted axes,
  // shifted down to harmoniously balance with the centered logo
  List<Widget> _buildRotatingPlanets(double w, double h) {
    return [
      // 1. Top-Right Blue Planet (shifted down to cy=0.255)
      _buildPositionedPlanet(
        assetPath: 'assets/splash/planet_blue.webp',
        centerNorm: const Offset(0.835, 0.255),
        baseSize: 104,
        w: w,
        h: h,
      ),

      // 2. Mid-Left Peach Planet (shifted down to cy=0.335)
      _buildPositionedPlanet(
        assetPath: 'assets/splash/planet_orange.webp',
        centerNorm: const Offset(0.210, 0.335),
        baseSize: 48,
        w: w,
        h: h,
      ),

      // 3. Right-Edge Striped Giant Planet (shifted down to cy=0.618)
      _buildPositionedPlanet(
        assetPath: 'assets/splash/planet_right.webp',
        centerNorm: const Offset(1.010, 0.618),
        baseSize: 160,
        w: w,
        h: h,
      ),

      // 4. Bottom-Left Purple Swirl Planet (shifted down to cy=0.730)
      _buildPositionedPlanet(
        assetPath: 'assets/splash/planet_purple.webp',
        centerNorm: const Offset(0.020, 0.730),
        baseSize: 148,
        w: w,
        h: h,
      ),

      // 5. Bottom-Right Pink Moon (shifted down to cy=0.870)
      _buildPositionedPlanet(
        assetPath: 'assets/splash/planet_pink.webp',
        centerNorm: const Offset(0.796, 0.870),
        baseSize: 44,
        w: w,
        h: h,
      ),
    ];
  }

  Widget _buildPositionedPlanet({
    required String assetPath,
    required Offset centerNorm,
    required double baseSize,
    required double w,
    required double h,
  }) {
    // Scale proportionally with screen width
    final scale = min(w / 390.0, 1.25);
    // The WebP image has 1.45x radius padding for atmospheric glow
    final imageSize = baseSize * 1.45 * scale;
    final cx = centerNorm.dx * w;
    final cy = centerNorm.dy * h;

    return Positioned(
      left: cx - (imageSize / 2),
      top: cy - (imageSize / 2),
      width: imageSize,
      height: imageSize,
      child: Image.asset(
        assetPath,
        fit: BoxFit.contain,
      ),
    );
  }

  // Animated Twinkling Golden Stars (4-pointed faceted stars)
  List<Widget> _buildTwinklingStars(double w, double h) {
    return _stars.map((star) {
      final cx = star.xNorm * w;
      final cy = star.yNorm * h;

      return Positioned(
        left: cx - (star.baseSize / 2),
        top: cy - (star.baseSize / 2),
        child: AnimatedBuilder(
          animation: _starsController,
          builder: (context, _) {
            final t = (_starsController.value * 2 * pi) + star.phaseOffset;
            final sine = (sin(t) + 1.0) / 2.0; // 0.0 -> 1.0

            // Modulate opacity and size
            final opacity = (0.35 + (sine * 0.65)).clamp(0.0, 1.0);
            final scale = 0.78 + (sine * 0.38);

            return Opacity(
              opacity: opacity,
              child: CustomPaint(
                size: Size(star.baseSize, star.baseSize),
                painter: GoldenStarPainter(scale: scale),
              ),
            );
          },
        ),
      );
    }).toList();
  }
}

// Specification for placing stars matching the reference image
class _StarSpec {
  final double xNorm;
  final double yNorm;
  final double baseSize;
  final double phaseOffset;

  const _StarSpec(this.xNorm, this.yNorm, this.baseSize, this.phaseOffset);
}

// Custom Painter for authentic 4-pointed golden faceted stars with diamond highlights
class GoldenStarPainter extends CustomPainter {
  final double scale;

  const GoldenStarPainter({this.scale = 1.0});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = (size.width / 2) * scale;

    // 1. Warm golden outer aura glow
    final glowPaint = Paint()
      ..color = const Color(0xFFFFB300).withValues(alpha: 0.45)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.5);
    canvas.drawCircle(Offset(cx, cy), r * 0.65, glowPaint);

    // 2. 4 Primary sharp diamond points
    final primaryPath = Path();
    primaryPath.moveTo(cx, cy - r); // Top
    primaryPath.quadraticBezierTo(cx, cy, cx + r, cy); // Right
    primaryPath.quadraticBezierTo(cx, cy, cx, cy + r); // Bottom
    primaryPath.quadraticBezierTo(cx, cy, cx - r, cy); // Left
    primaryPath.quadraticBezierTo(cx, cy, cx, cy - r); // Close
    primaryPath.close();

    final starShader = const RadialGradient(
      colors: [
        Colors.white,
        Color(0xFFFFE082),
        Color(0xFFFFB300),
        Color(0xFFFF8F00),
      ],
      stops: [0.0, 0.35, 0.7, 1.0],
    ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: r));

    final starPaint = Paint()..shader = starShader;
    canvas.drawPath(primaryPath, starPaint);

    // 3. 4 Smaller diagonal accent points
    final diagR = r * 0.45;
    final diagPath = Path();
    diagPath.moveTo(cx - diagR, cy - diagR);
    diagPath.quadraticBezierTo(cx, cy, cx + diagR, cy - diagR);
    diagPath.quadraticBezierTo(cx, cy, cx + diagR, cy + diagR);
    diagPath.quadraticBezierTo(cx, cy, cx - diagR, cy + diagR);
    diagPath.close();

    final diagPaint = Paint()
      ..color = const Color(0xFFFFD54F).withValues(alpha: 0.85);
    canvas.drawPath(diagPath, diagPaint);

    // 4. Intense white sparkling center core
    final corePaint = Paint()..color = Colors.white;
    canvas.drawCircle(Offset(cx, cy), max(1.2, r * 0.22), corePaint);
  }

  @override
  bool shouldRepaint(covariant GoldenStarPainter oldDelegate) {
    return oldDelegate.scale != scale;
  }
}
