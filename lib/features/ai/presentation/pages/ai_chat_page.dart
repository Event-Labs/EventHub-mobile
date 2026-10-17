import 'package:flutter/material.dart';
import '../../../../core/api/ai_service.dart';
import '../../../../core/models/event_model.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../home/presentation/pages/event_detail_page.dart';

class ChatMessageItem {
  final String sender; // 'user' or 'ai'
  final String text;
  final List<EventModel> suggestedEvents;

  ChatMessageItem({
    required this.sender,
    required this.text,
    this.suggestedEvents = const [],
  });
}

class AiChatPage extends StatefulWidget {
  const AiChatPage({super.key});

  @override
  State<AiChatPage> createState() => _AiChatPageState();
}

class _AiChatPageState extends State<AiChatPage> {
  final List<ChatMessageItem> _messages = [
    ChatMessageItem(
      sender: 'ai',
      text: 'Xin chào! Tôi là Genie - Trợ lý AI thông minh của EventHub. Bạn cần hỗ trợ gì về tìm kiếm sự kiện, giá vé hay hướng dẫn check-in hôm nay?',
    )
  ];
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  bool _isLoading = false;

  final List<String> _quickPrompts = [
    'Sự kiện hot nhất tuần này?',
    'Cách check-in QR tại cổng?',
    'Chính sách hoàn vé thế nào?',
  ];

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage([String? presetText]) async {
    final text = presetText ?? _inputController.text.trim();
    if (text.isEmpty) return;

    if (presetText == null) _inputController.clear();

    final userMsg = ChatMessageItem(sender: 'user', text: text);
    setState(() {
      _messages.add(userMsg);
      _isLoading = true;
    });
    _scrollToBottom();

    // Prepare history payload for backend
    final historyPayload = _messages.map((m) => {
      'role': m.sender == 'user' ? 'user' : 'assistant',
      'content': m.text,
    }).toList();

    final response = await AiService().askGenie(text, history: historyPayload);

    if (mounted) {
      setState(() {
        _messages.add(ChatMessageItem(
          sender: 'ai',
          text: response.text,
          suggestedEvents: response.suggestedEvents,
        ));
        _isLoading = false;
      });
      _scrollToBottom();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF070D1E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF070D1E),
        elevation: 0,
        title: const Row(
          children: [
            Icon(Icons.auto_awesome, color: Color(0xFF06B6D4), size: 22),
            SizedBox(width: 10),
            Text('Trợ Lý AI Genie', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
      ),
      body: Column(
        children: [
          // Chat list
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (ctx, idx) {
                final msg = _messages[idx];
                final isUser = msg.sender == 'user';
                return _buildMessageBubble(msg, isUser);
              },
            ),
          ),

          // Loading indicator
          if (_isLoading)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF06B6D4))),
                  const SizedBox(width: 10),
                  Text('Genie đang trả lời...', style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12)),
                ],
              ),
            ),

          // Quick Prompt chips
          if (_messages.length <= 3 && !_isLoading)
            SizedBox(
              height: 38,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _quickPrompts.length,
                itemBuilder: (ctx, i) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ActionChip(
                      backgroundColor: const Color(0xFF101932),
                      side: BorderSide(color: Colors.white.withOpacity(0.1)),
                      label: Text(
                        _quickPrompts[i],
                        style: const TextStyle(color: Color(0xFFDAE2FF), fontSize: 12),
                      ),
                      onPressed: () => _sendMessage(_quickPrompts[i]),
                    ),
                  );
                },
              ),
            ),

          // Input field
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF0C142A),
              border: Border(top: BorderSide(color: Colors.white.withOpacity(0.08))),
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF101932),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.white.withOpacity(0.1)),
                      ),
                      child: TextField(
                        controller: _inputController,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        onSubmitted: (_) => _sendMessage(),
                        decoration: const InputDecoration(
                          hintText: 'Nhập câu hỏi của bạn...',
                          hintStyle: TextStyle(color: Color(0xFF8B9CB5), fontSize: 13),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: _isLoading ? null : () => _sendMessage(),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.primaryContainer,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(color: AppColors.primaryContainer.withOpacity(0.3), blurRadius: 10),
                        ],
                      ),
                      child: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessageItem msg, bool isUser) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
            decoration: BoxDecoration(
              color: isUser ? AppColors.primaryContainer : const Color(0xFF101932),
              borderRadius: BorderRadius.circular(18).copyWith(
                bottomRight: isUser ? const Radius.circular(2) : const Radius.circular(18),
                topLeft: !isUser ? const Radius.circular(2) : const Radius.circular(18),
              ),
              border: !isUser ? Border.all(color: Colors.white.withOpacity(0.08)) : null,
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 8, offset: const Offset(0, 4)),
              ],
            ),
            child: Text(
              msg.text,
              style: TextStyle(
                color: isUser ? Colors.white : const Color(0xFFDAE2FF),
                fontSize: 14,
                height: 1.45,
              ),
            ),
          ),
          if (msg.suggestedEvents.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: SizedBox(
                height: 110,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: msg.suggestedEvents.length,
                  itemBuilder: (ctx, i) {
                    final evt = msg.suggestedEvents[i];
                    return GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => EventDetailPage(event: evt, eventId: evt.id)),
                        );
                      },
                      child: Container(
                        width: 220,
                        margin: const EdgeInsets.only(right: 10),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF16254F),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.primaryContainer.withOpacity(0.4)),
                        ),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: SizedBox(
                                width: 50,
                                height: 50,
                                child: evt.coverImageUrl != null
                                    ? Image.network(evt.coverImageUrl!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(color: Colors.white10))
                                    : Container(color: Colors.white10),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    evt.title,
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    evt.formattedPrice,
                                    style: const TextStyle(color: Color(0xFFFFB690), fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
