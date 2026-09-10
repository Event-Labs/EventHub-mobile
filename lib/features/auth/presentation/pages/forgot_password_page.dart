import 'package:flutter/material.dart';
import '../../../../core/api/auth_service.dart';
import '../../../../core/theme/app_colors.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _emailController = TextEditingController();
  bool _isLoading = false;

  Future<void> _handleReset() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập địa chỉ email hợp lệ!'), backgroundColor: AppColors.error),
      );
      return;
    }

    setState(() => _isLoading = true);
    final result = await AuthService().forgotPassword(email);
    setState(() => _isLoading = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message']),
          backgroundColor: result['success'] ? Colors.green : AppColors.error,
        ),
      );
      if (result['success']) {
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF081126),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Quên mật khẩu', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.lock_reset, size: 64, color: AppColors.primaryContainer),
            const SizedBox(height: 16),
            const Text(
              'Đặt lại mật khẩu',
              style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Nhập địa chỉ email đăng ký tài khoản của bạn. Hệ thống sẽ gửi liên kết khôi phục mật khẩu trong giây lát.',
              style: TextStyle(color: AppColors.secondary, fontSize: 14),
            ),
            const SizedBox(height: 32),
            Container(
              height: 52,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xFF122155),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.secondary.withOpacity(0.2)),
              ),
              child: TextField(
                controller: _emailController,
                style: const TextStyle(color: Colors.white),
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  hintText: 'name@eventhub.vn',
                  hintStyle: TextStyle(color: Colors.white38),
                  prefixIcon: Icon(Icons.mail_outline, color: AppColors.secondary),
                  border: InputBorder.none,
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _handleReset,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryContainer,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isLoading
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Gửi Yêu Cầu Đặt Lại', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
