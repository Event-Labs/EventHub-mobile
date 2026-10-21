import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/api/auth_service.dart';
import '../../../../core/api/staff_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/pages/login_page.dart';
import '../../../home/presentation/pages/home_discovery_page.dart';
import '../../../profile/presentation/pages/profile_page.dart';
import 'attendee_registry_page.dart';
import 'qr_scanner_page.dart';
import 'staff_direct_booking_page.dart';

class StaffDashboardPage extends StatefulWidget {
  const StaffDashboardPage({super.key});

  @override
  State<StaffDashboardPage> createState() => _StaffDashboardPageState();
}

class _StaffDashboardPageState extends State<StaffDashboardPage> {
  int _currentNavIndex = 0;
  bool _isLoading = true;

  String _selectedGate = 'GATE 01 - Main Entrance';
  final List<String> _availableGates = [
    'GATE 01 - Main Entrance',
    'GATE 02 - VIP Lane',
    'GATE 03 - Fast Track',
    'GATE 04 - General Access',
    'GATE 05 - Staff & Media',
  ];

  List<Map<String, dynamic>> _assignedEvents = [];
  Map<String, dynamic>? _selectedEvent;
  Map<String, dynamic>? _checkInReport;


  @override
  void initState() {
    super.initState();
    _checkAuthAndLoadData();
  }

