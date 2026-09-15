import 'package:flutter/material.dart';
import 'package:eventhub_mobile/core/api/auth_service.dart';
import 'package:eventhub_mobile/core/models/user_model.dart';
import 'package:eventhub_mobile/core/theme/app_colors.dart';
import 'package:eventhub_mobile/core/api/staff_service.dart';
import 'package:eventhub_mobile/features/auth/presentation/pages/forgot_password_page.dart';
import 'package:eventhub_mobile/features/auth/presentation/pages/verify_email_page.dart';
import 'package:eventhub_mobile/features/home/presentation/pages/home_discovery_page.dart';
import 'package:eventhub_mobile/features/staff/presentation/pages/staff_dashboard_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoginTab = true;
  bool _isLoading = false;
  bool _isGoogleLoading = false;

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
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

      if (mounted) {
        if (res['success'] == true) {
          final user = res['user'] as UserModel?;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Xin chào ${user?.fullName ?? ''}! (${user?.roleDisplayName ?? 'Khách hàng'})'),
              backgroundColor: Colors.green,
            ),
          );

          if (user != null && user.hasRole('STAFF')) {
            final hasActive = await StaffService().hasActiveOrUpcomingEvents();
            if (!mounted) return;
            setState(() => _isLoading = false);

            if (hasActive) {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const StaffDashboardPage()),
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Tất cả sự kiện của bạn đã kết thúc. Đã chuyển hướng đến giao diện Khách hàng.'),
                  backgroundColor: Colors.orange,
                ),
              );
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const HomeDiscoveryPage()),
              );
            }
          } else if (user != null && user.isStaff) {
            setState(() => _isLoading = false);
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const StaffDashboardPage()),
            );
          } else {
            setState(() => _isLoading = false);
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const HomeDiscoveryPage()),
            );
          }
        } else {
          setState(() => _isLoading = false);
          final msg = res['message']?.toString() ?? 'Đăng nhập không thành công!';
          final isUnverified = msg.toLowerCase().contains('chưa được xác thực') || msg.toLowerCase().contains('chưa kích hoạt');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(msg),
              backgroundColor: AppColors.error,
              action: isUnverified
                  ? SnackBarAction(
                      label: 'Xác thực',
                      textColor: Colors.white,
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => VerifyEmailPage(email: email),
                          ),
                        );
                      },
                    )
                  : null,
            ),
          );
        }
      } else {
        setState(() => _isLoading = false);
      }
    } else {
      // Register Flow
      final fullName = _fullNameController.text.trim();
      if (fullName.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vui lòng nhập Họ và tên!'), backgroundColor: AppColors.error),
        );
        return;
      }

      if (email.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vui lòng nhập địa chỉ Email!'), backgroundColor: AppColors.error),
        );
        return;
      }

      final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
      if (!emailRegex.hasMatch(email)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Địa chỉ Email không đúng định dạng!'), backgroundColor: AppColors.error),
        );
        return;
      }

      final phone = _phoneController.text.trim();
      if (phone.isNotEmpty && !RegExp(r'^[0-9]{9,11}$').hasMatch(phone)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Số điện thoại không hợp lệ (cần 9-11 chữ số)!'), backgroundColor: AppColors.error),
        );
        return;
      }

      if (password.length < 8 ||
          !password.contains(RegExp(r'[A-Z]')) ||
          !password.contains(RegExp(r'[a-z]')) ||
          !password.contains(RegExp(r'[0-9]')) ||
          !password.contains(RegExp(r'[^a-zA-Z0-9]'))) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Mật khẩu phải từ 8 ký tự, gồm ít nhất 1 chữ hoa, 1 chữ thường, 1 số và 1 ký tự đặc biệt!'),
            backgroundColor: AppColors.error,
            duration: Duration(seconds: 4),
          ),
        );
        return;
      }

      final confirmPassword = _confirmPasswordController.text;
      if (password != confirmPassword) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Mật khẩu xác nhận không trùng khớp!'), backgroundColor: AppColors.error),
        );
        return;
      }

      setState(() => _isLoading = true);

      final res = await AuthService().register(
        fullName: fullName,
        email: email,
        password: password,
        phone: phone.isNotEmpty ? phone : null,
      );
      setState(() => _isLoading = false);

      if (mounted) {
        if (res['success'] == true) {
          _showRegisterSuccessDialog(email);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(res['message'] ?? 'Đăng ký thất bại!'), backgroundColor: AppColors.error),
          );
        }
      }
    }
  }

  void _showRegisterSuccessDialog(String registeredEmail) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0C1446),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: AppColors.primaryContainer.withOpacity(0.4)),
        ),
        contentPadding: const EdgeInsets.all(24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.mark_email_read_outlined, color: Colors.green, size: 36),
            ),
            const SizedBox(height: 16),
            const Text(
              'Đăng Ký Thành Công!',
              style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                style: const TextStyle(color: AppColors.secondary, fontSize: 13, height: 1.5),
                children: [
                  const TextSpan(text: 'Chúng tôi đã gửi email kích hoạt đến:\n'),
                  TextSpan(
                    text: registeredEmail,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  const TextSpan(
                    text: '\n\nVui lòng kiểm tra hộp thư đến (hoặc hòm thư Spam) và nhấn vào liên kết xác nhận để kích hoạt tài khoản của bạn trước khi đăng nhập.',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryContainer,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => VerifyEmailPage(email: registeredEmail),
                    ),
                  );
                },
                child: const Text('Nhập Mã Xác Thực Ngay', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                setState(() {
                  _isLoginTab = true;
                  _passwordController.clear();
                  _confirmPasswordController.clear();
                });
              },
              child: const Text('Để sau, về trang Đăng nhập', style: TextStyle(color: AppColors.secondary, fontSize: 13)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isGoogleLoading = true);

    final res = await AuthService().loginWithGoogle();

    if (!mounted) return;
    setState(() => _isGoogleLoading = false);

    if (res['cancelled'] == true) {
      return;
    }

    if (res['success'] == true) {
      final user = res['user'] as UserModel?;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Xin chào ${user?.fullName ?? ''}! (${user?.roleDisplayName ?? 'Khách hàng'})'),
          backgroundColor: Colors.green,
        ),
      );

      if (user != null && user.hasRole('STAFF')) {
        final hasActive = await StaffService().hasActiveOrUpcomingEvents();
        if (!mounted) return;

        if (hasActive) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const StaffDashboardPage()),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Tất cả sự kiện của bạn đã kết thúc. Đã chuyển hướng đến giao diện Khách hàng.'),
              backgroundColor: Colors.orange,
            ),
          );
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const HomeDiscoveryPage()),
          );
        }
      } else if (user != null && user.isStaff) {
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
        SnackBar(
          content: Text(res['message'] ?? 'Đăng nhập Google không thành công!'),
          backgroundColor: AppColors.error,
        ),
      );
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

          if (!_isLoginTab) ...[
            _buildTextField(
              controller: _confirmPasswordController,
              label: 'Xác nhận mật khẩu',
              hint: '••••••••••••',
              icon: Icons.lock_reset,
              isPassword: true,
              obscureText: _obscureConfirmPassword,
              onToggleVisibility: () {
                setState(() => _obscureConfirmPassword = !_obscureConfirmPassword);
              },
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.shield_outlined, color: AppColors.secondary.withOpacity(0.7), size: 14),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Mật khẩu từ 8 ký tự, gồm chữ hoa, chữ thường, số và ký tự đặc biệt.',
                      style: TextStyle(color: AppColors.secondary.withOpacity(0.7), fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

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
            onPressed: (_isLoading || _isGoogleLoading) ? null : _handleSubmit,
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
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: Divider(color: AppColors.secondary.withOpacity(0.15))),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  'HOẶC',
                  style: TextStyle(
                    color: AppColors.secondary.withOpacity(0.6),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1,
                  ),
                ),
              ),
              Expanded(child: Divider(color: AppColors.secondary.withOpacity(0.15))),
            ],
          ),
          const SizedBox(height: 16),
          _buildGoogleSignInButton(),
        ],
      ),
    );
  }

  Widget _buildGoogleSignInButton() {
    return Container(
      width: double.infinity,
      height: 48,
      decoration: BoxDecoration(
        color: const Color(0xFF131F46),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.secondary.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: (_isLoading || _isGoogleLoading) ? null : _handleGoogleSignIn,
          child: _isGoogleLoading
              ? const Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildGoogleLogo(),
                    const SizedBox(width: 12),
                    const Text(
                      'Tiếp tục với Google',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildGoogleLogo() {
    return Container(
      width: 24,
      height: 24,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
      ),
      alignment: Alignment.center,
      child: const Text(
        'G',
        style: TextStyle(
          color: Color(0xFF4285F4),
          fontWeight: FontWeight.bold,
          fontSize: 16,
          fontFamily: 'Roboto',
        ),
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
