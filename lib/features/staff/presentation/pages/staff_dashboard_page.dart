import 'package:flutter/material.dart';
import '../../../../core/api/auth_service.dart';
import '../../../../core/api/staff_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/pages/login_page.dart';
import '../../../home/presentation/pages/home_discovery_page.dart';
import 'attendee_registry_page.dart';
import 'qr_scanner_page.dart';

class StaffDashboardPage extends StatefulWidget {
  const StaffDashboardPage({super.key});

  @override
  State<StaffDashboardPage> createState() => _StaffDashboardPageState();
}

class _StaffDashboardPageState extends State<StaffDashboardPage> {
  int _currentNavIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final user = AuthService().currentUser;
      if (user == null || !user.isStaff) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bạn không có quyền truy cập cổng nhân viên!'),
            backgroundColor: AppColors.error,
          ),
        );
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => user == null ? const LoginPage() : const HomeDiscoveryPage()),
        );
        return;
      }

      if (user.hasRole('STAFF')) {
        final hasActive = await StaffService().hasActiveOrUpcomingEvents();
        if (!hasActive && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Tất cả sự kiện được phân công đã kết thúc. Chuyển hướng đến trang Khách hàng.'),
              backgroundColor: Colors.orange,
            ),
          );
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const HomeDiscoveryPage()),
          );
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: const Color(0xFF0C1446).withOpacity(0.9),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leadingWidth: 0,
        leading: const SizedBox.shrink(),
        title: Row(
          children: [
            const Icon(Icons.local_activity, color: AppColors.primary, size: 22),
            const SizedBox(width: 8),
            Text(
              'EventHub',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.secondary.withOpacity(0.2)),
              ),
              child: const Text(
                'STAFF',
                style: TextStyle(color: AppColors.secondary, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1),
              ),
            ),
          ],
        ),
        actions: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant.withOpacity(0.8),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.secondary.withOpacity(0.15)),
            ),
            child: const Row(
              children: [
                CircleAvatar(radius: 4, backgroundColor: Color(0xFF22C55E)),
                SizedBox(width: 6),
                Text(
                  'GATE 02',
                  style: TextStyle(color: AppColors.secondary, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1),
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.storefront_outlined, color: AppColors.primaryContainer, size: 20),
            tooltip: 'Giao diện khách hàng',
            onPressed: () {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const HomeDiscoveryPage()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: AppColors.error, size: 20),
            tooltip: 'Đăng xuất',
            onPressed: () {
              AuthService().logout();
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginPage()),
                (route) => false,
              );
            },
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStaffProfile(context),
            const SizedBox(height: 20),
            _buildCheckInVelocity(context),
            const SizedBox(height: 24),
            const Text(
              'PRIORITY LAUNCHERS',
              style: TextStyle(color: AppColors.secondary, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1),
            ),
            const SizedBox(height: 12),
            _buildScannerLauncher(context),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const AttendeeRegistryPage()),
                      );
                    },
                    child: _buildSecondaryLauncher(context, Icons.person_search, 'Attendee Registry', 'MANUAL CHECK-IN', Colors.orange),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Màn hình POS Bán vé tại quầy!')),
                      );
                    },
                    child: _buildSecondaryLauncher(context, Icons.point_of_sale, 'Walk-In Counter', 'BOX OFFICE POS', Colors.tealAccent),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildGateFeeds(context),
          ],
        ),
      ),
      bottomNavigationBar: _buildStaffBottomNav(),
    );
  }

  Widget _buildStaffProfile(BuildContext context) {
    final user = AuthService().currentUser;
    final staffName = user?.fullName.isNotEmpty == true ? user!.fullName : 'Nhân viên EventHub';
    final initials = staffName.trim().split(RegExp(r'\s+')).where((s) => s.isNotEmpty).map((s) => s[0].toUpperCase()).take(2).join();
    final roleName = user?.roleDisplayName ?? 'Nhân viên';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0C1446).withOpacity(0.75),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.secondary.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Stack(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFF122155),
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.secondary.withOpacity(0.2), width: 2),
                    ),
                    child: Center(
                      child: Text(
                        initials.isNotEmpty ? initials : 'NV',
                        style: const TextStyle(color: AppColors.secondary, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: const Color(0xFF22C55E),
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.surface, width: 2),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      staffName,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(roleName, style: const TextStyle(color: AppColors.secondary, fontSize: 11)),
                        const SizedBox(width: 6),
                        const Text('•', style: TextStyle(color: Colors.white24)),
                        const SizedBox(width: 6),
                        const Text('Station #02', style: TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF22C55E).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF22C55E).withOpacity(0.3)),
                ),
                child: const Row(
                  children: [
                    CircleAvatar(radius: 3, backgroundColor: Color(0xFF22C55E)),
                    SizedBox(width: 6),
                    Text('ONLINE', style: TextStyle(color: Color(0xFF22C55E), fontSize: 10, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant.withOpacity(0.9),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.secondary.withOpacity(0.2)),
            ),
            child: const Row(
              children: [
                Icon(Icons.stadium, color: AppColors.primary, size: 18),
                SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('ACTIVE EVENT VENUE', style: TextStyle(color: AppColors.secondary, fontSize: 9, fontWeight: FontWeight.bold)),
                      Text('Neon Horizon 2025', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                Icon(Icons.arrow_drop_down, color: AppColors.secondary),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckInVelocity(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.secondary.withOpacity(0.15)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.analytics, color: Color(0xFF22C55E), size: 20),
                  SizedBox(width: 8),
                  Text('CHECK-IN VELOCITY', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1)),
                ],
              ),
              Text('Synced 2s ago', style: TextStyle(color: AppColors.secondary.withOpacity(0.7), fontSize: 11, fontFamily: 'monospace')),
            ],
          ),
          const SizedBox(height: 16),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text('3,842', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                  SizedBox(width: 4),
                  Text('/ 5,000', style: TextStyle(color: AppColors.secondary, fontSize: 14)),
                ],
              ),
              Text('76.8%', style: TextStyle(color: Color(0xFF22C55E), fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            height: 12,
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerHighest.withOpacity(0.8),
              borderRadius: BorderRadius.circular(10),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: 0.768,
              child: Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF22C55E), Color(0xFF2DD4BF), AppColors.primaryContainer],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScannerLauncher(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const QrScannerPage()),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [AppColors.primaryContainer, Color(0xFFEA580C)]),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: AppColors.primaryContainer.withOpacity(0.4), blurRadius: 20, offset: const Offset(0, 8)),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.qr_code_scanner, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 16),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('INSTANT VERIFICATION', style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold)),
                  Text('SCAN QR CODE', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward, color: Colors.white),
          ],
        ),
      ),
    );
  }

  Widget _buildSecondaryLauncher(BuildContext context, IconData icon, String label, String title, Color accentColor) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.secondary.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFF122155),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: accentColor, size: 20),
              ),
              const Icon(Icons.chevron_right, color: AppColors.secondary, size: 16),
            ],
          ),
          const SizedBox(height: 12),
          Text(label, style: const TextStyle(color: AppColors.secondary, fontSize: 9, fontWeight: FontWeight.bold)),
          Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildGateFeeds(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface.withOpacity(0.9),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.secondary.withOpacity(0.15)),
      ),
      child: Column(
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.checklist, color: AppColors.secondary, size: 18),
                  SizedBox(width: 8),
                  Text('ACTIVE GATE FEEDS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1)),
                ],
              ),
              Text('2 Active', style: TextStyle(color: AppColors.secondary, fontSize: 10, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 16),
          _buildFeedItem(Icons.stars, 'Turnstile B: VIP Lane', 'Operating Normally • Lane 4', const Color(0xFF22C55E), 'OPEN'),
          const SizedBox(height: 12),
          _buildFeedItem(Icons.battery_5_bar, 'Handheld Scanner #04', '85% Charge • Signal High', AppColors.secondary, 'GOOD'),
        ],
      ),
    );
  }

  Widget _buildFeedItem(IconData icon, String title, String subtitle, Color statusColor, String statusText) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant.withOpacity(0.4),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: statusColor, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                Text(subtitle, style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
            child: Text(statusText, style: TextStyle(color: statusColor, fontSize: 9, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildStaffBottomNav() {
    return Container(
      height: 70,
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest.withOpacity(0.9),
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.05))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildNavItem(0, Icons.dashboard, 'Dashboard'),
          _buildNavItem(1, Icons.qr_code_scanner, 'Scanner'),
          _buildNavItem(2, Icons.how_to_reg, 'Check-in'),
          _buildNavItem(3, Icons.point_of_sale, 'POS'),
        ],
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isActive = _currentNavIndex == index;
    return GestureDetector(
      onTap: () {
        setState(() => _currentNavIndex = index);
        if (index == 1) {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const QrScannerPage()),
          );
        } else if (index == 2) {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const AttendeeRegistryPage()),
          );
        }
      },
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: isActive ? AppColors.primaryContainer : AppColors.secondary, size: 22),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: isActive ? AppColors.primaryContainer : AppColors.secondary, fontSize: 10, fontWeight: isActive ? FontWeight.bold : FontWeight.w500)),
        ],
      ),
    );
  }
}
