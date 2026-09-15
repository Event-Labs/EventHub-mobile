import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/api/auth_service.dart';
import '../../../../core/theme/app_colors.dart';
import 'login_page.dart';

class VerifyEmailPage extends StatefulWidget {
  final String? email;
  final String? initialToken;

  const VerifyEmailPage({
    super.key,
    this.email,
    this.initialToken,
  });

  @override
  State<VerifyEmailPage> createState() => _VerifyEmailPageState();
}

class _VerifyEmailPageState extends State<VerifyEmailPage> {
  final _tokenController = TextEditingController();
  bool _isLoading = false;
  bool _isSuccess = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    if (widget.initialToken != null && widget.initialToken!.isNotEmpty) {
      _tokenController.text = _extractToken(widget.initialToken!);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handleVerify();
      });
    }
  }

  @override
  void dispose() {
    _tokenController.dispose();
    super.dispose();
  }

  /// Trích xuất mã token kể cả khi người dùng dán nguyên URL nhận từ email
  String _extractToken(String input) {
    final trimmed = input.trim();
    if (trimmed.contains('token=')) {
      try {
        final uri = Uri.parse(trimmed);
        final token = uri.queryParameters['token'];
        if (token != null && token.isNotEmpty) {
          return token;
        }
      } catch (_) {}
      final split = trimmed.split('token=');
      if (split.length > 1) {
        return split[1].split('&').first.trim();
      }
    }
    return trimmed;
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null && data!.text!.trim().isNotEmpty) {
      final extracted = _extractToken(data.text!);
      setState(() {
        _tokenController.text = extracted;
        _errorMessage = null;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã dán mã xác thực từ clipboard!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _handleVerify() async {
    final token = _extractToken(_tokenController.text);
    if (token.isEmpty) {
      setState(() {
        _errorMessage = 'Vui lòng nhập hoặc dán mã xác thực nhận từ email!';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final res = await AuthService().verifyEmail(token);

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (res['success'] == true) {
      setState(() => _isSuccess = true);
    } else {
      setState(() {
        _errorMessage = res['message'] ?? 'Mã xác thực không hợp lệ hoặc đã hết hạn!';
      });
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
        title: const Text(
          'Xác thực tài khoản',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: _isSuccess ? _buildSuccessView() : _buildVerifyForm(),
        ),
      ),
    );
  }

  Widget _buildVerifyForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.primaryContainer.withOpacity(0.12),
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.primaryContainer.withOpacity(0.3)),
            ),
            child: const Icon(Icons.mark_email_unread_outlined, size: 42, color: AppColors.primaryContainer),
          ),
        ),
        const SizedBox(height: 24),
        const Center(
          child: Text(
            'Kích Hoạt Tài Khoản',
            style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: Text(
            widget.email != null && widget.email!.isNotEmpty
                ? 'Hệ thống đã gửi liên kết xác thực đến hộp thư:\n${widget.email}'
                : 'Vui lòng kiểm tra hộp thư (cả mục Spam) để lấy mã xác thực kích hoạt tài khoản.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.secondary, fontSize: 14, height: 1.5),
          ),
        ),
        const SizedBox(height: 32),

        // Auth Card for Token Input
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xE60C1446),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.secondary.withOpacity(0.15)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Mã xác thực / Liên kết',
                    style: TextStyle(color: AppColors.secondary, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  TextButton.icon(
                    onPressed: _isLoading ? null : _pasteFromClipboard,
                    icon: const Icon(Icons.content_paste, size: 16, color: AppColors.primary),
                    label: const Text(
                      'Dán mã',
                      style: TextStyle(color: AppColors.primary, fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(50, 30)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF122155),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _errorMessage != null
                        ? AppColors.error
                        : AppColors.secondary.withOpacity(0.2),
                  ),
                ),
                child: TextField(
                  controller: _tokenController,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText: 'Nhập mã token hoặc dán liên kết xác thực...',
                    hintStyle: TextStyle(color: AppColors.secondary.withOpacity(0.4), fontSize: 13),
                    prefixIcon: const Icon(Icons.vpn_key_outlined, color: AppColors.secondary, size: 20),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                ),
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.error_outline, size: 14, color: AppColors.error),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: AppColors.error, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleVerify,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryContainer,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 6,
                    shadowColor: AppColors.primaryContainer.withOpacity(0.4),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.verified_outlined, size: 18),
                            SizedBox(width: 8),
                            Text('Kích Hoạt Tài Khoản', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                          ],
                        ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),
        Center(
          child: TextButton(
            onPressed: () {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginPage()),
                (route) => false,
              );
            },
            child: const Text(
              'Quay lại trang Đăng nhập',
              style: TextStyle(color: AppColors.secondary, fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSuccessView() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: const Color(0xE60C1446),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.green.withOpacity(0.3)),
          boxShadow: [
            BoxShadow(
              color: Colors.green.withOpacity(0.1),
              blurRadius: 40,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_outline, color: Colors.green, size: 48),
            ),
            const SizedBox(height: 20),
            const Text(
              'Xác Thực Thành Công!',
              style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            const Text(
              'Email của bạn đã được xác nhận thành công. Tài khoản EventHub hiện đã sẵn sàng để đăng nhập và sử dụng.',
              style: TextStyle(color: AppColors.secondary, fontSize: 14, height: 1.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 6,
                ),
                onPressed: () {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const LoginPage()),
                    (route) => false,
                  );
                },
                child: const Text(
                  'Đăng Nhập Ngay',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
