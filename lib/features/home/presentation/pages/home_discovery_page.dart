import 'package:flutter/material.dart';
import '../../../../core/api/auth_service.dart';
import '../../../../core/api/events_service.dart';
import '../../../../core/api/notifications_service.dart';
import '../../../../core/models/event_model.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../staff/presentation/pages/staff_dashboard_page.dart';
import '../../../ai/presentation/pages/ai_chat_page.dart';
import '../../../favorites/presentation/pages/favorite_events_page.dart';
import '../../../notifications/presentation/pages/notifications_page.dart';
import '../../../profile/presentation/pages/profile_page.dart';
import '../../../tickets/presentation/pages/my_tickets_page.dart';
import '../widgets/event_card.dart';
import 'event_detail_page.dart';
import 'search_events_page.dart';

class HomeDiscoveryPage extends StatefulWidget {
  const HomeDiscoveryPage({super.key});

  @override
  State<HomeDiscoveryPage> createState() => _HomeDiscoveryPageState();
}

class _HomeDiscoveryPageState extends State<HomeDiscoveryPage> {
  int _currentBottomNavIndex = 0;
  List<EventCategoryModel> _categories = [];
  List<EventModel> _events = [];
  List<EventOrganizerModel> _organizers = [];
  bool _isLoading = true;
  String _selectedCategoryId = 'all';
  String? _selectedOrganizerId;
  String _statusFilter = 'all'; // 'all', 'ongoing', 'upcoming', 'ended'
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
    final categoriesFuture = EventsService().getCategories();
    final eventsFuture = EventsService().getPublicEvents(
      search: _searchController.text.trim(),
      categoryId: _selectedCategoryId,
    );
    final organizersFuture = EventsService().getOrganizers();
    final notiCountFuture = NotificationsService().getUnreadCount();

    final results = await Future.wait([categoriesFuture, eventsFuture, organizersFuture, notiCountFuture]);
    final categories = results[0] as List<EventCategoryModel>;
    final events = results[1] as List<EventModel>;
    var organizers = results[2] as List<EventOrganizerModel>;
    final notiCount = results[3] as int;

    // Fallback: If organizers list from API is empty, extract unique from events
    if (organizers.isEmpty) {
      final Map<String, EventOrganizerModel> map = {};
      for (final e in events) {
        if (e.organizer?.id != null && !map.containsKey(e.organizer!.id)) {
          map[e.organizer!.id!] = e.organizer!;
        }
      }
      organizers = map.values.toList();
    }

