import 'package:flutter/material.dart';
import '../../../../core/api/auth_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/pages/login_page.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = AuthService().currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFF081126),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Hồ Sơ Cá Nhân', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // User Header
            Center(
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 44,
                    backgroundColor: AppColors.primaryContainer,
                    child: Text(
                      user?.fullName.isNotEmpty == true ? user!.fullName[0].toUpperCase() : 'U',
                      style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    user?.fullName ?? 'Lê Hoàng Nam',
                    style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    user?.email ?? 'nam.le@eventhub.vn',
                    style: const TextStyle(color: AppColors.secondary, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primaryContainer.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.primaryContainer.withOpacity(0.4)),
                    ),
                    child: Text(
                      user?.role ?? 'CUSTOMER MEMBER',
                      style: const TextStyle(color: AppColors.primaryContainer, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Profile Options
            _buildProfileOption(Icons.person_outline, 'Thông tin tài khoản', 'Chỉnh sửa họ tên, số điện thoại'),
            _buildProfileOption(Icons.lock_outline, 'Đổi mật khẩu', 'Bảo mật tài khoản của bạn'),
            _buildProfileOption(Icons.notifications_none, 'Cài đặt thông báo', 'Quản lý thông báo sự kiện'),
            _buildProfileOption(Icons.payment, 'Phương thức thanh toán', 'Quản lý thẻ & ví điện tử'),
            _buildProfileOption(Icons.help_outline, 'Trợ giúp & Hỗ trợ', 'Điều khoản & chính sách bảo mật'),

            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                onPressed: () {
                  AuthService().logout();
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const LoginPage()),
                    (route) => false,
                  );
                },
                icon: const Icon(Icons.logout, color: AppColors.error),
                label: const Text('Đăng Xuất Tài Khoản', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.error),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileOption(IconData icon, String title, String subtitle) {
    return Container(
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
                Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(color: AppColors.secondary, fontSize: 11)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: AppColors.secondary, size: 18),
        ],
      ),
    );
  }
}
