import 'package:flutter/material.dart';
import '../../../../core/api/auth_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_background.dart';
import 'package:eventhub_mobile/core/models/user_model.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  late TextEditingController _fullNameController;
  late TextEditingController _phoneController;
  late TextEditingController _cityController;
  late TextEditingController _addressController;
  late TextEditingController _dobController;
  late TextEditingController _avatarUrlController;
  late TextEditingController _bioController;

  @override
  void initState() {
    super.initState();
    final user = AuthService().currentUser;

    _fullNameController = TextEditingController(text: user?.fullName ?? '');
    _phoneController = TextEditingController(text: user?.phone ?? '');
    _cityController = TextEditingController(text: user?.city ?? '');
    _addressController = TextEditingController(text: user?.address ?? '');
    _dobController = TextEditingController(text: UserModel.parseDob(user?.dob) ?? '');
    _avatarUrlController = TextEditingController(text: user?.avatarUrl ?? '');
    _bioController = TextEditingController(text: user?.bio ?? '');
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    _cityController.dispose();
    _addressController.dispose();
    _dobController.dispose();
    _avatarUrlController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  bool _validateVietnamesePhone(String phone) {
    if (phone.isEmpty) return true;
    final regex = RegExp(r'^(0|\+84)(3|5|7|8|9)[0-9]{8}$');
    return regex.hasMatch(phone);
  }

  Future<void> _selectDateOfBirth() async {
    DateTime initialDate = DateTime.now().subtract(const Duration(days: 365 * 18));
    if (_dobController.text.isNotEmpty) {
      final parsed = DateTime.tryParse(_dobController.text.trim());
      if (parsed != null) {
        initialDate = parsed.isUtc ? parsed.toLocal() : parsed;
      }
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1920),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppColors.primaryContainer,
              onPrimary: Colors.black,
              surface: Color(0xFF0C1446),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      final formatted = "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
      setState(() {
        _dobController.text = formatted;
      });
    }
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    final phone = _phoneController.text.trim();
    if (phone.isNotEmpty && !_validateVietnamesePhone(phone)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Số điện thoại không hợp lệ (Ví dụ: 0912345678 hoặc +84912345678)'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    final res = await AuthService().updateProfile(
      fullName: _fullNameController.text.trim(),
      phone: phone.isEmpty ? null : phone,
      city: _cityController.text.trim().isEmpty ? null : _cityController.text.trim(),
      address: _addressController.text.trim().isEmpty ? null : _addressController.text.trim(),
      dob: _dobController.text.trim().isEmpty ? null : _dobController.text.trim(),
      avatarUrl: _avatarUrlController.text.trim().isEmpty ? null : _avatarUrlController.text.trim(),
      bio: _bioController.text.trim().isEmpty ? null : _bioController.text.trim(),
    );

    setState(() => _isLoading = false);

    if (mounted) {
      if (res['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['message'] ?? 'Cập nhật thông tin thành công!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop(true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['message'] ?? 'Cập nhật thất bại, vui lòng thử lại.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final avatarUrl = _avatarUrlController.text.trim();

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
        title: const Text(
          'Chỉnh Sửa Hồ Sơ',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Avatar Preview & Input
                  Center(
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 46,
                          backgroundColor: AppColors.primaryContainer,
                          backgroundImage: avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
                          child: avatarUrl.isEmpty
                              ? Text(
                                  _fullNameController.text.isNotEmpty
                                      ? _fullNameController.text[0].toUpperCase()
                                      : 'U',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 34,
                                    fontWeight: FontWeight.bold,
                                  ),
                                )
                              : null,
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Xem trước ảnh đại diện',
                          style: TextStyle(color: AppColors.secondary, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Avatar URL field
                  _buildTextField(
                    controller: _avatarUrlController,
                    label: 'Link Ảnh Đại Diện (Avatar URL)',
                    hint: 'https://example.com/avatar.jpg',
                    icon: Icons.link,
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 16),

                  // Full Name field
                  _buildTextField(
                    controller: _fullNameController,
                    label: 'Họ và tên',
                    hint: 'Nhập họ và tên',
                    icon: Icons.person_outline,
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Vui lòng nhập họ và tên';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Phone field
                  _buildTextField(
                    controller: _phoneController,
                    label: 'Số điện thoại',
                    hint: '0912345678',
                    icon: Icons.phone_outlined,
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 16),

                  // Date of Birth field
                  GestureDetector(
                    onTap: _selectDateOfBirth,
                    child: AbsorbPointer(
                      child: _buildTextField(
                        controller: _dobController,
                        label: 'Ngày sinh',
                        hint: 'YYYY-MM-DD',
                        icon: Icons.cake_outlined,
                        suffixIcon: const Icon(Icons.calendar_today, color: AppColors.primaryContainer, size: 20),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // City field
                  _buildTextField(
                    controller: _cityController,
                    label: 'Tỉnh / Thành phố',
                    hint: 'Ví dụ: TP. Hồ Chí Minh, Hà Nội',
                    icon: Icons.location_city_outlined,
                  ),
                  const SizedBox(height: 16),

                  // Address field
                  _buildTextField(
                    controller: _addressController,
                    label: 'Địa chỉ chi tiết',
                    hint: 'Nhập địa chỉ của bạn',
                    icon: Icons.home_outlined,
                  ),
                  const SizedBox(height: 16),

                  // Bio field
                  _buildTextField(
                    controller: _bioController,
                    label: 'Giới thiệu (Bio)',
                    hint: 'Chia sẻ ngắn gọn về sở thích âm nhạc...',
                    icon: Icons.notes_outlined,
                    maxLines: 3,
                  ),
                  const SizedBox(height: 32),

                  // Submit Button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _handleSave,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryContainer,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 4,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2.5),
                            )
                          : const Text(
                              'LƯU THAY ĐỔI',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    Widget? suffixIcon,
    String? Function(String?)? validator,
    void Function(String)? onChanged,
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
          keyboardType: keyboardType,
          maxLines: maxLines,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          validator: validator,
          onChanged: onChanged,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Colors.white30, fontSize: 13),
            prefixIcon: Icon(icon, color: AppColors.primaryContainer, size: 20),
            suffixIcon: suffixIcon,
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
