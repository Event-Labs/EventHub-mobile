import 'package:flutter/material.dart';
import '../../../../core/api/events_service.dart';
import '../../../../core/models/event_model.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../ai/presentation/pages/ai_chat_page.dart';
import '../../../profile/presentation/pages/profile_page.dart';
import '../../../tickets/presentation/pages/my_tickets_page.dart';
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

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final categories = await EventsService().getCategories();
    final events = await EventsService().getPublicEvents(
      search: _searchController.text.trim(),
      categoryId: _selectedCategoryId,
    );
    setState(() {
      _categories = categories;
      _events = events;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Switch main view body based on Bottom NavBar tab
    Widget bodyContent;
    switch (_currentBottomNavIndex) {
      case 1:
        bodyContent = _buildDiscoveryContent(); // Search / Explore
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
      backgroundColor: AppColors.background,
      body: bodyContent,
      floatingActionButton: _currentBottomNavIndex == 0 ? _buildAiGenieFab() : null,
      bottomNavigationBar: _buildBottomNavBar(),
    );
  }

  Widget _buildDiscoveryContent() {
    final featured = _events.where((e) => e.isFeatured).toList();
    final trending = _events;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background.withOpacity(0.9),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.local_activity, color: AppColors.onPrimary, size: 20),
            ),
            const SizedBox(width: 8),
            Text(
              'EventHub',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ],
        ),
        actions: [
          _buildLocationSelector(),
          const SizedBox(width: 8),
          _buildNotificationBadge(),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => setState(() => _currentBottomNavIndex = 4),
            child: const CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.primaryContainer,
              child: Icon(Icons.person, color: Colors.white, size: 18),
            ),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        color: AppColors.primaryContainer,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              _buildSearchBar(),
              const SizedBox(height: 20),
              _buildCategorySelector(),
              const SizedBox(height: 24),

              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(child: CircularProgressIndicator(color: AppColors.primaryContainer)),
                )
              else ...[
                if (featured.isNotEmpty) ...[
                  _buildFeaturedCard(featured.first),
                  const SizedBox(height: 16),
                ],
                _buildAiCuratorBanner(),
                const SizedBox(height: 24),
                _buildTrendingSectionHeader(),
                const SizedBox(height: 16),
                ...trending.map((event) => Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: GestureDetector(
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => EventDetailPage(event: event)),
                          );
                        },
                        child: _buildTrendingEventCard(event),
                      ),
                    )),
                const SizedBox(height: 100),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.outlineVariant.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.search, color: AppColors.secondary, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    style: const TextStyle(color: Colors.white),
                    onSubmitted: (_) => _loadData(),
                    decoration: const InputDecoration(
                      hintText: 'Search concerts, EDM, acoustic...',
                      hintStyle: TextStyle(color: Colors.white38, fontSize: 14),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: _loadData,
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.tune, color: AppColors.secondary, size: 20),
          ),
        ),
      ],
    );
  }

  Widget _buildCategorySelector() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _categories.map((cat) {
          final isSelected = _selectedCategoryId == cat.id;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(cat.name),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) {
                  setState(() => _selectedCategoryId = cat.id);
                  _loadData();
                }
              },
              selectedColor: AppColors.primaryContainer,
              backgroundColor: AppColors.surfaceContainerLow,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : AppColors.secondary,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                fontSize: 12,
              ),
              side: BorderSide(color: isSelected ? AppColors.primaryContainer : Colors.white12),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildFeaturedCard(EventModel event) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => EventDetailPage(event: event)),
        );
      },
      child: Container(
        height: 200,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          image: DecorationImage(
            image: NetworkImage(event.coverImageUrl ?? 'https://lh3.googleusercontent.com/aida-public/AB6AXuCsh1MyeOrExv0OTGWPXymZBnHdDiqnLogqJTML1O6osQPpeQP11Xa069TLuCwM-qYBI6xOmazp-7pg5MCxPM4TcaDHr7rhFP7PRyR7QS79TjINZdZ4k4DfgPm1umU1TYFb7w-_8bpoVl9R1VTWzNVop69NIQAPIhcnx8LZ1FDgsJ4ME58mNas6uSxXTAiSOwUKbbgiKBdEG1KIhXlEOKa-7pEzLNe1z7_DJbEJhZKSIizd6czYP7-3'),
            fit: BoxFit.cover,
          ),
        ),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.transparent, Colors.black.withOpacity(0.9)],
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: AppColors.primaryContainer, borderRadius: BorderRadius.circular(4)),
                child: const Text('FEATURED EVENT', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 6),
              Text(event.title, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              Text('${event.startDate} • ${event.locationName}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTrendingEventCard(EventModel event) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0C1446),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.secondary.withOpacity(0.15)),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              event.coverImageUrl ?? 'https://lh3.googleusercontent.com/aida-public/AB6AXuCHvQQo3rlkT-_-4tUHI3g57mTvXFLLtgJIrPL-reMGuj3XaOw5i6m8XE6UGxWKt-QuWxbS2cGCGQjYHDt8EDrRooC6YbzU-eaPUv9DcCue5-MmAQR68oLBY_jSWFWP-C4xOAdAv4AxulL_cS5HPJAIgKYoERtOuwFAt7Adc_XIULWFK-BBSXPXfPg5aXY3f55MNtosKA6Nk4dKNOiGKA4Obe8EMj5iC0bffRUXPj_BkbYJEu63krqF',
              width: 80,
              height: 80,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(event.categoryName?.toUpperCase() ?? 'CONCERT', style: const TextStyle(color: AppColors.primaryContainer, fontSize: 10, fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text(event.title, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text(event.startDate ?? '', style: const TextStyle(color: AppColors.secondary, fontSize: 11)),
                Text(event.formattedPrice, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: AppColors.secondary),
        ],
      ),
    );
  }

  Widget _buildAiCuratorBanner() {
    return GestureDetector(
      onTap: () => setState(() => _currentBottomNavIndex = 3),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF0C1446),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.tertiaryContainer.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.tertiaryContainer.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.auto_awesome, color: AppColors.tertiary, size: 22),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Gợi ý sự kiện đêm nay', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
                  Text('Hỏi Trợ lý AI Genie về show âm nhạc phù hợp gu bạn', style: TextStyle(color: AppColors.secondary, fontSize: 11)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.secondary, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildTrendingSectionHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            const Icon(Icons.trending_up, color: AppColors.primary, size: 18),
            const SizedBox(width: 6),
            Text(
              'Trending Events',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        const Row(
          children: [
            CircleAvatar(radius: 3, backgroundColor: Colors.greenAccent),
            SizedBox(width: 4),
            Text('Real-time', style: TextStyle(color: AppColors.secondary, fontSize: 11)),
          ],
        ),
      ],
    );
  }

  Widget _buildLocationSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHigh.withOpacity(0.8),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.near_me, color: AppColors.primaryContainer, size: 14),
          SizedBox(width: 4),
          Text('TP. Hồ Chí Minh', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildNotificationBadge() {
    return const Icon(Icons.notifications_none, color: AppColors.secondary, size: 24);
  }

  Widget _buildAiGenieFab() {
    return FloatingActionButton.extended(
      onPressed: () => setState(() => _currentBottomNavIndex = 3),
      backgroundColor: AppColors.neonPurple,
      icon: const Icon(Icons.auto_awesome, color: Colors.white, size: 20),
      label: const Text('Ask Genie', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildBottomNavBar() {
    return Container(
      height: 70,
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest.withOpacity(0.95),
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.05))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildNavBarItem(0, Icons.home, 'Home'),
          _buildNavBarItem(1, Icons.search, 'Search'),
          _buildNavBarItem(2, Icons.confirmation_number_outlined, 'Tickets'),
          _buildNavBarItem(3, Icons.auto_awesome, 'AI Genie'),
          _buildNavBarItem(4, Icons.person_outline, 'Profile'),
        ],
      ),
    );
  }

  Widget _buildNavBarItem(int index, IconData icon, String label) {
    final isActive = _currentBottomNavIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _currentBottomNavIndex = index),
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: isActive ? AppColors.primaryContainer : AppColors.secondary, size: 22),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: isActive ? AppColors.primaryContainer : AppColors.secondary,
              fontSize: 10,
              fontWeight: isActive ? FontWeight.bold : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}