  Future<void> _checkAuthAndLoadData() async {
    final user = AuthService().currentUser;
    if (user == null || !user.canAccessStaff) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tài khoản của bạn chỉ có quyền Khách hàng, không thể truy cập Cổng Nhân sự!'),
          backgroundColor: AppColors.error,
        ),
      );
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => user == null ? const LoginPage() : const HomeDiscoveryPage()),
        );
      }
      return;
    }

    await _fetchStaffData();
  }

  Future<void> _fetchStaffData() async {
    setState(() => _isLoading = true);

    try {
      final eventsFuture = StaffService().getAssignedEvents();
      final reportFuture = StaffService().getStaffCheckInReport();

      final results = await Future.wait([eventsFuture, reportFuture]);
      final events = results[0] as List<Map<String, dynamic>>;
      final report = results[1] as Map<String, dynamic>?;

      _assignedEvents = events;
      _checkInReport = report;

      if (_assignedEvents.isNotEmpty) {
        _selectedEvent = _assignedEvents.first;
        if (_selectedEvent!['gate'] != null) {
          final g = _selectedEvent!['gate'].toString();
          if (_availableGates.any((e) => e.startsWith(g))) {
            _selectedGate = _availableGates.firstWhere((e) => e.startsWith(g));
          }
        }
      } else {
        _selectedEvent = null;
      }
    } catch (_) {
      _assignedEvents = [];
      _selectedEvent = null;
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  void _showGateSelectorSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0C1446),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.door_sliding, color: AppColors.primaryContainer),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text('Chọn Cổng Soát Vé', softWrap: true, style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text('Hệ thống sẽ ghi nhận lịch sử check-in theo cổng đang chọn.', style: TextStyle(color: AppColors.secondary, fontSize: 13)),
              const SizedBox(height: 16),
              ..._availableGates.map((gate) {
                final isSelected = _selectedGate == gate;
                return ListTile(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  tileColor: isSelected ? AppColors.primaryContainer.withValues(alpha: 0.15) : Colors.transparent,
                  leading: Icon(
                    isSelected ? Icons.check_circle : Icons.door_front_door_outlined,
                    color: isSelected ? AppColors.primaryContainer : AppColors.secondary,
                  ),
                  title: Text(
                    gate,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.white70,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  trailing: isSelected
                      ? Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primaryContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text('HIỆN TẠI', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                        )
                      : null,
                  onTap: () {
                    setState(() => _selectedGate = gate);
                    Navigator.pop(ctx);
                  },
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  void _showEventSelectorSheet() {
    if (_assignedEvents.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bạn chưa có sự kiện nào được phân công hoặc mời tham gia.'),
          backgroundColor: AppColors.secondary,
        ),
      );
      return;
    }
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0C1446),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.festival_outlined, color: AppColors.primaryContainer),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text('Chọn Sự Kiện Quản Lý', softWrap: true, style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ..._assignedEvents.map((evt) {
                final isSelected = _selectedEvent?['id'] == evt['id'];
                return ListTile(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  tileColor: isSelected ? AppColors.primaryContainer.withValues(alpha: 0.15) : Colors.transparent,
                  leading: Icon(
                    isSelected ? Icons.check_circle : Icons.event_available,
                    color: isSelected ? AppColors.primaryContainer : AppColors.secondary,
                  ),
                  title: Text(
                    evt['title'] ?? evt['name'] ?? 'Sự kiện EventHub',
                    style: TextStyle(color: isSelected ? Colors.white : Colors.white70, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
                  ),
                  subtitle: Text(
                    'Cổng: ${evt['gate'] ?? 'GATE 01'} • Khu: ${evt['zone'] ?? 'Toàn bộ'}',
                    style: const TextStyle(color: AppColors.secondary, fontSize: 12),
                  ),
                  onTap: () {
                    setState(() => _selectedEvent = evt);
                    Navigator.pop(ctx);
                  },
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildStaffAppBar() {
    return AppBar(
      backgroundColor: const Color(0xFF0C1446).withValues(alpha: 0.95),
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      leadingWidth: 0,
      leading: const SizedBox.shrink(),
      title: Row(
        children: [
          const Icon(Icons.shield_outlined, color: AppColors.primaryContainer, size: 22),
          const SizedBox(width: 8),
          Text(
            'EventHub',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFEA580C), Color(0xFFF97316)],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'STAFF',
              style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1),
            ),
          ),
        ],
      ),
      actions: [
        // Current Gate Pill
        GestureDetector(
          onTap: _showGateSelectorSheet,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.secondary.withValues(alpha: 0.15)),
            ),
            child: Row(
              children: [
                const CircleAvatar(radius: 4, backgroundColor: Color(0xFF22C55E)),
                const SizedBox(width: 6),
                Text(
                  _selectedGate.split(' - ').first,
                  style: const TextStyle(color: AppColors.secondary, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1),
                ),
                const Icon(Icons.arrow_drop_down, color: AppColors.secondary, size: 14),
              ],
            ),
          ),
        ),
        const SizedBox(width: 6),
        // Logout Button
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
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildBody() {
    if (_currentNavIndex == 4) {
      return const ProfilePage(isStaffPortal: true);
    }
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primaryContainer));
    }
    return RefreshIndicator(
      onRefresh: _fetchStaffData,
      color: AppColors.primaryContainer,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Staff Profile & Active Event Venue
            _buildStaffProfile(context),
            const SizedBox(height: 20),

            // Check-in Velocity / Report Card
            _buildCheckInVelocity(context),
            const SizedBox(height: 24),

            // Priority Launchers
            const Text(
              'CÔNG CỤ TÁC NGHIỆP NHÂN SỰ',
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
                      if (_assignedEvents.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Bạn chưa có sự kiện nào được phân công hoặc mời tham gia.'),
                            backgroundColor: AppColors.secondary,
                          ),
                        );
                        return;
                      }
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => AttendeeRegistryPage(
                            eventId: _selectedEvent?['id']?.toString(),
                            eventTitle: _selectedEvent?['title']?.toString(),
                            initialEvent: _selectedEvent,
                          ),
                        ),
                      );
                    },
                    child: _buildSecondaryLauncher(
                      context,
                      Icons.person_search,
                      'Tra Cứu Khách',
                      'CHECK-IN TAY',
                      Colors.orange,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      if (_assignedEvents.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Bạn chưa có sự kiện nào được phân công hoặc mời tham gia.'),
                            backgroundColor: AppColors.secondary,
                          ),
                        );
                        return;
                      }
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => StaffDirectBookingPage(initialEvent: _selectedEvent),
                        ),
                      );
                    },
                    child: _buildSecondaryLauncher(
                      context,
                      Icons.point_of_sale,
                      'Bán Vé Trực Tiếp',
                      'QUẦY POS BOX OFFICE',
                      Colors.tealAccent,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),
            // Active Gate Feeds
            _buildGateFeeds(context),

            const SizedBox(height: 24),
            // Assigned Events List
            _buildAssignedEventsList(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _currentNavIndex == 4 ? null : _buildStaffAppBar(),
      body: _buildBody(),
      bottomNavigationBar: _buildStaffBottomNav(),
    );
  }



  Widget _buildStaffProfile(BuildContext context) {
    final user = AuthService().currentUser;
    final staffName = user?.fullName.isNotEmpty == true ? user!.fullName : 'Nhân viên EventHub';
    final initials = staffName.trim().split(RegExp(r'\s+')).where((s) => s.isNotEmpty).map((s) => s[0].toUpperCase()).take(2).join();
    final roleName = user?.roleDisplayName ?? 'Nhân sự vận hành';

    final eventTitle = _selectedEvent?['title'] ?? _selectedEvent?['name'] ?? (_assignedEvents.isEmpty ? 'Chưa có sự kiện phân công' : 'Chưa chọn sự kiện');
    final venueName = _selectedEvent?['venue_name'] ?? _selectedEvent?['venue']?['name'] ?? (_assignedEvents.isEmpty ? 'Vui lòng liên hệ BTC để được mời tham gia sự kiện' : 'Địa điểm đang cập nhật');
    final gate = _selectedEvent?['gate'] ?? _selectedGate.split(' - ').first;
    final zone = _selectedEvent?['zone'] ?? (_assignedEvents.isEmpty ? 'Chưa có khu vực' : 'Khu vực chính');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0C1446).withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.secondary.withValues(alpha: 0.15)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Stack(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFF122155),
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.primaryContainer.withValues(alpha: 0.4), width: 2),
                    ),
                    child: Center(
                      child: Text(
                        initials.isNotEmpty ? initials : 'NV',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
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
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                      softWrap: true,
                    ),
                    const SizedBox(height: 2),
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 4,
                      children: [
                        Text(
                          roleName,
                          style: const TextStyle(color: AppColors.secondary, fontSize: 11),
                          softWrap: true,
                        ),
                        const Text('•', style: TextStyle(color: Colors.white24)),
                        Text(
                          gate,
                          style: const TextStyle(color: AppColors.primaryContainer, fontSize: 11, fontWeight: FontWeight.bold),
                          softWrap: true,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF22C55E).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF22C55E).withValues(alpha: 0.3)),
                ),
                child: const Row(
                  children: [
                    CircleAvatar(radius: 3, backgroundColor: Color(0xFF22C55E)),
                    SizedBox(width: 6),
                    Text('TRỰC CỔNG', style: TextStyle(color: Color(0xFF22C55E), fontSize: 10, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Active Event Selector Tile
          GestureDetector(
            onTap: _showEventSelectorSheet,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.secondary.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.stadium, color: AppColors.primaryContainer, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 4,
                          children: [
                            Text(
                              _assignedEvents.isEmpty ? 'TRẠNG THÁI PHÂN CÔNG' : 'SỰ KIỆN PHÂN CÔNG',
                              style: const TextStyle(color: AppColors.secondary, fontSize: 9, fontWeight: FontWeight.bold),
                              softWrap: true,
                            ),
                            if (_assignedEvents.isNotEmpty) ...[
                              Text(
                                '• $zone',
                                style: const TextStyle(color: AppColors.primaryContainer, fontSize: 9, fontWeight: FontWeight.bold),
                                softWrap: true,
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          eventTitle,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                          softWrap: true,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          venueName,
                          style: const TextStyle(color: AppColors.secondary, fontSize: 11),
                          softWrap: true,
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_drop_down, color: AppColors.secondary),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckInVelocity(BuildContext context) {
    if (_assignedEvents.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.secondary.withValues(alpha: 0.15)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      const Icon(Icons.analytics_outlined, color: AppColors.secondary, size: 20),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'TIẾN ĐỘ SOÁT VÉ CỔNG',
                          softWrap: true,
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.5, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Text('Chờ phân công', style: TextStyle(color: AppColors.secondary, fontSize: 11)),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF0C1446).withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.secondary.withValues(alpha: 0.1)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: AppColors.secondary, size: 18),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Hiện tại chưa có sự kiện nào được phân công nên không thể thống kê tiến độ soát vé.',
                      style: TextStyle(color: AppColors.secondary, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final total = _selectedEvent?['total_tickets'] ?? _checkInReport?['total_tickets'] ?? 0;
    final checkedIn = _selectedEvent?['checked_in'] ?? _checkInReport?['checked_in'] ?? 0;
    final double percent = total > 0 ? (checkedIn / total) : 0.0;
    final percentStr = (percent * 100).toStringAsFixed(1);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.secondary.withValues(alpha: 0.15)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(Icons.analytics, color: Color(0xFF22C55E), size: 20),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'TIẾN ĐỘ SOÁT VÉ CỔNG',
                        softWrap: true,
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.5, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircleAvatar(radius: 3, backgroundColor: Color(0xFF22C55E)),
                  const SizedBox(width: 4),
                  Text('Đồng bộ live', style: TextStyle(color: AppColors.secondary.withValues(alpha: 0.7), fontSize: 11)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    NumberFormat('#,###').format(checkedIn),
                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '/ ${NumberFormat('#,###').format(total)} vé',
                    style: const TextStyle(color: AppColors.secondary, fontSize: 14),
                  ),
                ],
              ),
              Text(
                '$percentStr%',
                style: const TextStyle(color: Color(0xFF22C55E), fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            height: 10,
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerHighest.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(10),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: percent.clamp(0.0, 1.0),
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
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: _buildVelocityStat('ĐÃ VÀO CỔNG', NumberFormat('#,###').format(checkedIn), const Color(0xFF22C55E))),
              const SizedBox(width: 6),
              Expanded(child: _buildVelocityStat('CHƯA CHECK-IN', NumberFormat('#,###').format(total > checkedIn ? total - checkedIn : 0), AppColors.secondary)),
              const SizedBox(width: 6),
              Expanded(child: _buildVelocityStat('CỔNG HIỆN TẠI', _selectedGate.split(' - ').first, AppColors.primaryContainer)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVelocityStat(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          softWrap: true,
          style: const TextStyle(color: AppColors.secondary, fontSize: 9, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          softWrap: true,
          style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildScannerLauncher(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (_assignedEvents.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Bạn chưa có sự kiện nào được phân công hoặc mời tham gia.'),
              backgroundColor: AppColors.secondary,
            ),
          );
          return;
        }
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => QrScannerPage(
              initialGate: _selectedGate,
              eventId: _selectedEvent?['id']?.toString(),
              eventTitle: _selectedEvent?['title']?.toString(),
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFFEA580C), Color(0xFFF97316)]),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: const Color(0xFFEA580C).withValues(alpha: 0.4), blurRadius: 20, offset: const Offset(0, 8)),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.qr_code_scanner, color: Colors.white, size: 28),
            ),
            const SizedBox(width: 16),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('QUÉT SOÁT VÉ TỨC THÌ (CAMERA)', style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                  SizedBox(height: 2),
                  Text('QUÉT MÃ QR CHECK-IN', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildSecondaryLauncher(BuildContext context, IconData icon, String label, String title, Color accentColor) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.secondary.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFF122155),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: accentColor, size: 20),
              ),
              const Icon(Icons.chevron_right, color: AppColors.secondary, size: 16),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            label,
            softWrap: true,
            style: const TextStyle(color: AppColors.secondary, fontSize: 9, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            softWrap: true,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildGateFeeds(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.secondary.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(Icons.door_front_door_outlined, color: AppColors.primaryContainer, size: 18),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'TRẠNG THÁI CÁC CỔNG',
                        softWrap: true,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _showGateSelectorSheet,
                child: const Text('Đổi cổng', style: TextStyle(color: AppColors.primaryContainer, fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _buildFeedItem(Icons.door_sliding, 'GATE 01 - Cổng Chính (Main Entrance)', '1,840 khách đã vào • Đang thông luồng', const Color(0xFF22C55E), 'HOẠT ĐỘNG'),
          const SizedBox(height: 10),
          _buildFeedItem(Icons.stars, 'GATE 02 - VIP Lane (Làn Ưu Tiên)', '420 khách đã vào • Đang soát vé', const Color(0xFF22C55E), 'HOẠT ĐỘNG'),
          const SizedBox(height: 10),
          _buildFeedItem(Icons.battery_charging_full, 'Thiết bị POS & Máy quét di động #02', 'Pin 92% • Tín hiệu mạng ổn định', AppColors.secondary, 'TỐT'),
        ],
      ),
    );
  }

  Widget _buildFeedItem(IconData icon, String title, String subtitle, Color statusColor, String statusText) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: statusColor, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  softWrap: true,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  softWrap: true,
                  style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
            child: Text(
              statusText,
              softWrap: true,
              style: TextStyle(color: statusColor, fontSize: 9, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAssignedEventsList() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.secondary.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.assignment_outlined, color: AppColors.primaryContainer, size: 18),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'DANH SÁCH SỰ KIỆN ĐƯỢC PHÂN CÔNG',
                  softWrap: true,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (_assignedEvents.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xFF0C1446).withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.secondary.withValues(alpha: 0.1)),
              ),
              child: Column(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant.withValues(alpha: 0.6),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.event_busy, color: AppColors.secondary, size: 24),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Chưa có sự kiện nào được phân công',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Bạn chỉ có thể tác nghiệp ở những sự kiện mà Ban tổ chức mời hoặc phân công cho bạn.',
                    style: TextStyle(color: AppColors.secondary, fontSize: 12, height: 1.4),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 14),
                  OutlinedButton.icon(
                    onPressed: _fetchStaffData,
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('Làm mới danh sách', style: TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primaryContainer,
                      side: const BorderSide(color: AppColors.primaryContainer),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
            )
          else
            ..._assignedEvents.map((evt) {
              final isSelected = _selectedEvent?['id'] == evt['id'];
            final title = evt['title'] ?? evt['name'] ?? 'Sự kiện';
            final venue = evt['venue_name'] ?? evt['venue']?['name'] ?? '';
            final role = evt['role'] ?? 'Nhân viên soát vé';
            final gate = evt['gate'] ?? 'GATE 01';

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF0C1446),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isSelected ? AppColors.primaryContainer : AppColors.secondary.withValues(alpha: 0.15),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primaryContainer.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(gate, style: const TextStyle(color: AppColors.primaryContainer, fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          role,
                          style: const TextStyle(color: AppColors.secondary, fontSize: 11),
                          softWrap: true,
                        ),
                      ),
                      if (isSelected) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF22C55E).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text('ĐANG CHỌN', style: TextStyle(color: Color(0xFF22C55E), fontSize: 9, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(title, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold), softWrap: true),
                  const SizedBox(height: 4),
                  Text(venue, style: const TextStyle(color: AppColors.secondary, fontSize: 11), softWrap: true),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => QrScannerPage(
                                  initialGate: gate,
                                  eventId: evt['id']?.toString(),
                                  eventTitle: title,
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.qr_code_scanner, size: 16),
                          label: const FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text('Quét Vé', style: TextStyle(fontSize: 12)),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primaryContainer,
                            side: const BorderSide(color: AppColors.primaryContainer),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => StaffDirectBookingPage(initialEvent: evt),
                              ),
                            );
                          },
                          icon: const Icon(Icons.point_of_sale, size: 16),
                          label: const FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text('Bán Vé POS', style: TextStyle(fontSize: 12)),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF14B8A6),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildStaffBottomNav() {
    return Container(
      height: 72,
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest.withValues(alpha: 0.95),
        border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Expanded(child: _buildNavItem(0, Icons.dashboard_outlined, Icons.dashboard, 'Dashboard')),
          Expanded(child: _buildNavItem(1, Icons.qr_code_scanner, Icons.qr_code_scanner, 'Soát Vé')),
          Expanded(child: _buildNavItem(2, Icons.how_to_reg_outlined, Icons.how_to_reg, 'Danh Sách')),
          Expanded(child: _buildNavItem(3, Icons.point_of_sale_outlined, Icons.point_of_sale, 'Bán Vé POS')),
          Expanded(child: _buildNavItem(4, Icons.person_outline, Icons.person, 'Tài khoản')),
        ],
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, IconData activeIcon, String label) {
    final isActive = _currentNavIndex == index;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if ((index == 1 || index == 2 || index == 3) && _assignedEvents.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Bạn chưa có sự kiện nào được phân công hoặc mời tham gia.'),
              backgroundColor: AppColors.secondary,
            ),
          );
          return;
        }

        setState(() => _currentNavIndex = index);
        if (index == 1) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => QrScannerPage(
                initialGate: _selectedGate,
                eventId: _selectedEvent?['id']?.toString(),
                eventTitle: _selectedEvent?['title']?.toString(),
              ),
            ),
          ).then((_) {
            if (mounted) setState(() => _currentNavIndex = 0);
          });
        } else if (index == 2) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => AttendeeRegistryPage(
                eventId: _selectedEvent?['id']?.toString(),
                eventTitle: _selectedEvent?['title']?.toString(),
                initialEvent: _selectedEvent,
              ),
            ),
          ).then((_) {
            if (mounted) setState(() => _currentNavIndex = 0);
          });
        } else if (index == 3) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => StaffDirectBookingPage(initialEvent: _selectedEvent),
            ),
          ).then((_) {
            if (mounted) setState(() => _currentNavIndex = 0);
          });
        }
      },
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(isActive ? activeIcon : icon, color: isActive ? AppColors.primaryContainer : AppColors.secondary, size: 22),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Text(
                label,
                style: TextStyle(
                  color: isActive ? AppColors.primaryContainer : AppColors.secondary,
                  fontSize: 10,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
