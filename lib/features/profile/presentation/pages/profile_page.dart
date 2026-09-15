import 'package:flutter/material.dart';
import '../../../../core/api/auth_service.dart';
import '../../../../core/api/staff_service.dart';
import '../../../../core/models/user_model.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/pages/login_page.dart';
import '../../../staff/presentation/pages/staff_dashboard_page.dart';
import 'change_password_page.dart';
import 'edit_profile_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool _isLoading = false;
  bool _hasActiveStaffEvents = false;

  @override
  void initState() {
    super.initState();
    _fetchLatestProfile();
  }

  Future<void> _fetchLatestProfile() async {
    if (AuthService().currentUser == null) {
      setState(() => _isLoading = true);
    }
    await AuthService().fetchProfile();
    final user = AuthService().currentUser;
    bool hasActive = false;
    if (user != null && user.isStaff) {
      if (user.hasRole('STAFF')) {
        hasActive = await StaffService().hasActiveOrUpcomingEvents();
      } else {
        hasActive = true;
      }
    }
    if (mounted) {
      setState(() {
        _hasActiveStaffEvents = hasActive;
        _isLoading = false;
      });
    }
  }


  Future<void> _openEditProfile() async {
    final updated = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const EditProfilePage()),
    );
    if (updated == true) {
      _fetchLatestProfile();
    }
  }

  Future<void> _openChangePassword() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ChangePasswordPage()),
    );
  }

  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0C1446),
        title: const Text('Đăng Xuất', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text('Bạn có chắc chắn muốn đăng xuất khỏi tài khoản không?', style: TextStyle(color: AppColors.secondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Hủy', style: TextStyle(color: AppColors.secondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Đăng Xuất', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      AuthService().logout();
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginPage()),
        (route) => false,
      );
    }
  }

  void _showNotificationSettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0C1446),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Cài Đặt Thông Báo', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('Thông báo sự kiện sắp diễn ra', style: TextStyle(color: Colors.white, fontSize: 14)),
                subtitle: const Text('Nhắc nhở lịch chiếu & check-in vé', style: TextStyle(color: AppColors.secondary, fontSize: 11)),
                value: true,
                activeColor: AppColors.primaryContainer,
                onChanged: (_) {},
              ),
              SwitchListTile(
                title: const Text('Ưu đãi & Khuyến mãi hot', style: TextStyle(color: Colors.white, fontSize: 14)),
                subtitle: const Text('Cập nhật mã giảm giá vé từ EventHub', style: TextStyle(color: AppColors.secondary, fontSize: 11)),
                value: true,
                activeColor: AppColors.primaryContainer,
                onChanged: (_) {},
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  void _showHelpSupport() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0C1446),
        title: const Row(
          children: [
            Icon(Icons.help_outline, color: AppColors.primaryContainer),
            SizedBox(width: 8),
            Text('Trợ Giúp & Hỗ Trợ', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('EventHub Platform Mobile v1.0.0', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
            SizedBox(height: 8),
            Text('• Hotline hỗ trợ 24/7: 1900 6868\n• Email: support@eventhub.vn\n• Website: https://eventhub.vn', style: TextStyle(color: AppColors.secondary, fontSize: 13, height: 1.5)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Đóng', style: TextStyle(color: AppColors.primaryContainer, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService().currentUser;
    final avatarUrl = user?.avatarUrl ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFF081126),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Hồ Sơ Cá Nhân',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined, color: AppColors.primaryContainer),
            tooltip: 'Chỉnh sửa',
            onPressed: _openEditProfile,
          ),
        ],
      ),
      body: _isLoading && user == null
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primaryContainer),
            )
          : RefreshIndicator(
              onRefresh: _fetchLatestProfile,
              color: AppColors.primaryContainer,
              backgroundColor: const Color(0xFF0C1446),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [

              // User Header Profile Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0F1B47), Color(0xFF0C1446)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.primaryContainer.withOpacity(0.3)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Stack(
                      children: [
                        CircleAvatar(
                          radius: 46,
                          backgroundColor: AppColors.primaryContainer,
                          backgroundImage: avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
                          child: avatarUrl.isEmpty
                              ? Text(
                                  user?.fullName.isNotEmpty == true ? user!.fullName[0].toUpperCase() : 'U',
                                  style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold),
                                )
                              : null,
                        ),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: GestureDetector(
                            onTap: _openEditProfile,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: const BoxDecoration(
                                color: AppColors.primaryContainer,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.camera_alt, size: 16, color: Colors.black),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      user?.fullName ?? 'Khách Hàng EventHub',
                      style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user?.email ?? '',
                      style: const TextStyle(color: AppColors.secondary, fontSize: 13),
                    ),
                    const SizedBox(height: 10),

                    // Role Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppColors.primaryContainer.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.primaryContainer.withOpacity(0.5)),
                      ),
                      child: Text(
                        (user?.roleDisplayName ?? user?.role ?? 'Khách hàng').toUpperCase(),
                        style: const TextStyle(color: AppColors.primaryContainer, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.8),
                      ),
                    ),

                    if (user?.bio != null && user!.bio!.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      Text(
                        '"${user.bio}"',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white70, fontSize: 12, fontStyle: FontStyle.italic),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Detail Cards Grid (Phone, City, Address, DOB)
              _buildUserDetailItems(user),

              const SizedBox(height: 24),

              // Profile Options Menu
              if (_hasActiveStaffEvents) ...[
                _buildProfileOption(
                  icon: Icons.badge_outlined,
                  title: 'Cổng nhân sự (Staff Portal)',
                  subtitle: 'Quản lý soát vé & tra cứu người tham dự',
                  onTap: () async {
                    if (user?.hasRole('STAFF') == true) {
                      final hasActive = await StaffService().hasActiveOrUpcomingEvents();
                      if (!context.mounted) return;
                      if (hasActive) {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const StaffDashboardPage()),
                        );
                      } else {
                        setState(() => _hasActiveStaffEvents = false);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Tất cả sự kiện được phân công đã kết thúc. Không thể vào cổng nhân sự.'),
                            backgroundColor: Colors.orange,
                          ),
                        );
                      }
                    } else {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const StaffDashboardPage()),
                      );
                    }
                  },
                ),
              ],
              _buildProfileOption(
                icon: Icons.person_outline,
                title: 'Thông tin tài khoản',
                subtitle: 'Chỉnh sửa họ tên, số điện thoại, ngày sinh',
                onTap: _openEditProfile,
              ),
              _buildProfileOption(
                icon: Icons.lock_outline,
                title: 'Đổi mật khẩu',
                subtitle: 'Cập nhật mật khẩu bảo mật tài khoản',
                onTap: _openChangePassword,
              ),
              _buildProfileOption(
                icon: Icons.notifications_none,
                title: 'Cài đặt thông báo',
                subtitle: 'Quản lý thông báo sự kiện & khuyến mãi',
                onTap: _showNotificationSettings,
              ),
              _buildProfileOption(
                icon: Icons.help_outline,
                title: 'Trợ giúp & Hỗ trợ',
                subtitle: 'Điều khoản sử dụng & liên hệ hỗ trợ',
                onTap: _showHelpSupport,
              ),

              const SizedBox(height: 28),

              // Logout Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton.icon(
                  onPressed: _handleLogout,
                  icon: const Icon(Icons.logout, color: AppColors.error),
                  label: const Text(
                    'Đăng Xuất Tài Khoản',
                    style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.error),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUserDetailItems(UserModel? user) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0C1446),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.secondary.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          _buildInfoRow(Icons.phone_outlined, 'Số điện thoại', user?.phone ?? 'Chưa cập nhật'),
          const Divider(color: Colors.white10, height: 16),
          _buildInfoRow(Icons.cake_outlined, 'Ngày sinh', user?.formattedDob ?? 'Chưa cập nhật'),
          const Divider(color: Colors.white10, height: 16),
          _buildInfoRow(Icons.location_city_outlined, 'Tỉnh / Thành phố', user?.city ?? 'Chưa cập nhật'),
          const Divider(color: Colors.white10, height: 16),
          _buildInfoRow(Icons.home_outlined, 'Địa chỉ', user?.address ?? 'Chưa cập nhật'),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primaryContainer, size: 18),
        const SizedBox(width: 12),
        Text(
          label,
          style: const TextStyle(color: AppColors.secondary, fontSize: 12),
        ),
        const Spacer(),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  Widget _buildProfileOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF0C1446),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.secondary.withOpacity(0.1)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF122155),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: AppColors.primaryContainer, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(color: AppColors.secondary, fontSize: 11),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.secondary, size: 18),
          ],
        ),
      ),
    );
  }
}
