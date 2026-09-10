import 'package:flutter/material.dart';
import '../../../../core/api/ai_service.dart';
import '../../../../core/theme/app_colors.dart';

class AiChatPage extends StatefulWidget {
  const AiChatPage({super.key});

  @override
  State<AiChatPage> createState() => _AiChatPageState();
}

class _AiChatPageState extends State<AiChatPage> {
  final List<Map<String, String>> _messages = [
    {
      'sender': 'ai',
      'text': 'Xin chào! Tôi là Genie - Trợ lý AI thông minh của EventHub. Bạn cần hỗ trợ gì về sự kiện, giá vé hay tư vấn đề xuất đêm nay?'
    }
  ];
  final _inputController = TextEditingController();
  bool _isLoading = false;

  Future<void> _sendMessage() async {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add({'sender': 'user', 'text': text});
      _isLoading = true;
    });
    _inputController.clear();

    final response = await AiService().askGenie(text);

    setState(() {
      _messages.add({'sender': 'ai', 'text': response});
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF081126),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0C1446),
        elevation: 0,
        title: const Row(
          children: [
            Icon(Icons.auto_awesome, color: AppColors.tertiary, size: 22),
            SizedBox(width: 8),
            Text('EventHub AI Genie', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (ctx, idx) {
                final msg = _messages[idx];
                final isUser = msg['sender'] == 'user';
                return Align(
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(14),
                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
                    decoration: BoxDecoration(
                      color: isUser ? AppColors.primaryContainer : const Color(0xFF0C1446),
                      borderRadius: BorderRadius.circular(16).copyWith(
                        bottomRight: isUser ? const Radius.circular(0) : const Radius.circular(16),
                        topLeft: !isUser ? const Radius.circular(0) : const Radius.circular(16),
                      ),
                      border: !isUser ? Border.all(color: AppColors.tertiaryContainer.withOpacity(0.3)) : null,
                    ),
                    child: Text(
                      msg['text'] ?? '',
                      style: TextStyle(color: isUser ? Colors.white : Colors.white70, fontSize: 14, height: 1.4),
                    ),
                  ),
                );
              },
            ),
          ),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.tertiary)),
                  SizedBox(width: 8),
                  Text('Genie đang phản hồi...', style: TextStyle(color: AppColors.secondary, fontSize: 12)),
                ],
              ),
            ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: Color(0xFF0C1446),
              border: Border(top: BorderSide(color: Colors.white12)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 48,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF122155),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: TextField(
                      controller: _inputController,
                      style: const TextStyle(color: Colors.white),
                      onSubmitted: (_) => _sendMessage(),
                      decoration: const InputDecoration(
                        hintText: 'Hỏi Genie về sự kiện, giá vé...',
                        hintStyle: TextStyle(color: Colors.white38, fontSize: 13),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const CircleAvatar(
                    backgroundColor: AppColors.tertiaryContainer,
                    child: Icon(Icons.send, color: Colors.white, size: 18),
                  ),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
