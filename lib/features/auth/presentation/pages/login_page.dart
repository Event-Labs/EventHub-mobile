import 'package:flutter/material.dart';
import 'package:eventhub_mobile/core/api/api_config.dart';
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

          if (user != null && user.canAccessStaff) {
            final hasActive = await StaffService().hasActiveOrUpcomingEvents();
            if (!mounted) return;
            setState(() => _isLoading = false);

            if (hasActive) {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const StaffDashboardPage()),
                (route) => false,
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Tất cả sự kiện của bạn đã kết thúc. Đã chuyển hướng đến giao diện Khách hàng.'),
                  backgroundColor: Colors.orange,
                ),
              );
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const HomeDiscoveryPage()),
                (route) => false,
              );
            }
          } else {
            setState(() => _isLoading = false);
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const HomeDiscoveryPage()),
              (route) => false,
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
          side: BorderSide(color: AppColors.primaryContainer.withValues(alpha: 0.4)),
        ),
        contentPadding: const EdgeInsets.all(24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.15),
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

      if (user != null && user.canAccessStaff) {
        final hasActive = await StaffService().hasActiveOrUpcomingEvents();
        if (!mounted) return;

        if (hasActive) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const StaffDashboardPage()),
            (route) => false,
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Tất cả sự kiện của bạn đã kết thúc. Đã chuyển hướng đến giao diện Khách hàng.'),
              backgroundColor: Colors.orange,
            ),
          );
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const HomeDiscoveryPage()),
            (route) => false,
          );
        }
      } else {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const HomeDiscoveryPage()),
          (route) => false,
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
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight,
                        ),
                        child: IntrinsicHeight(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _buildAuthCard(),
                              const SizedBox(height: 20),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showServerConfigDialog() {
    final controller = TextEditingController(text: ApiConfig.apiHost);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0C1446),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.dns, color: AppColors.primaryContainer, size: 22),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Cấu hình Server Backend',
                softWrap: true,
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Backend URL hiện tại:\n${ApiConfig.baseUrl}',
              style: const TextStyle(color: Color(0xFF22C55E), fontSize: 12, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text(
              'Nhập IP máy tính chạy backend:',
              style: TextStyle(color: AppColors.secondary, fontSize: 13),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: controller,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFF122155),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                hintText: '10.0.2.2 hoặc 127.0.0.1 hoặc 192.168.1.44',
                hintStyle: const TextStyle(color: Colors.white38),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                ActionChip(
                  label: const Text('Máy ảo (10.0.2.2)', style: TextStyle(fontSize: 11)),
                  backgroundColor: const Color(0xFF122155),
                  labelStyle: const TextStyle(color: Colors.white),
                  onPressed: () => controller.text = '10.0.2.2',
                ),
                ActionChip(
                  label: const Text('USB Cáp (127.0.0.1)', style: TextStyle(fontSize: 11)),
                  backgroundColor: const Color(0xFF122155),
                  labelStyle: const TextStyle(color: Colors.white),
                  onPressed: () => controller.text = '127.0.0.1',
                ),
                ActionChip(
                  label: const Text('Wi-Fi (192.168.1.44)', style: TextStyle(fontSize: 11)),
                  backgroundColor: const Color(0xFF122155),
                  labelStyle: const TextStyle(color: Colors.white),
                  onPressed: () => controller.text = '192.168.1.44',
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Đóng', style: TextStyle(color: AppColors.secondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              final newHost = controller.text.trim();
              if (newHost.isNotEmpty) {
                ApiConfig.setDynamicHost(newHost);
                setState(() {});
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Đã cập nhật: ${ApiConfig.baseUrl}'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryContainer),
            child: const Text('Lưu & Áp Dụng', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Nút X bọc bằng vòng tròn
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                if (Navigator.of(context).canPop()) {
                  Navigator.of(context).pop();
                } else {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => const HomeDiscoveryPage()),
                  );
                }
              },
              borderRadius: BorderRadius.circular(20),
              splashColor: Colors.white12,
              highlightColor: Colors.white.withValues(alpha: 0.05),
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.18),
                    width: 1.0,
                  ),
                ),
                child: const Icon(
                  Icons.close_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ),
          // Vùng chạm ẩn bên phải để giữ tính năng cấu hình server (long-press)
          GestureDetector(
            behavior: HitTestBehavior.translucent,
            onLongPress: _showServerConfigDialog,
            child: const SizedBox(width: 40, height: 40),
          ),
        ],
      ),
    );
  }

  Widget _buildAuthCard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
          // Tiêu đề & phụ đề theo web
          Text(
            _isLoginTab ? 'Đăng nhập' : 'Đăng ký tài khoản',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _isLoginTab
                ? 'Đăng nhập để tiếp tục đặt vé và quản lý sự kiện'
                : 'Tạo tài khoản để trải nghiệm không gian sự kiện đỉnh cao',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.72),
              fontSize: 13.5,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 22),

          // Nút đăng nhập Google ở trên theo web
          _buildGoogleSignInButton(),
          const SizedBox(height: 18),

          // Divider HOẶC EMAIL
          Row(
            children: [
              Expanded(
                child: Divider(
                  color: Colors.white.withValues(alpha: 0.15),
                  thickness: 1,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  'HOẶC EMAIL',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.45),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.1,
                  ),
                ),
              ),
              Expanded(
                child: Divider(
                  color: Colors.white.withValues(alpha: 0.15),
                  thickness: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Form fields
          if (!_isLoginTab) ...[
            _buildTextField(
              controller: _fullNameController,
              label: 'Họ và tên',
              hint: 'Lê Hoàng Nam',
              icon: Icons.person_outline,
            ),
            const SizedBox(height: 14),
            _buildTextField(
              controller: _phoneController,
              label: 'Số điện thoại',
              hint: '0987654321',
              icon: Icons.phone_android_outlined,
            ),
            const SizedBox(height: 14),
          ],

          _buildTextField(
            controller: _emailController,
            label: 'Email',
            hint: 'alex@example.com',
            icon: Icons.mail_outline,
          ),
          const SizedBox(height: 14),
          _buildTextField(
            controller: _passwordController,
            label: 'Mật khẩu',
            hint: '••••••••',
            icon: Icons.lock_outline,
            isPassword: true,
            obscureText: _obscurePassword,
            onToggleVisibility: () {
              setState(() => _obscurePassword = !_obscurePassword);
            },
          ),
          const SizedBox(height: 14),

          if (!_isLoginTab) ...[
            _buildTextField(
              controller: _confirmPasswordController,
              label: 'Xác nhận mật khẩu',
              hint: '••••••••',
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
                  Icon(Icons.shield_outlined, color: Colors.white.withValues(alpha: 0.5), size: 14),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Mật khẩu từ 8 ký tự, gồm chữ hoa, chữ thường, số và ký tự đặc biệt.',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],

          // Ghi nhớ đăng nhập & Quên mật khẩu
          if (_isLoginTab)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 18,
                      height: 18,
                      child: Checkbox(
                        value: true,
                        onChanged: (val) {},
                        activeColor: const Color(0xFFC99A47),
                        checkColor: const Color(0xFF0D1B2A),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                        side: BorderSide(color: Colors.white.withValues(alpha: 0.4), width: 1.5),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Ghi nhớ đăng nhập',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const ForgotPasswordPage()),
                    );
                  },
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    'Quên mật khẩu?',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          const SizedBox(height: 20),

          // Nút submit màu gradient #C99A47 #E6C17A dạng pill bo tròn
          Container(
            width: double.infinity,
            height: 50,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFC99A47), Color(0xFFE6C17A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(25),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFC99A47).withValues(alpha: 0.35),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(25),
                onTap: (_isLoading || _isGoogleLoading) ? null : _handleSubmit,
                child: Center(
                  child: _isLoading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(color: Color(0xFF0D1B2A), strokeWidth: 2.5),
                        )
                      : Text(
                          _isLoginTab ? 'Đăng nhập' : 'Tạo tài khoản',
                          style: const TextStyle(
                            color: Color(0xFF0D1B2A),
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 22),

          // Footer link đổi tab theo web
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _isLoginTab ? 'Chưa có tài khoản? ' : 'Đã có tài khoản? ',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 13.5,
                ),
              ),
              GestureDetector(
                onTap: () => setState(() => _isLoginTab = !_isLoginTab),
                child: Text(
                  _isLoginTab ? 'Tạo tài khoản ngay' : 'Đăng nhập ngay',
                  style: const TextStyle(
                    color: Color(0xFF06B6D4),
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ],
      );
  }

  Widget _buildGoogleSignInButton() {
    return Container(
      width: double.infinity,
      height: 44,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: (_isLoading || _isGoogleLoading) ? null : _handleGoogleSignIn,
          child: _isGoogleLoading
              ? const Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(color: Color(0xFF4285F4), strokeWidth: 2),
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildGoogleLogo(),
                    const SizedBox(width: 10),
                    const Flexible(
                      child: Text(
                        'Tiếp tục sử dụng dịch vụ bằng Google',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Color(0xFF374151),
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildGoogleLogo() {
    return const SizedBox(
      width: 20,
      height: 20,
      child: CustomPaint(
        painter: _GoogleLogoPainter(),
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
          padding: const EdgeInsets.only(left: 2, bottom: 6),
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Container(
          height: 48,
          decoration: BoxDecoration(
            color: const Color(0xFF0F1A33).withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: TextField(
            controller: controller,
            obscureText: obscureText,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(
                color: Colors.white.withValues(alpha: 0.35),
                fontSize: 14,
              ),
              prefixIcon: Icon(icon, color: Colors.white.withValues(alpha: 0.45), size: 20),
              suffixIcon: isPassword
                  ? IconButton(
                      icon: Icon(
                        obscureText ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                        color: Colors.white.withValues(alpha: 0.45),
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
}

class _GoogleLogoPainter extends CustomPainter {
  const _GoogleLogoPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final double r = size.width / 2;
    final double stroke = size.width * 0.22;
    final center = Offset(r, r);
    final rect = Rect.fromCircle(center: center, radius: r - stroke / 2);
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.butt
      ..isAntiAlias = true;

    // Blue arc (right)
    p.color = const Color(0xFF4285F4);
    canvas.drawArc(rect, -0.78, 1.56, false, p);

    // Green arc (bottom)
    p.color = const Color(0xFF34A853);
    canvas.drawArc(rect, 0.78, 1.57, false, p);

    // Yellow arc (left)
    p.color = const Color(0xFFFBBC05);
    canvas.drawArc(rect, 2.35, 1.57, false, p);

    // Red arc (top)
    p.color = const Color(0xFFEA4335);
    canvas.drawArc(rect, 3.92, 1.58, false, p);

    // Blue horizontal bar
    final barPaint = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.fill;
    canvas.drawRect(
      Rect.fromLTWH(center.dx - stroke * 0.1, center.dy - stroke / 2, r * 0.9 + stroke * 0.1, stroke),
      barPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
