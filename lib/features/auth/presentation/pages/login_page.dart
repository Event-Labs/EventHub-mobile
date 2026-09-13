import 'package:flutter/material.dart';
import 'package:eventhub_mobile/core/api/auth_service.dart';
import 'package:eventhub_mobile/core/models/user_model.dart';
import 'package:eventhub_mobile/core/theme/app_colors.dart';
import 'package:eventhub_mobile/features/auth/presentation/pages/forgot_password_page.dart';
import 'package:eventhub_mobile/features/home/presentation/pages/home_discovery_page.dart';
import 'package:eventhub_mobile/features/staff/presentation/pages/staff_dashboard_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool _obscurePassword = true;
  bool _isLoginTab = true;
  bool _isLoading = false;

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _fullNameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập đầy đủ Email và Mật khẩu!'), backgroundColor: AppColors.error),
      );
      return;
    }

    setState(() => _isLoading = true);

    if (_isLoginTab) {
      // Login Flow
      final res = await AuthService().login(email: email, password: password);
      setState(() => _isLoading = false);

      if (mounted) {
        if (res['success'] == true) {
          final user = res['user'] as UserModel?;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Xin chào ${user?.fullName ?? ''}! (${user?.roleDisplayName ?? 'Khách hàng'})'),
              backgroundColor: Colors.green,
            ),
          );
          if (user != null && user.isStaff) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const StaffDashboardPage()),
            );
          } else {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const HomeDiscoveryPage()),
            );
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(res['message'] ?? 'Đăng nhập không thành công!'), backgroundColor: AppColors.error),
          );
        }
      }
    } else {
      // Register Flow
      final fullName = _fullNameController.text.trim();
      if (fullName.isEmpty) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vui lòng nhập Họ và tên!'), backgroundColor: AppColors.error),
        );
        return;
      }

      final res = await AuthService().register(
        fullName: fullName,
        email: email,
        password: password,
        phone: _phoneController.text.trim(),
      );
      setState(() => _isLoading = false);

      if (mounted) {
        if (res['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Đăng ký thành công! Hãy đăng nhập ngay.'), backgroundColor: Colors.green),
          );
          setState(() => _isLoginTab = true);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(res['message'] ?? 'Đăng ký thất bại!'), backgroundColor: AppColors.error),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          color: Color(0xFF081126),
          gradient: RadialGradient(
            center: Alignment(-0.7, -0.7),
            radius: 1.5,
            colors: [
              Color(0x1F161F35),
              Color(0xFF081126),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      const SizedBox(height: 30),
                      _buildBrandIdentity(),
                      const SizedBox(height: 30),
                      _buildAuthCard(),
                      const SizedBox(height: 24),
                      _buildStaffPortalLink(),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
              _buildFooter(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: AppColors.primaryContainer,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'EVENT NETWORK LIVE',
                style: TextStyle(
                  color: AppColors.secondary,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const Row(
            children: [
              Icon(Icons.wifi, color: AppColors.secondary, size: 16),
              SizedBox(width: 8),
              Icon(Icons.battery_full, color: AppColors.secondary, size: 18),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBrandIdentity() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF0C1446),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.secondary.withOpacity(0.15)),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryContainer.withOpacity(0.1),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primaryContainer, Color(0xFFEA580C)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.confirmation_number, color: Colors.white, size: 26),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'EventHub',
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.primaryContainer.withOpacity(0.2),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: AppColors.primaryContainer.withOpacity(0.3)),
              ),
              child: const Text(
                'VN',
                style: TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          _isLoginTab ? 'Đăng nhập vào không gian sự kiện đỉnh cao' : 'Tạo tài khoản mới để nhận nhiều ưu đãi',
          style: const TextStyle(color: AppColors.secondary, fontSize: 14),
        ),
      ],
    );
  }

  Widget _buildAuthCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xE60C1446),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.secondary.withOpacity(0.15)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 40,
            offset: const Offset(0, 20),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildTabSwitcher(),
          const SizedBox(height: 24),

          if (!_isLoginTab) ...[
            _buildTextField(
              controller: _fullNameController,
              label: 'Họ và tên',
              hint: 'Lê Hoàng Nam',
              icon: Icons.person_outline,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _phoneController,
              label: 'Số điện thoại',
              hint: '0987654321',
              icon: Icons.phone_android_outlined,
            ),
            const SizedBox(height: 16),
          ],

          _buildTextField(
            controller: _emailController,
            label: 'Email',
            hint: 'name@eventhub.vn',
            icon: Icons.mail_outline,
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _passwordController,
            label: 'Mật khẩu',
            hint: '••••••••••••',
            icon: Icons.lock_outline,
            isPassword: true,
            obscureText: _obscurePassword,
            onToggleVisibility: () {
              setState(() => _obscurePassword = !_obscurePassword);
            },
          ),
          const SizedBox(height: 16),

          if (_isLoginTab)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: Checkbox(
                        value: true,
                        onChanged: (val) {},
                        activeColor: AppColors.primaryContainer,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text('Ghi nhớ đăng nhập', style: TextStyle(color: AppColors.secondary, fontSize: 13)),
                  ],
                ),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const ForgotPasswordPage()),
                    );
                  },
                  child: const Text(
                    'Quên mật khẩu?',
                    style: TextStyle(color: AppColors.secondary, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          const SizedBox(height: 16),

          ElevatedButton(
            onPressed: _isLoading ? null : _handleSubmit,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryContainer,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 8,
              shadowColor: AppColors.primaryContainer.withOpacity(0.5),
            ),
            child: _isLoading
                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_isLoginTab ? 'Đăng Nhập Ngay' : 'Tạo Tài Khoản', style: const TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(width: 8),
                      const Icon(Icons.arrow_forward, size: 18),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabSwitcher() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFF122155).withOpacity(0.8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.secondary.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _isLoginTab = true),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _isLoginTab ? AppColors.primaryContainer : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Đăng nhập',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _isLoginTab ? Colors.white : AppColors.secondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _isLoginTab = false),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: !_isLoginTab ? AppColors.primaryContainer : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Đăng ký',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: !_isLoginTab ? Colors.white : AppColors.secondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool isPassword = false,
    bool obscureText = false,
    VoidCallback? onToggleVisibility,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Text(
            label,
            style: const TextStyle(color: AppColors.secondary, fontSize: 12, fontWeight: FontWeight.w500),
          ),
        ),
        Container(
          height: 48,
          decoration: BoxDecoration(
            color: const Color(0xFF122155),
            borderRadius: BorderRadius.circular(12),
          ),
          child: TextField(
            controller: controller,
            obscureText: obscureText,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: AppColors.secondary.withOpacity(0.4), fontSize: 14),
              prefixIcon: Icon(icon, color: AppColors.secondary, size: 20),
              suffixIcon: isPassword
                  ? IconButton(
                      icon: Icon(
                        obscureText ? Icons.visibility : Icons.visibility_off,
                        color: AppColors.secondary,
                        size: 20,
                      ),
                      onPressed: onToggleVisibility,
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStaffPortalLink() {
    return GestureDetector(
      onTap: () {
        final currentUser = AuthService().currentUser;
        if (currentUser != null && currentUser.isStaff) {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const StaffDashboardPage()),
          );
        } else {
          setState(() => _isLoginTab = true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Vui lòng đăng nhập bằng tài khoản Ban Tổ Chức hoặc Nhân viên!'),
              backgroundColor: AppColors.primaryContainer,
            ),
          );
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xCC0C1446),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: AppColors.secondary.withOpacity(0.15)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.verified_user, color: AppColors.tertiary, size: 18),
            SizedBox(width: 8),
            Text(
              'Bạn là Ban Tổ Chức / Staff?',
              style: TextStyle(color: AppColors.secondary, fontSize: 13),
            ),
            SizedBox(width: 4),
            Text(
              'Đăng nhập Staff',
              style: TextStyle(color: AppColors.primaryContainer, fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        children: [
          const Text(
            'Bằng cách tiếp tục, bạn đồng ý với Điều khoản dịch vụ và Chính sách bảo mật của EventHub.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white38, fontSize: 11),
          ),
          const SizedBox(height: 8),
          Text(
            'EVENTHUB SECURITY SHIELD v4.2.0',
            style: TextStyle(
              color: AppColors.secondary.withOpacity(0.2),
              fontSize: 9,
              letterSpacing: 1,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }
}
