import 'package:flutter/material.dart';
import '../api/api_config.dart';
import '../theme/app_colors.dart';

Future<void> showServerConfigDialog(BuildContext context, {VoidCallback? onApplied}) async {
  final currentClean = ApiConfig.baseUrl.replaceAll('/api', '');
  final controller = TextEditingController(text: currentClean);

  await showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (dialogContext, setDialogState) {
        return AlertDialog(
          backgroundColor: const Color(0xFF0C1446),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: AppColors.primaryContainer.withValues(alpha: 0.3)),
          ),
          title: const Row(
            children: [
              Icon(Icons.dns_rounded, color: AppColors.primaryContainer, size: 24),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Cấu hình Máy chủ (Backend)',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF081033),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Color(0xFF22C55E),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            'Đang kết nối tới:',
                            style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      SelectableText(
                        ApiConfig.baseUrl,
                        style: const TextStyle(
                          color: Color(0xFFE6C17A),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Nhập IP hoặc URL Cloudflare Tunnel:',
                  style: TextStyle(color: AppColors.secondary, fontSize: 13),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: controller,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: const Color(0xFF122155),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                    hintText: 'https://... hoặc 10.0.2.2 hoặc 127.0.0.1',
                    hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    suffixIcon: controller.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, color: Colors.white38, size: 18),
                            onPressed: () {
                              controller.clear();
                              setDialogState(() {});
                            },
                          )
                        : null,
                  ),
                  onChanged: (_) => setDialogState(() {}),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Chọn nhanh:',
                  style: TextStyle(color: Colors.white60, fontSize: 11),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    ActionChip(
                      label: const Text('Cloudflare Tunnel', style: TextStyle(fontSize: 11)),
                      backgroundColor: const Color(0xFF122155),
                      labelStyle: const TextStyle(color: Color(0xFFE6C17A), fontWeight: FontWeight.w600),
                      onPressed: () {
                        controller.text = 'https://agricultural-casino-left-cabin.trycloudflare.com';
                        setDialogState(() {});
                      },
                    ),
                    ActionChip(
                      label: const Text('Máy ảo (10.0.2.2)', style: TextStyle(fontSize: 11)),
                      backgroundColor: const Color(0xFF122155),
                      labelStyle: const TextStyle(color: Colors.white),
                      onPressed: () {
                        controller.text = '10.0.2.2';
                        setDialogState(() {});
                      },
                    ),
                    ActionChip(
                      label: const Text('USB Cáp (127.0.0.1)', style: TextStyle(fontSize: 11)),
                      backgroundColor: const Color(0xFF122155),
                      labelStyle: const TextStyle(color: Colors.white),
                      onPressed: () {
                        controller.text = '127.0.0.1';
                        setDialogState(() {});
                      },
                    ),
                    ActionChip(
                      label: const Text('Wi-Fi (192.168.1.174)', style: TextStyle(fontSize: 11)),
                      backgroundColor: const Color(0xFF122155),
                      labelStyle: const TextStyle(color: Colors.white),
                      onPressed: () {
                        controller.text = '192.168.1.174';
                        setDialogState(() {});
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Đóng', style: TextStyle(color: AppColors.secondary)),
            ),
            ElevatedButton(
              onPressed: () {
                final newHost = controller.text.trim();
                if (newHost.isNotEmpty) {
                  ApiConfig.setDynamicHost(newHost);
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Đã cập nhật máy chủ: ${ApiConfig.baseUrl}'),
                      backgroundColor: Colors.green,
                    ),
                  );
                  onApplied?.call();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryContainer,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Lưu & Áp Dụng', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    ),
  );
}
