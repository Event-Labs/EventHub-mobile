import 'package:flutter/material.dart';
import '../../../../core/api/auth_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_background.dart';
import '../../../auth/presentation/pages/login_page.dart';

class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleChangePassword(bool hasPassword) async {
    if (!_formKey.currentState!.validate()) return;

    final currentPassword = _currentPasswordController.text.trim();
    final newPassword = _newPasswordController.text;

    setState(() => _isLoading = true);

    final res = await AuthService().changePassword(
      currentPassword: hasPassword ? currentPassword : null,
      newPassword: newPassword,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (res['success'] == true) {
      _showSuccessDialog(hasPassword);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['message'] ?? 'Đổi mật khẩu thất bại, vui lòng kiểm tra lại.'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  void _showSuccessDialog(bool hasPassword) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0C1446),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Colors.green.withOpacity(0.4)),
        ),
        contentPadding: const EdgeInsets.all(24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_outline, color: Colors.green, size: 40),
            ),
            const SizedBox(height: 18),
            Text(
              hasPassword ? 'Đổi Mật Khẩu Thành Công!' : 'Thiết Lập Mật Khẩu Thành Công!',
              style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            const Text(
              'Mật khẩu của bạn đã được cập nhật thành công. Bạn có thể sử dụng mật khẩu mới để đăng nhập ở các lần tiếp theo.',
              style: TextStyle(color: AppColors.secondary, fontSize: 13, height: 1.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryContainer,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 6,
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.pop(context, true);
                },
                child: const Text('Hoàn tất', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                AuthService().logout();
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginPage()),
                  (route) => false,
                );
              },
              child: const Text('Đăng xuất để thử đăng nhập lại', style: TextStyle(color: AppColors.secondary, fontSize: 13)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService().currentUser;
    final bool hasPassword = user?.hasPassword ?? true;

    final titleText = hasPassword ? 'Đổi Mật Khẩu' : 'Thiết Lập Mật Khẩu';

    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          titleText,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF0C1446),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.primaryContainer.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.shield_outlined, color: AppColors.primaryContainer, size: 28),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        hasPassword
                            ? 'Mật khẩu mới phải từ 8 ký tự, gồm ít nhất 1 chữ hoa, 1 chữ thường, 1 số, 1 ký tự đặc biệt và không trùng với mật khẩu cũ.'
                            : 'Tài khoản của bạn đăng nhập qua Google. Hãy tạo mật khẩu bảo mật để có thể đăng nhập bằng email và mật khẩu.',
                        style: const TextStyle(color: AppColors.secondary, fontSize: 12, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Current Password (only if user already has a password)
              if (hasPassword) ...[
                _buildPasswordField(
                  controller: _currentPasswordController,
                  label: 'Mật khẩu hiện tại',
                  hint: 'Nhập mật khẩu hiện tại của bạn',
                  obscureText: _obscureCurrent,
                  onToggleVisibility: () => setState(() => _obscureCurrent = !_obscureCurrent),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Vui lòng nhập mật khẩu hiện tại';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
              ],

              // New Password
              _buildPasswordField(
                controller: _newPasswordController,
                label: 'Mật khẩu mới',
                hint: '••••••••••••',
                obscureText: _obscureNew,
                onToggleVisibility: () => setState(() => _obscureNew = !_obscureNew),
                validator: (val) {
                  if (val == null || val.isEmpty) {
                    return 'Vui lòng nhập mật khẩu mới';
                  }
                  if (val.length < 8 ||
                      !val.contains(RegExp(r'[A-Z]')) ||
                      !val.contains(RegExp(r'[a-z]')) ||
                      !val.contains(RegExp(r'[0-9]')) ||
                      !val.contains(RegExp(r'[^a-zA-Z0-9]'))) {
                    return 'Mật khẩu từ 8 ký tự, gồm ít nhất 1 chữ hoa, 1 thường, 1 số và 1 ký tự đặc biệt';
                  }
                  if (hasPassword && val.trim() == _currentPasswordController.text.trim()) {
                    return 'Mật khẩu mới không được trùng với mật khẩu hiện tại';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Confirm New Password
              _buildPasswordField(
                controller: _confirmPasswordController,
                label: 'Xác nhận mật khẩu mới',
                hint: '••••••••••••',
                obscureText: _obscureConfirm,
                onToggleVisibility: () => setState(() => _obscureConfirm = !_obscureConfirm),
                validator: (val) {
                  if (val == null || val != _newPasswordController.text) {
                    return 'Mật khẩu xác nhận không trùng khớp';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, color: AppColors.secondary.withOpacity(0.7), size: 14),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Yêu cầu: Tối thiểu 8 ký tự, 1 chữ hoa, 1 chữ thường, 1 chữ số và 1 ký tự đặc biệt.',
                        style: TextStyle(color: AppColors.secondary.withOpacity(0.7), fontSize: 11),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Submit Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : () => _handleChangePassword(hasPassword),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryContainer,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 6,
                    shadowColor: AppColors.primaryContainer.withOpacity(0.4),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.2),
                        )
                      : Text(
                          hasPassword ? 'CẬP NHẬT MẬT KHẨU' : 'TẠO MẬT KHẨU',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required bool obscureText,
    required VoidCallback onToggleVisibility,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          validator: validator,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Colors.white30, fontSize: 13),
            prefixIcon: const Icon(Icons.lock_outline, color: AppColors.primaryContainer, size: 20),
            suffixIcon: IconButton(
              icon: Icon(
                obscureText ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                color: AppColors.secondary,
                size: 20,
              ),
              onPressed: onToggleVisibility,
            ),
            filled: true,
            fillColor: const Color(0xFF0C1446),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.secondary.withOpacity(0.15)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.primaryContainer, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.error),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.error, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}
