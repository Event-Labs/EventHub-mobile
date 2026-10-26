import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/api/ai_service.dart';
import '../../../../core/api/events_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../home/presentation/pages/event_detail_page.dart';
import '../../../home/presentation/pages/ticket_booking_page.dart';
import '../../../tickets/presentation/pages/my_tickets_page.dart';
import '../../../tickets/presentation/pages/ticket_detail_page.dart';

class AiChatPage extends StatefulWidget {
  const AiChatPage({super.key});

  @override
  State<AiChatPage> createState() => _AiChatPageState();
}

class _AiChatPageState extends State<AiChatPage> {
  List<AiChatSession> _sessions = [];
  String? _activeSessionId;
  bool _isLoadingSessions = true;
  bool _isTyping = false;
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _showHistoryDrawer = false;

  final List<String> _quickPrompts = [
    'Sự kiện hot nhất tuần này?',
    'Các sự kiện hot sắp diễn ra?',
    'Hướng dẫn check-in QR tại cổng?',
    'Chính sách hoàn tiền vé thế nào?',
    'Phương thức thanh toán được hỗ trợ?',
    'Kiểm tra vé đã mua của tôi',
  ];

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadSessions() async {
    setState(() => _isLoadingSessions = true);
    try {
      final remoteSessions = await AiService().getSessions();
      if (mounted) {
        if (remoteSessions.isNotEmpty) {
          _sessions = remoteSessions;
          _activeSessionId = remoteSessions.first.id;
        } else {
          final defaultSession = AiChatSession.createDefault();
          _sessions = [defaultSession];
          _activeSessionId = defaultSession.id;
          AiService().saveSession(defaultSession).catchError((_) => false);
        }
      }
    } catch (_) {
      if (mounted) {
        final defaultSession = AiChatSession.createDefault();
        _sessions = [defaultSession];
        _activeSessionId = defaultSession.id;
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingSessions = false);
      }
    }
  }

  AiChatSession get _activeSession {
    if (_sessions.isEmpty) {
      final fallback = AiChatSession.createDefault();
      _sessions.add(fallback);
      _activeSessionId = fallback.id;
      return fallback;
    }
    return _sessions.firstWhere(
      (s) => s.id == _activeSessionId,
      orElse: () => _sessions.first,
    );
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

  void _handleCreateNewChat() {
    final newSession = AiChatSession.createDefault();
    setState(() {
      _sessions.insert(0, newSession);
      _activeSessionId = newSession.id;
      _showHistoryDrawer = false;
      _inputController.clear();
    });
    AiService().saveSession(newSession).catchError((_) => false);
  }

  void _handleSelectSession(String sessionId) {
    setState(() {
      _activeSessionId = sessionId;
      _showHistoryDrawer = false;
    });
    _scrollToBottom();
  }

  Future<void> _handleDeleteSession(String sessionId) async {
    await AiService().deleteSession(sessionId);
    setState(() {
      _sessions.removeWhere((s) => s.id == sessionId);
      if (_sessions.isEmpty) {
        final fresh = AiChatSession.createDefault();
        _sessions.add(fresh);
        _activeSessionId = fresh.id;
        AiService().saveSession(fresh).catchError((_) => false);
      } else if (_activeSessionId == sessionId) {
        _activeSessionId = _sessions.first.id;
      }
    });
  }

  Future<void> _sendMessage([String? presetText]) async {
    final text = presetText ?? _inputController.text.trim();
    if (text.isEmpty || _isTyping) return;

    if (presetText == null) {
      _inputController.clear();
    }

    final currentSession = _activeSession;
    final isFirstUserMessage = !currentSession.messages.any((m) => m.role == 'user');
    final newTitle = (isFirstUserMessage || currentSession.title == 'Đoạn chat mới')
        ? (text.length > 28 ? '${text.substring(0, 28)}...' : text)
        : currentSession.title;

    final userMessage = AiChatMessage(role: 'user', content: text);
    setState(() {
      currentSession.messages.add(userMessage);
      currentSession.title = newTitle;
      currentSession.updatedAt = DateTime.now().millisecondsSinceEpoch;
      _isTyping = true;
    });
    _scrollToBottom();

    // Prepare API history
    final historyPayload = currentSession.messages
        .where((m) => m != userMessage)
        .map((m) => {'role': m.role, 'content': m.content})
        .toList();

    try {
      final response = await AiService().sendChatMessage(
        text,
        history: historyPayload,
        sessionId: currentSession.id,
        title: newTitle,
      );

      if (mounted) {
        setState(() {
          currentSession.messages.add(
            AiChatMessage(role: 'assistant', content: response.rawContent),
          );
          currentSession.updatedAt = DateTime.now().millisecondsSinceEpoch;
          _isTyping = false;
        });
        _scrollToBottom();
        AiService().saveSession(currentSession).catchError((_) => false);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          currentSession.messages.add(
            AiChatMessage(
              role: 'assistant',
              content: 'Dạ Eve vừa gặp một chút gián đoạn kết nối. Bạn vui lòng thử lại sau ít giây nhé! 🔄',
            ),
          );
          _isTyping = false;
        });
        _scrollToBottom();
      }
    }
  }

  void _stopGeneration() {
    if (!_isTyping) return;
    final currentSession = _activeSession;
    setState(() {
      _isTyping = false;
      currentSession.messages.add(
        AiChatMessage(role: 'assistant', content: '_⏹️ Đã dừng phản hồi theo yêu cầu của bạn._'),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final activeSession = _activeSession;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      behavior: HitTestBehavior.translucent,
      child: Scaffold(
        backgroundColor: const Color(0xFF090F1F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D162E),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(
            _showHistoryDrawer ? Icons.close : Icons.menu,
            color: _showHistoryDrawer ? const Color(0xFFE6C17A) : Colors.white70,
          ),
          onPressed: () => setState(() => _showHistoryDrawer = !_showHistoryDrawer),
          tooltip: 'Lịch sử trò chuyện',
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: const Color(0xFFE6C17A).withValues(alpha: 0.15),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFE6C17A).withValues(alpha: 0.3)),
              ),
              child: const Icon(Icons.smart_toy_outlined, color: Color(0xFFE6C17A), size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'EventHub AI',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  Text(
                    activeSession.title != 'Đoạn chat mới' ? activeSession.title : 'Trợ lý hỗ trợ sự kiện & vé',
                    style: const TextStyle(color: Color(0xFFE6C17A), fontSize: 11),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: Colors.white70),
            onPressed: _handleCreateNewChat,
            tooltip: 'Đoạn chat mới',
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Stack(
        children: [
          // Main Chat Area
          Column(
            children: [
              // Message List
              Expanded(
                child: _isLoadingSessions
                    ? const Center(child: CircularProgressIndicator(color: AppColors.primaryContainer))
                    : ListView.builder(
                        controller: _scrollController,
                        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        itemCount: activeSession.messages.length,
                        itemBuilder: (ctx, idx) {
                          final msg = activeSession.messages[idx];
                          return _buildMessageItem(msg);
                        },
                      ),
              ),

              // Typing Indicator & Stop generation bar
              if (_isTyping)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF06B6D4)),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Eve đang trả lời...',
                        style: TextStyle(color: Color(0xFF8B9CB5), fontSize: 12),
                      ),
                      const SizedBox(width: 12),
                      GestureDetector(
                        onTap: _stopGeneration,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF16254F),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white24),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.stop, color: Colors.white70, size: 12),
                              SizedBox(width: 4),
                              Text('Dừng', style: TextStyle(color: Colors.white70, fontSize: 11)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // Quick Prompts Carousel
              if (!_isTyping && activeSession.messages.length <= 4)
                Container(
                  height: 38,
                  margin: const EdgeInsets.only(bottom: 6),
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _quickPrompts.length,
                    itemBuilder: (ctx, i) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ActionChip(
                          backgroundColor: const Color(0xFF101932),
                          side: BorderSide(color: const Color(0xFFE6C17A).withValues(alpha: 0.3)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          avatar: const Icon(Icons.bolt, color: Color(0xFFE6C17A), size: 14),
                          label: Text(
                            _quickPrompts[i],
                            style: const TextStyle(color: Color(0xFFDAE2FF), fontSize: 11, fontWeight: FontWeight.w500),
                          ),
                          onPressed: () {
                            FocusScope.of(context).unfocus();
                            _sendMessage(_quickPrompts[i]);
                          },
                        ),
                      );
                    },
                  ),
                ),

              // Input Bar
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D162E),
                  border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
                ),
                child: SafeArea(
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF101932),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                          ),
                          child: TextField(
                            controller: _inputController,
                            maxLines: 4,
                            minLines: 1,
                            style: const TextStyle(color: Colors.white, fontSize: 14),
                            onSubmitted: (_) => _sendMessage(),
                            decoration: const InputDecoration(
                              hintText: 'Nhắn tin cho EventHub AI...',
                              hintStyle: TextStyle(color: Color(0xFF8B9CB5), fontSize: 13),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      GestureDetector(
                        onTap: _isTyping ? null : () => _sendMessage(),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFC99A47), Color(0xFFE6C17A)],
                            ),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFC99A47).withValues(alpha: 0.35),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: const Icon(Icons.send_rounded, color: Color(0xFF0D1B2A), size: 18),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Slide-in History Drawer Overlay
          if (_showHistoryDrawer)
            Positioned.fill(
              child: GestureDetector(
                onTap: () => setState(() => _showHistoryDrawer = false),
                child: Container(
                  color: Colors.black54,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: GestureDetector(
                      onTap: () {}, // Prevent dismissal when tapping inside drawer
                      child: Container(
                        width: MediaQuery.of(context).size.width * 0.82,
                        height: double.infinity,
                        decoration: const BoxDecoration(
                          color: Color(0xFF090F1F),
                          border: Border(right: BorderSide(color: Colors.white12)),
                        ),
                        child: SafeArea(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Drawer Header
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                decoration: const BoxDecoration(
                                  color: Color(0xFF0D162E),
                                  border: Border(bottom: BorderSide(color: Colors.white12)),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Row(
                                      children: [
                                        Icon(Icons.history, color: Color(0xFFE6C17A), size: 18),
                                        SizedBox(width: 8),
                                        Text(
                                          'Lịch sử trò chuyện',
                                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                                        ),
                                      ],
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.close, color: Colors.white70, size: 20),
                                      onPressed: () => setState(() => _showHistoryDrawer = false),
                                    ),
                                  ],
                                ),
                              ),

                              // New chat button inside drawer
                              Padding(
                                padding: const EdgeInsets.all(14),
                                child: ElevatedButton.icon(
                                  onPressed: _handleCreateNewChat,
                                  icon: const Icon(Icons.add, color: Color(0xFF0D1B2A), size: 18),
                                  label: const Text(
                                    'Đoạn chat mới',
                                    style: TextStyle(color: Color(0xFF0D1B2A), fontWeight: FontWeight.bold),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFE6C17A),
                                    minimumSize: const Size(double.infinity, 44),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                ),
                              ),

                              // Session List
                              Expanded(
                                child: ListView.builder(
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  itemCount: _sessions.length,
                                  itemBuilder: (ctx, idx) {
                                    final s = _sessions[idx];
                                    final isActive = s.id == _activeSessionId;
                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      decoration: BoxDecoration(
                                        color: isActive ? const Color(0xFF16254F) : const Color(0xFF101932),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: isActive ? const Color(0xFFE6C17A) : Colors.white.withValues(alpha: 0.06),
                                          width: isActive ? 1.2 : 1,
                                        ),
                                      ),
                                      child: ListTile(
                                        onTap: () => _handleSelectSession(s.id),
                                        dense: true,
                                        leading: Icon(
                                          Icons.chat_bubble_outline,
                                          color: isActive ? const Color(0xFFE6C17A) : const Color(0xFF8B9CB5),
                                          size: 18,
                                        ),
                                        title: Text(
                                          s.title,
                                          style: TextStyle(
                                            color: isActive ? Colors.white : const Color(0xFFDAE2FF),
                                            fontSize: 13,
                                            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        subtitle: Text(
                                          DateFormat('dd/MM HH:mm').format(DateTime.fromMillisecondsSinceEpoch(s.updatedAt)),
                                          style: const TextStyle(color: Color(0xFF64748B), fontSize: 10),
                                        ),
                                        trailing: IconButton(
                                          icon: const Icon(Icons.delete_outline, color: Color(0xFF94A3B8), size: 18),
                                          onPressed: () => _handleDeleteSession(s.id),
                                          tooltip: 'Xóa đoạn chat',
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
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  );
  }

  Widget _buildMessageItem(AiChatMessage msg) {
    final isUser = msg.role == 'user';

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.88),
        child: Column(
          crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            // Sender Badge for AI
            if (!isUser)
              Padding(
                padding: const EdgeInsets.only(bottom: 6, left: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF06B6D4).withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.auto_awesome, color: Color(0xFF06B6D4), size: 12),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'Eve (EventHub AI)',
                      style: TextStyle(color: Color(0xFF06B6D4), fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),

            // Message Bubble
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isUser ? const Color(0xFF1B365D) : const Color(0xFF101932),
                borderRadius: BorderRadius.circular(18).copyWith(
                  bottomRight: isUser ? const Radius.circular(2) : const Radius.circular(18),
                  topLeft: !isUser ? const Radius.circular(2) : const Radius.circular(18),
                ),
                border: Border.all(
                  color: isUser
                      ? const Color(0xFF38BDF8).withValues(alpha: 0.3)
                      : Colors.white.withValues(alpha: 0.08),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: _buildActionOrTextContent(msg.content, isUser),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionOrTextContent(String content, bool isUser) {
    if (isUser) {
      return Text(
        content,
        style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.45),
      );
    }

    // Parse Action tags like [ACTION:BOOKING_PROPOSAL:...], [ACTION:BOOKING:...], [ACTION:PREFILL_BOOKING:...]
    final actionRegex = RegExp(r'\[ACTION:([A-Z_]+):?([^\]]*)\]');
    final matches = actionRegex.allMatches(content).toList();

    if (matches.isEmpty) {
      return _buildFormattedMarkdown(content);
    }

    final List<Widget> widgets = [];
    int lastIndex = 0;

    for (final match in matches) {
      if (match.start > lastIndex) {
        final textPart = content.substring(lastIndex, match.start).trim();
        if (textPart.isNotEmpty) {
          widgets.add(_buildFormattedMarkdown(textPart));
        }
      }

      final action = match.group(1);
      final rawArgs = match.group(2) ?? '';

      if (action == 'BOOKING_PROPOSAL') {
        widgets.add(_buildBookingProposalCard(rawArgs));
      } else if (action == 'BOOKING') {
        widgets.add(_buildBookingButton(rawArgs));
      } else if (action == 'PREFILL_BOOKING') {
        widgets.add(_buildPrefillBookingButton(rawArgs));
      } else if (action == 'VIEW_EVENT') {
        widgets.add(_buildViewEventButton(rawArgs));
      } else if (action == 'VIEW_TICKET') {
        widgets.add(_buildViewTicketButton(rawArgs));
      }

      lastIndex = match.end;
    }

    if (lastIndex < content.length) {
      final remaining = content.substring(lastIndex).trim();
      if (remaining.isNotEmpty) {
        widgets.add(_buildFormattedMarkdown(remaining));
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }

  Widget _buildFormattedMarkdown(String text) {
    final lines = text.split('\n');
    final List<Widget> lineWidgets = [];

    for (final line in lines) {
      if (line.trim().isEmpty) {
        lineWidgets.add(const SizedBox(height: 6));
        continue;
      }

      // Check header ##
      if (line.startsWith('## ') || line.startsWith('### ')) {
        final headerText = line.replaceFirst(RegExp(r'^#{2,3}\s*'), '');
        lineWidgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 4),
            child: Text(
              headerText,
              style: const TextStyle(color: Color(0xFFE6C17A), fontWeight: FontWeight.bold, fontSize: 15),
            ),
          ),
        );
        continue;
      }

      // Check bullet point
      if (line.trim().startsWith('• ') || line.trim().startsWith('- ') || line.trim().startsWith('* ')) {
        final bulletText = line.trim().substring(2);
        lineWidgets.add(
          Padding(
            padding: const EdgeInsets.only(left: 6, bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('• ', style: TextStyle(color: Color(0xFF06B6D4), fontSize: 14, fontWeight: FontWeight.bold)),
                Expanded(child: _buildRichText(bulletText)),
              ],
            ),
          ),
        );
        continue;
      }

      // Normal paragraph
      lineWidgets.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: _buildRichText(line),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: lineWidgets,
    );
  }

  Widget _buildRichText(String text) {
    // Basic parser for **bold** text
    final parts = text.split('**');
    if (parts.length <= 1) {
      return Text(
        text,
        style: const TextStyle(color: Color(0xFFDAE2FF), fontSize: 13.5, height: 1.45),
      );
    }

    final spans = <TextSpan>[];
    for (int i = 0; i < parts.length; i++) {
      final isBold = i % 2 == 1;
      spans.add(
        TextSpan(
          text: parts[i],
          style: TextStyle(
            color: isBold ? Colors.white : const Color(0xFFDAE2FF),
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            fontSize: 13.5,
            height: 1.45,
          ),
        ),
      );
    }

    return Text.rich(TextSpan(children: spans));
  }

  // Action: Booking Proposal Card (Same as web!)
  Widget _buildBookingProposalCard(String rawPayload) {
    Map<String, dynamic>? proposal;
    try {
      proposal = jsonDecode(Uri.decodeComponent(rawPayload));
    } catch (_) {
      try {
        proposal = jsonDecode(rawPayload);
      } catch (e) {
        proposal = null;
      }
    }

    if (proposal == null) return const SizedBox.shrink();

    final eventTitle = proposal['eventTitle']?.toString() ?? 'Sự kiện EventHub';
    final eventId = proposal['eventId']?.toString() ?? '';
    final session = proposal['session'] is Map ? proposal['session'] : null;
    final sessionName = session?['name']?.toString() ?? 'Buổi diễn';
    final sessionStartTime = session?['start_time']?.toString();
    final venueSummary = proposal['venueSummary']?.toString() ?? 'Tại sự kiện';
    final totalAmount = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ', decimalDigits: 0)
        .format(double.tryParse(proposal['totalAmount']?.toString() ?? '0') ?? 0);
    final seats = proposal['seats'] is List ? (proposal['seats'] as List) : [];
    final hasSeatMap = proposal['hasSeatMap'] == true || seats.isNotEmpty;
    final isComplete = proposal['isAttendeesComplete'] == true;
    final quantity = int.tryParse(proposal['quantity']?.toString() ?? '1') ?? 1;

    return Container(
      margin: const EdgeInsets.only(top: 10, bottom: 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0B2038), Color(0xFF091728), Color(0xFF06101C)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF06B6D4).withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF06B6D4).withValues(alpha: 0.15),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: Color(0xFF22C55E),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'ĐỀ XUẤT ĐẶT VÉ THÔNG MINH',
                    style: TextStyle(color: Color(0xFF06B6D4), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.8),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.4)),
                ),
                child: Text(
                  hasSeatMap ? 'Tạm giữ chỗ' : 'Sẵn sàng đặt',
                  style: const TextStyle(color: Color(0xFFF59E0B), fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),
          Text(
            eventTitle,
            style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),

          // Session & Date
          Row(
            children: [
              const Icon(Icons.theater_comedy, color: Color(0xFFE6C17A), size: 14),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  sessionStartTime != null
                      ? '$sessionName • ${DateFormat('HH:mm dd/MM/yyyy').format(DateTime.parse(sessionStartTime))}'
                      : sessionName,
                  style: const TextStyle(color: Color(0xFFB0CADD), fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),

          // Venue
          Row(
            children: [
              const Icon(Icons.location_on, color: Color(0xFF8B9CB5), size: 14),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  venueSummary,
                  style: const TextStyle(color: Color(0xFF8B9CB5), fontSize: 11),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Seats or Ticket Types
          if (seats.isNotEmpty) ...[
            const Text('Vị trí ghế đề xuất:', style: TextStyle(color: Color(0xFF8B9CB5), fontSize: 11)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: seats.map((s) {
                final label = s['label']?.toString() ?? s['name']?.toString() ?? 'Ghế';
                final type = s['ticketTypeName']?.toString() ?? '';
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF06B6D4).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF06B6D4).withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    '🪑 $label ${type.isNotEmpty ? "($type)" : ""}',
                    style: const TextStyle(color: Color(0xFF06B6D4), fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                );
              }).toList(),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF22C55E).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF22C55E).withValues(alpha: 0.3)),
              ),
              child: Text(
                '🎟️ $quantity vé tham dự',
                style: const TextStyle(color: Color(0xFF22C55E), fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
          ],

          const SizedBox(height: 10),

          // Attendee status
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: isComplete
                  ? const Color(0xFF22C55E).withValues(alpha: 0.12)
                  : const Color(0xFFF59E0B).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isComplete
                    ? const Color(0xFF22C55E).withValues(alpha: 0.3)
                    : const Color(0xFFF59E0B).withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isComplete ? Icons.check_circle : Icons.warning_amber,
                  color: isComplete ? const Color(0xFF22C55E) : const Color(0xFFF59E0B),
                  size: 14,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    isComplete
                        ? 'Đã đủ thông tin người tham gia'
                        : 'Có thể bổ sung thông tin người tham gia khi thanh toán',
                    style: TextStyle(
                      color: isComplete ? const Color(0xFF22C55E) : const Color(0xFFF59E0B),
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const Divider(color: Colors.white12, height: 20),

          // Total Price
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Tổng thanh toán:', style: TextStyle(color: Color(0xFF8B9CB5), fontSize: 12)),
              Text(
                totalAmount,
                style: const TextStyle(color: Color(0xFF22C55E), fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Confirm & Checkout Button
          ElevatedButton(
            onPressed: () async {
              try {
                final event = await EventsService().getEventDetail(eventId);
                if (mounted) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => TicketBookingPage(
                        event: event,
                        initialSessionId: session?['id']?.toString(),
                        initialQuantity: quantity,
                      ),
                    ),
                  );
                }
              } catch (_) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Chuyển tới trang sự kiện...'), duration: Duration(seconds: 1)),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF06B6D4),
              minimumSize: const Size(double.infinity, 44),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '✓ Xác nhận & Đi tới Đặt vé',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                ),
                SizedBox(width: 6),
                Icon(Icons.arrow_forward, color: Colors.white, size: 16),
              ],
            ),
          ),

          const SizedBox(height: 6),

          // Secondary adjustments
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 6,
            runSpacing: 4,
            children: [
              TextButton(
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => EventDetailPage(eventId: eventId)),
                  );
                },
                child: const Text('🪑 Xem chi tiết sự kiện', style: TextStyle(color: Color(0xFF06B6D4), fontSize: 11)),
              ),
              TextButton(
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: () {
                  _inputController.text = 'Tôi muốn đổi sang vé ';
                  _inputController.selection = TextSelection.fromPosition(TextPosition(offset: _inputController.text.length));
                },
                child: const Text('✏️ Đổi số lượng / loại vé', style: TextStyle(color: Color(0xFFE6C17A), fontSize: 11)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBookingButton(String args) {
    final parts = args.split(':');
    final eventId = parts.isNotEmpty ? parts[0] : '';
    final sessionId = parts.length > 1 ? parts[1] : null;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: ElevatedButton(
        onPressed: () async {
          if (eventId.isEmpty) return;
          try {
            final event = await EventsService().getEventDetail(eventId);
            if (mounted) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => TicketBookingPage(event: event, initialSessionId: sessionId),
                ),
              );
            }
          } catch (_) {}
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF0E2744),
          side: const BorderSide(color: Color(0xFF06B6D4)),
          minimumSize: const Size(double.infinity, 44),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('🪑 Nhấn vào đây để chọn ghế & đặt vé', style: TextStyle(color: Color(0xFF06B6D4), fontWeight: FontWeight.bold, fontSize: 12)),
            SizedBox(width: 6),
            Icon(Icons.arrow_forward, color: Color(0xFF06B6D4), size: 14),
          ],
        ),
      ),
    );
  }

  Widget _buildPrefillBookingButton(String args) {
    final parts = args.split(':');
    final eventId = parts.isNotEmpty ? parts[0] : '';
    final sessionId = parts.length > 1 ? parts[1] : null;
    final ticketTypeId = parts.length > 2 ? parts[2] : null;
    final quantity = parts.length > 3 ? int.tryParse(parts[3]) ?? 1 : 1;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: ElevatedButton(
        onPressed: () async {
          if (eventId.isEmpty) return;
          try {
            final event = await EventsService().getEventDetail(eventId);
            if (mounted) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => TicketBookingPage(
                    event: event,
                    initialSessionId: sessionId,
                    initialTicketTypeId: ticketTypeId,
                    initialQuantity: quantity,
                  ),
                ),
              );
            }
          } catch (_) {}
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF0C3124),
          side: const BorderSide(color: Color(0xFF22C55E)),
          minimumSize: const Size(double.infinity, 44),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('🎟️ Nhấn vào đây để xem lại & xác nhận vé', style: TextStyle(color: Color(0xFF22C55E), fontWeight: FontWeight.bold, fontSize: 12)),
            SizedBox(width: 6),
            Icon(Icons.arrow_forward, color: Color(0xFF22C55E), size: 14),
          ],
        ),
      ),
    );
  }

  Widget _buildViewEventButton(String args) {
    final slugOrId = args.trim();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: ElevatedButton(
        onPressed: () {
          if (slugOrId.isNotEmpty) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => EventDetailPage(eventId: slugOrId)),
            );
          }
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF16254F),
          side: const BorderSide(color: Color(0xFFE6C17A)),
          minimumSize: const Size(double.infinity, 42),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.calendar_today, color: Color(0xFFE6C17A), size: 14),
            SizedBox(width: 8),
            Text('Xem chi tiết sự kiện này', style: TextStyle(color: Color(0xFFE6C17A), fontWeight: FontWeight.bold, fontSize: 12)),
            SizedBox(width: 6),
            Icon(Icons.arrow_forward, color: Color(0xFFE6C17A), size: 14),
          ],
        ),
      ),
    );
  }

  Widget _buildViewTicketButton(String ticketId) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: ElevatedButton(
        onPressed: () {
          if (ticketId.isNotEmpty) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => TicketDetailPage(ticketId: ticketId)),
            );
          } else {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const MyTicketsPage()),
            );
          }
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF16254F),
          side: const BorderSide(color: Color(0xFF06B6D4)),
          minimumSize: const Size(double.infinity, 42),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.confirmation_number_outlined, color: Color(0xFF06B6D4), size: 14),
            SizedBox(width: 8),
            Text('Xem vé của bạn trong ví', style: TextStyle(color: Color(0xFF06B6D4), fontWeight: FontWeight.bold, fontSize: 12)),
            SizedBox(width: 6),
            Icon(Icons.arrow_forward, color: Color(0xFF06B6D4), size: 14),
          ],
        ),
      ),
    );
  }
}
