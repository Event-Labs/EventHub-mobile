import 'package:flutter/material.dart';
import '../../../../core/api/events_service.dart';
import '../../../../core/api/notifications_service.dart';
import '../../../../core/models/event_model.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../ai/presentation/pages/ai_chat_page.dart';
import '../../../favorites/presentation/pages/favorite_events_page.dart';
import '../../../notifications/presentation/pages/notifications_page.dart';
import '../../../profile/presentation/pages/profile_page.dart';
import '../../../tickets/presentation/pages/my_tickets_page.dart';
import '../widgets/event_card.dart';
import 'event_detail_page.dart';

class HomeDiscoveryPage extends StatefulWidget {
  const HomeDiscoveryPage({super.key});

  @override
  State<HomeDiscoveryPage> createState() => _HomeDiscoveryPageState();
}

class _HomeDiscoveryPageState extends State<HomeDiscoveryPage> {
  int _currentBottomNavIndex = 0;
  List<EventCategoryModel> _categories = [];
  List<EventModel> _events = [];
  bool _isLoading = true;
  String _selectedCategoryId = 'all';
  final _searchController = TextEditingController();
  int _unreadNotiCount = 0;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    final categories = await EventsService().getCategories();
    final events = await EventsService().getPublicEvents();
    final notiCount = await NotificationsService().getUnreadCount();