    if (mounted) {
      setState(() {
        _categories = categories;
        _events = events;
        _organizers = organizers;
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

  String _getEventTimeState(EventModel event, DateTime now) {
    DateTime? start = event.startTime != null ? DateTime.tryParse(event.startTime!) : null;
    DateTime? end = event.endTime != null ? DateTime.tryParse(event.endTime!) : null;
    if (end != null && end.isBefore(now)) return 'ended';
    if (start != null && start.isAfter(now)) return 'upcoming';
    return 'ongoing';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF070D1E),
      body: IndexedStack(
        index: _currentBottomNavIndex,
        children: [
          _buildDiscoveryContent(),
          const FavoriteEventsPage(),
          const MyTicketsPage(),
          const AiChatPage(),
          const ProfilePage(),
        ],
      ),
      bottomNavigationBar: _buildBottomNavBar(),
    );
  }

  Widget _buildDiscoveryContent() {
    final now = DateTime.now();

    // 1. Filter events by selected organizer if any
    List<EventModel> filteredEvents = _events;
    if (_selectedOrganizerId != null) {
      filteredEvents = filteredEvents.where((e) => e.organizer?.id == _selectedOrganizerId).toList();
    }

    // Single pass classification to optimize performance and prevent lag/freeze
    final ongoingEvents = <EventModel>[];
    final upcomingEvents = <EventModel>[];
    final endedEvents = <EventModel>[];
    final validEvents = <EventModel>[];

    for (final e in filteredEvents) {
      final state = _getEventTimeState(e, now);
      if (state == 'ongoing') {
        ongoingEvents.add(e);
        validEvents.add(e);
      } else if (state == 'upcoming') {
        upcomingEvents.add(e);
        validEvents.add(e);
      } else {
        endedEvents.add(e);
      }
    }

    // 2. Spotlight: ONLY events that are still valid (not ended)
    final featured = validEvents.where((e) => e.isFeatured).toList();
    final displayFeatured = featured.isNotEmpty ? featured : validEvents.take(5).toList();

    return Scaffold(
      backgroundColor: const Color(0xFF070D1E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF070D1E),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [Color(0xFFFFB690), Color(0xFFE6C17A)],
          ).createShader(bounds),
          child: const Text(
            'EventHub',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 24,
              letterSpacing: -0.5,
            ),
          ),
        ),
        actions: [
          // Icon kính lúp tìm kiếm
          IconButton(
            icon: const Icon(Icons.search, color: Colors.white, size: 24),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SearchEventsPage()),
              );
            },
          ),
          // Icon chuông thông báo
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
            const SizedBox(width: 8),
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
              const SizedBox(height: 8),

              // Categories Horizontal Scroll
              if (_categories.isNotEmpty) ...[
                SizedBox(
                  height: 40,
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
                            setState(() {
                              if (_selectedCategoryId == cat.id && cat.id != 'all') {
                                _selectedCategoryId = 'all';
                              } else {
                                _selectedCategoryId = cat.id;
                              }
                            });
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
                const SizedBox(height: 20),
              ],

              // 1. Featured Spotlight Section (Only active events)
              if (displayFeatured.isNotEmpty) ...[
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Icon(Icons.bolt, color: Color(0xFFE6C17A), size: 20),
                      SizedBox(width: 6),
                      Text(
                        'Sự Kiện Nổi Bật',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ],
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
                const SizedBox(height: 24),
              ],

              // 2. Featured Organizers Section (Avatar + Tên BTC)
              if (_organizers.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.stars, color: Color(0xFFE6C17A), size: 18),
                          SizedBox(width: 6),
                          Text(
                            'Ban Tổ Chức Nổi Bật',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ],
                      ),
                      if (_selectedOrganizerId != null)
                        GestureDetector(
                          onTap: () => setState(() => _selectedOrganizerId = null),
                          child: const Text(
                            'Bỏ lọc',
                            style: TextStyle(
                              color: AppColors.primaryContainer,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 106,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _organizers.length,
                    itemBuilder: (ctx, idx) {
                      final org = _organizers[idx];
                      final isSelected = _selectedOrganizerId == org.id;
                      final name = org.displayName;

                      return Padding(
                        padding: const EdgeInsets.only(right: 14),
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              if (_selectedOrganizerId == org.id) {
                                _selectedOrganizerId = null;
                              } else {
                                _selectedOrganizerId = org.id;
                              }
                            });
                          },
                          child: SizedBox(
                            width: 76,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 60,
                                  height: 60,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: const Color(0xFF1E2846),
                                    border: Border.all(
                                      color: isSelected
                                          ? AppColors.primaryContainer
                                          : const Color(0xFFE6C17A).withOpacity(0.4),
                                      width: isSelected ? 2.5 : 1.5,
                                    ),
                                    boxShadow: isSelected
                                        ? [
                                            BoxShadow(
                                              color: AppColors.primaryContainer.withOpacity(0.4),
                                              blurRadius: 10,
                                              spreadRadius: 1,
                                            ),
                                          ]
                                        : null,
                                  ),
                                  clipBehavior: Clip.antiAlias,
                                  child: org.avatarUrl != null && org.avatarUrl!.isNotEmpty
                                      ? Image.network(
                                          org.avatarUrl!,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) => _buildOrganizerFallback(name),
                                        )
                                      : _buildOrganizerFallback(name),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  name,
                                  maxLines: 2,
                                  textAlign: TextAlign.center,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: isSelected ? AppColors.primaryContainer : const Color(0xFFDAE2FF),
                                    fontSize: 11,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                    height: 1.15,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // 3. Status Tabs (Tất cả, Đang diễn ra, Sắp diễn ra, Đã kết thúc)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildStatusPill('all', 'Tất cả (${filteredEvents.length})', null),
                      const SizedBox(width: 8),
                      _buildStatusPill('ongoing', 'Đang diễn ra (${ongoingEvents.length})', const Color(0xFF10B981)),
                      const SizedBox(width: 8),
                      _buildStatusPill('upcoming', 'Sắp diễn ra (${upcomingEvents.length})', const Color(0xFF06B6D4)),
                      const SizedBox(width: 8),
                      _buildStatusPill('ended', 'Đã kết thúc (${endedEvents.length})', const Color(0xFF94A3B8)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Events List Display
              if (_isLoading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(40),
                    child: CircularProgressIndicator(color: AppColors.primaryContainer),
                  ),
                )
              else if (filteredEvents.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(40),
                    child: Column(
                      children: [
                        const Icon(Icons.event_busy, color: Colors.white24, size: 50),
                        const SizedBox(height: 12),
                        const Text('Không tìm thấy sự kiện nào.', style: TextStyle(color: Color(0xFFB0CADD), fontSize: 14)),
                        if (_selectedOrganizerId != null) ...[
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: () => setState(() => _selectedOrganizerId = null),
                            child: const Text('Xem tất cả ban tổ chức'),
                          ),
                        ],
                      ],
                    ),
                  ),
                )
              else
                ..._buildCategorizedEventsList(
                  ongoingEvents: ongoingEvents,
                  upcomingEvents: upcomingEvents,
                  endedEvents: endedEvents,
                  allEvents: filteredEvents,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOrganizerFallback(String name) {
    final initial = name.isNotEmpty ? name.trim().characters.first.toUpperCase() : 'B';
    return Center(
      child: Text(
        initial,
        style: const TextStyle(
          color: Color(0xFFE6C17A),
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildStatusPill(String filterKey, String label, Color? indicatorColor) {
    final isSelected = _statusFilter == filterKey;
    return GestureDetector(
      onTap: () => setState(() => _statusFilter = filterKey),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryContainer.withOpacity(0.2) : const Color(0xFF101932),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected ? AppColors.primaryContainer : Colors.white.withOpacity(0.08),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (indicatorColor != null) ...[
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(color: indicatorColor, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : const Color(0xFFB0CADD),
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildCategorizedEventsList({
    required List<EventModel> ongoingEvents,
    required List<EventModel> upcomingEvents,
    required List<EventModel> endedEvents,
    required List<EventModel> allEvents,
  }) {
    if (_statusFilter == 'ongoing') {
      return [
        _buildSectionHeader('Đang Diễn Ra', ongoingEvents.length, const Color(0xFF10B981)),
        _buildEventsColumn(ongoingEvents, emptyMessage: 'Không có sự kiện nào đang diễn ra.'),
      ];
    }
    if (_statusFilter == 'upcoming') {
      return [
        _buildSectionHeader('Sắp Diễn Ra', upcomingEvents.length, const Color(0xFF06B6D4)),
        _buildEventsColumn(upcomingEvents, emptyMessage: 'Không có sự kiện nào sắp diễn ra.'),
      ];
    }
    if (_statusFilter == 'ended') {
      return [
        _buildSectionHeader('Đã Kết Thúc', endedEvents.length, const Color(0xFF94A3B8)),
        _buildEventsColumn(endedEvents, emptyMessage: 'Không có sự kiện nào đã kết thúc.'),
      ];
    }

    // Default 'all': Display categorized sections in order
    final widgets = <Widget>[];

    if (ongoingEvents.isNotEmpty) {
      widgets.add(_buildSectionHeader('Đang Diễn Ra', ongoingEvents.length, const Color(0xFF10B981)));
      widgets.add(_buildEventsColumn(ongoingEvents));
      widgets.add(const SizedBox(height: 14));
    }

    if (upcomingEvents.isNotEmpty) {
      widgets.add(_buildSectionHeader('Sắp Diễn Ra', upcomingEvents.length, const Color(0xFF06B6D4)));
      widgets.add(_buildEventsColumn(upcomingEvents));
      widgets.add(const SizedBox(height: 14));
    }

    if (endedEvents.isNotEmpty) {
      widgets.add(_buildSectionHeader('Đã Kết Thúc', endedEvents.length, const Color(0xFF94A3B8)));
      widgets.add(_buildEventsColumn(endedEvents));
    }

    return widgets;
  }

  Widget _buildSectionHeader(String title, int count, Color accentColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 18,
                decoration: BoxDecoration(
                  color: accentColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
          Text(
            '$count sự kiện',
            style: const TextStyle(color: Color(0xFF8B9CB5), fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildEventsColumn(List<EventModel> events, {String emptyMessage = 'Không có sự kiện nào.'}) {
    if (events.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: Text(
            emptyMessage,
            style: const TextStyle(color: Color(0xFF8B9CB5), fontSize: 13),
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: events.length,
      itemBuilder: (ctx, idx) {
        final event = events[idx];
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
