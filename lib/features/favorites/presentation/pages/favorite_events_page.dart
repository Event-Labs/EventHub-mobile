import 'package:flutter/material.dart';
import '../../../../core/api/auth_service.dart';
import '../../../../core/api/events_service.dart';
import '../../../auth/presentation/pages/login_page.dart';
import '../../../../core/models/event_model.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../home/presentation/pages/event_detail_page.dart';
import '../../../home/presentation/widgets/event_card.dart';

class FavoriteEventsPage extends StatefulWidget {
  const FavoriteEventsPage({super.key});

  @override
  State<FavoriteEventsPage> createState() => _FavoriteEventsPageState();
}

class _FavoriteEventsPageState extends State<FavoriteEventsPage> {
  List<EventModel> _favorites = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    if (AuthService().currentUser != null && AuthService().isLoggedIn) {
      _loadFavorites();
    } else {
      _isLoading = false;
    }
  }

  Future<void> _loadFavorites() async {
    setState(() => _isLoading = true);
    final list = await EventsService().getFavoriteEvents();
    if (mounted) {
      setState(() {
        _favorites = list;
        _isLoading = false;
      });
    }
  }

  Future<void> _handleToggleFavorite(EventModel event) async {
    final res = await EventsService().toggleFavorite(event.id);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['message'] ?? 'Đã cập nhật yêu thích'),
          backgroundColor: Colors.black87,
          duration: const Duration(seconds: 2),
        ),
      );
      _loadFavorites();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (AuthService().currentUser == null || !AuthService().isLoggedIn) {
      return Scaffold(
        backgroundColor: const Color(0xFF070D1E),
        appBar: AppBar(
          automaticallyImplyLeading: false,
          backgroundColor: const Color(0xFF070D1E),
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          title: const Text(
            'Sự kiện Yêu thích',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFF101932),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                  ),
                  child: const Icon(Icons.favorite_border, color: Color(0xFFE6C17A), size: 48),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Vui lòng đăng nhập để xem danh sách sự kiện yêu thích của bạn.',
                  style: TextStyle(color: Color(0xFFB0CADD), fontSize: 14),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Container(
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFC99A47), Color(0xFFE6C17A)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
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
                      borderRadius: BorderRadius.circular(24),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const LoginPage()),
                        ).then((_) {
                          if (mounted && AuthService().currentUser != null) {
                            _loadFavorites();
                          }
                        });
                      },
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 28),
                        child: Center(
                          child: Text(
                            'Đăng Nhập Ngay',
                            style: TextStyle(color: Color(0xFF0D1B2A), fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF070D1E),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: const Color(0xFF070D1E),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Sự kiện Yêu thích',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primaryContainer))
          : _favorites.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  color: AppColors.primaryContainer,
                  backgroundColor: const Color(0xFF101932),
                  onRefresh: _loadFavorites,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _favorites.length,
                    itemBuilder: (ctx, idx) {
                      final event = _favorites[idx];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: EventCardWidget(
                          event: event.copyWith(isFavorited: true),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => EventDetailPage(event: event, eventId: event.id),
                              ),
                            ).then((_) => _loadFavorites());
                          },
                          onFavoriteToggle: () => _handleToggleFavorite(event),
                        ),
                      );
                    },
                  ),
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF101932),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withOpacity(0.08)),
              ),
              child: const Icon(Icons.favorite_border, color: Color(0xFFE6C17A), size: 48),
            ),
            const SizedBox(height: 20),
            const Text(
              'Chưa có sự kiện yêu thích',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Nhấn vào biểu tượng trái tim trên các sự kiện để lưu lại và theo dõi lịch diễn sau này.',
              style: TextStyle(color: Color(0xFFB0CADD), fontSize: 13, height: 1.4),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