    if (mounted) {
      setState(() {
        _categories = categories;
        _events = events;
        _unreadNotiCount = notiCount;
        _isLoading = false;
      });
    }
  }

  Future<void> _filterEvents() async {
    setState(() => _isLoading = true);
    final events = await EventsService().getPublicEvents(
      search: _searchController.text.trim(),
      categoryId: _selectedCategoryId,
    );
    if (mounted) {
      setState(() {
        _events = events;
        _isLoading = false;
      });
    }
  }

  Future<void> _handleToggleFavorite(EventModel event) async {
    final res = await EventsService().toggleFavorite(event.id);
    if (mounted) {
      final isFav = res['isFavorited'] ?? !event.isFavorited;
      setState(() {
        final idx = _events.indexWhere((e) => e.id == event.id);
        if (idx != -1) {
          _events[idx] = _events[idx].copyWith(isFavorited: isFav);
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['message'] ?? (isFav ? 'Đã thêm vào yêu thích' : 'Đã xóa khỏi yêu thích')),
          duration: const Duration(seconds: 1),
          backgroundColor: Colors.black87,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget bodyContent;
    switch (_currentBottomNavIndex) {
      case 1:
        bodyContent = const FavoriteEventsPage();
        break;
      case 2:
        bodyContent = const MyTicketsPage();
        break;
      case 3:
        bodyContent = const AiChatPage();
        break;
      case 4:
        bodyContent = const ProfilePage();
        break;
      case 0:
      default:
        bodyContent = _buildDiscoveryContent();
        break;
    }

    return Scaffold(
      backgroundColor: const Color(0xFF070D1E),
      body: bodyContent,
      bottomNavigationBar: _buildBottomNavBar(),
    );
  }

  Widget _buildDiscoveryContent() {
    final featured = _events.where((e) => e.isFeatured).toList();
    final displayFeatured = featured.isNotEmpty ? featured : _events.take(2).toList();

    return Scaffold(
      backgroundColor: const Color(0xFF070D1E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF070D1E),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primaryContainer, Color(0xFFE6C17A)],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.local_activity, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 10),
            ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [Color(0xFFFFB690), Color(0xFFE6C17A)],
              ).createShader(bounds),
              child: const Text(
                'EventHub',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 22,
                  letterSpacing: -0.5,
                ),
              ),
            ),
          ],
        ),
        actions: [
          // Notification bell with unread badge
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_none, color: Colors.white, size: 24),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const NotificationsPage()),
                  ).then((_) async {
                    final count = await NotificationsService().getUnreadCount();
                    if (mounted) setState(() => _unreadNotiCount = count);
                  });
                },
              ),
              if (_unreadNotiCount > 0)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: AppColors.primaryContainer,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                    child: Text(
                      '$_unreadNotiCount',
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          // Avatar
          GestureDetector(
            onTap: () => setState(() => _currentBottomNavIndex = 4),
            child: const Padding(
              padding: EdgeInsets.only(right: 16, left: 4),
              child: CircleAvatar(
                radius: 17,
                backgroundColor: Color(0xFF1E2846),
                child: Icon(Icons.person, color: Color(0xFFE6C17A), size: 18),
              ),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.primaryContainer,
        backgroundColor: const Color(0xFF101932),
        onRefresh: _loadInitialData,
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Search Input Box
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF101932),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withOpacity(0.08)),
                  ),
                  child: TextField(
                    controller: _searchController,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    onSubmitted: (_) => _filterEvents(),
                    decoration: InputDecoration(
                      hintText: 'Tìm kiếm sự kiện, nghệ sĩ, địa điểm...',
                      hintStyle: const TextStyle(color: Color(0xFF8B9CB5), fontSize: 13),
                      prefixIcon: const Icon(Icons.search, color: Color(0xFF8B9CB5), size: 20),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, color: Colors.white38, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                _filterEvents();
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ),

              // Categories Horizontal Scroll
              SizedBox(
                height: 44,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _categories.length,
                  itemBuilder: (ctx, idx) {
                    final cat = _categories[idx];
                    final isSelected = _selectedCategoryId == cat.id;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () {
                          setState(() => _selectedCategoryId = cat.id);
                          _filterEvents();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected ? AppColors.primaryContainer : const Color(0xFF101932),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isSelected ? AppColors.primaryContainer : Colors.white.withOpacity(0.08),
                            ),
                          ),
                          child: Center(
                            child: Text(
                              cat.name,
                              style: TextStyle(
                                color: isSelected ? Colors.white : const Color(0xFFDAE2FF),
                                fontSize: 13,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 24),

              // Featured Hero Spotlight Section
              if (displayFeatured.isNotEmpty) ...[
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'Sự Kiện Nổi Bật',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 220,
                  child: PageView.builder(
                    controller: PageController(viewportFraction: 0.9),
                    itemCount: displayFeatured.length,
                    itemBuilder: (ctx, idx) {
                      final item = displayFeatured[idx];
                      return GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => EventDetailPage(event: item, eventId: item.id)),
                          ).then((_) => _loadInitialData());
                        },
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 6),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(color: Colors.white.withOpacity(0.1)),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Stack(
                            children: [
                              Positioned.fill(
                                child: item.coverImageUrl != null
                                    ? Image.network(item.coverImageUrl!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(color: const Color(0xFF1E2846)))
                                    : Container(color: const Color(0xFF1E2846)),
                              ),
                              Positioned.fill(
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Colors.transparent,
                                        const Color(0xFF070D1E).withOpacity(0.95),
                                      ],
                                      stops: const [0.4, 1.0],
                                    ),
                                  ),
                                ),
                              ),
                              Positioned(
                                top: 12,
                                left: 14,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(colors: [Color(0xFFF97316), Color(0xFFE6C17A)]),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: const Text('SPOTLIGHT', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                ),
                              ),
                              Positioned(
                                bottom: 16,
                                left: 16,
                                right: 16,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.title,
                                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${item.formattedDateTime} • ${item.locationSummary}',
                                      style: const TextStyle(color: Color(0xFFB0CADD), fontSize: 12),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
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
                const SizedBox(height: 28),
              ],

              // Events List (All / Filtered)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Tất Cả Sự Kiện',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.2,
                      ),
                    ),
                    Text(
                      '${_events.length} sự kiện',
                      style: const TextStyle(color: Color(0xFF8B9CB5), fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              if (_isLoading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(40),
                    child: CircularProgressIndicator(color: AppColors.primaryContainer),
                  ),
                )
              else if (_events.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(40),
                    child: Column(
                      children: [
                        const Icon(Icons.event_busy, color: Colors.white24, size: 50),
                        const SizedBox(height: 12),
                        const Text('Không tìm thấy sự kiện nào.', style: TextStyle(color: Color(0xFFB0CADD), fontSize: 14)),
                      ],
                    ),
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _events.length,
                  itemBuilder: (ctx, idx) {
                    final event = _events[idx];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: EventCardWidget(
                        event: event,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => EventDetailPage(event: event, eventId: event.id)),
                          ).then((_) => _loadInitialData());
                        },
                        onFavoriteToggle: () => _handleToggleFavorite(event),
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNavBar() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0C142A),
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.08))),
      ),
      child: NavigationBar(
        selectedIndex: _currentBottomNavIndex,
        onDestinationSelected: (idx) => setState(() => _currentBottomNavIndex = idx),
        backgroundColor: Colors.transparent,
        indicatorColor: AppColors.primaryContainer.withOpacity(0.2),
        elevation: 0,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.explore_outlined, color: Color(0xFF8B9CB5)),
            selectedIcon: Icon(Icons.explore, color: AppColors.primaryContainer),
            label: 'Khám phá',
          ),
          NavigationDestination(
            icon: Icon(Icons.favorite_border, color: Color(0xFF8B9CB5)),
            selectedIcon: Icon(Icons.favorite, color: Color(0xFFE6C17A)),
            label: 'Yêu thích',
          ),
          NavigationDestination(
            icon: Icon(Icons.confirmation_number_outlined, color: Color(0xFF8B9CB5)),
            selectedIcon: Icon(Icons.confirmation_number, color: AppColors.primaryContainer),
            label: 'Vé của tôi',
          ),
          NavigationDestination(
            icon: Icon(Icons.auto_awesome_outlined, color: Color(0xFF8B9CB5)),
            selectedIcon: Icon(Icons.auto_awesome, color: Color(0xFF06B6D4)),
            label: 'Trợ lý AI',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline, color: Color(0xFF8B9CB5)),
            selectedIcon: Icon(Icons.person, color: AppColors.primaryContainer),
            label: 'Tài khoản',
          ),
        ],
      ),
    );
  }
}
