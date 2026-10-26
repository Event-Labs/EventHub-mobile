import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/api/events_service.dart';
import '../../../../core/models/event_model.dart';
import '../../../../core/theme/app_colors.dart';
import '../widgets/event_card.dart';
import 'event_detail_page.dart';

class SearchEventsPage extends StatefulWidget {
  final String? initialKeyword;
  final String? initialCategoryId;

  const SearchEventsPage({
    super.key,
    this.initialKeyword,
    this.initialCategoryId,
  });

  @override
  State<SearchEventsPage> createState() => _SearchEventsPageState();
}

class _SearchEventsPageState extends State<SearchEventsPage> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  Timer? _debounceTimer;

  bool _isLoading = true;
  List<EventModel> _allEvents = [];
  List<EventModel> _searchResults = [];
  List<EventModel> _suggestedEvents = [];
  List<EventCategoryModel> _categories = [];

  String _dateFilter = 'all'; // 'all', 'today', 'tomorrow', 'this_weekend', 'this_month', 'custom'
  DateTime? _selectedCalendarDay;
  String? _categoryFilter; // category_id or null
  String _priceFilter = 'all'; // 'all', 'free', 'under_300k', '300k_1m', 'over_1m'

  @override
  void initState() {
    super.initState();
    if (widget.initialKeyword != null) {
      _searchController.text = widget.initialKeyword!;
    }
    if (widget.initialCategoryId != null && widget.initialCategoryId != 'all') {
      _categoryFilter = widget.initialCategoryId;
    }
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  bool _isEventActive(EventModel event) {
    final now = DateTime.now();
    if (event.endTime != null) {
      final end = DateTime.tryParse(event.endTime!)?.toLocal();
      if (end != null) return end.isAfter(now);
    }
    if (event.startTime != null) {
      final start = DateTime.tryParse(event.startTime!)?.toLocal();
      if (start != null) {
        // Event started less than 4 hours ago or in future
        return start.isAfter(now.subtract(const Duration(hours: 4)));
      }
    }
    return true;
  }

  int _calculatePopularityScore(EventModel event) {
    int score = 0;
    // 1. Total tickets sold
    int totalSold = 0;
    for (final t in event.ticketTypes) {
      totalSold += t.soldQuantity;
    }
    score += totalSold * 10;

    // 2. Featured & Live indicators
    if (event.isFeatured) score += 100;
    if (event.isLive) score += 80;
    if (event.isFavorited) score += 40;

    // 3. Number of sessions
    score += event.sessions.length * 10;

    return score;
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final futures = await Future.wait([
        EventsService().getPublicEvents(),
        EventsService().getCategories(),
      ]);

      final events = futures[0] as List<EventModel>;
      final categories = futures[1] as List<EventCategoryModel>;

      if (mounted) {
        setState(() {
          _allEvents = events;

          // Filter only active / upcoming events (exclude ended)
          final activeEvents = events.where(_isEventActive).toList();

          // Sort by popularity: tickets sold, views, featured, favorites
          activeEvents.sort((a, b) => _calculatePopularityScore(b).compareTo(_calculatePopularityScore(a)));

          _suggestedEvents = activeEvents;
          _categories = categories.where((c) => c.id != 'all').toList();
          _isLoading = false;
        });
        _applyFilters();
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        _applyFilters();
      }
    });
  }

  void _applyFilters() {
    final query = _searchController.text.trim().toLowerCase();
    final now = DateTime.now();

    final filtered = _allEvents.where((event) {
      // 1. Text keyword search
      if (query.isNotEmpty) {
        final title = event.title.toLowerCase();
        final desc = (event.shortDescription ?? '').toLowerCase();
        final org = event.organizerDisplayName.toLowerCase();
        final loc = event.locationSummary.toLowerCase();
        final cat = (event.categoryName ?? '').toLowerCase();

        final matchesQuery = title.contains(query) ||
            desc.contains(query) ||
            org.contains(query) ||
            loc.contains(query) ||
            cat.contains(query);

        if (!matchesQuery) return false;
      }

      // 2. Category filter
      if (_categoryFilter != null && _categoryFilter!.isNotEmpty && _categoryFilter != 'all') {
        if (event.categoryId != _categoryFilter) {
          return false;
        }
      }

      // 3. Date filter
      if (event.startTime != null) {
        try {
          final eventDate = DateTime.parse(event.startTime!).toLocal();

          if (_selectedCalendarDay != null) {
            final sameDay = eventDate.year == _selectedCalendarDay!.year &&
                eventDate.month == _selectedCalendarDay!.month &&
                eventDate.day == _selectedCalendarDay!.day;
            if (!sameDay) return false;
          } else if (_dateFilter != 'all') {
            final sameDayToday = eventDate.year == now.year &&
                eventDate.month == now.month &&
                eventDate.day == now.day;

            if (_dateFilter == 'today') {
              if (!sameDayToday) return false;
            } else if (_dateFilter == 'tomorrow') {
              final tomorrow = now.add(const Duration(days: 1));
              final sameDayTomorrow = eventDate.year == tomorrow.year &&
                  eventDate.month == tomorrow.month &&
                  eventDate.day == tomorrow.day;
              if (!sameDayTomorrow) return false;
            } else if (_dateFilter == 'this_weekend') {
              final daysUntilSaturday = DateTime.saturday - now.weekday;
              final saturday = now.add(Duration(days: daysUntilSaturday));
              final sunday = saturday.add(const Duration(days: 1));
              final isSat = eventDate.year == saturday.year &&
                  eventDate.month == saturday.month &&
                  eventDate.day == saturday.day;
              final isSun = eventDate.year == sunday.year &&
                  eventDate.month == sunday.month &&
                  eventDate.day == sunday.day;
              if (!isSat && !isSun) return false;
            } else if (_dateFilter == 'this_month') {
              if (eventDate.year != now.year || eventDate.month != now.month) {
                return false;
              }
            }
          }
        } catch (_) {}
      }

      // 4. Price filter
      if (_priceFilter != 'all') {
        final minP = event.minPrice ?? 0;
        if (_priceFilter == 'free') {
          if (minP > 0) return false;
        } else if (_priceFilter == 'under_300k') {
          if (minP > 300000) return false;
        } else if (_priceFilter == '300k_1m') {
          if (minP < 300000 || minP > 1000000) return false;
        } else if (_priceFilter == 'over_1m') {
          if (minP < 1000000) return false;
        }
      }

      return true;
    }).toList();

    setState(() {
      _searchResults = filtered;
    });
  }

  bool get _isFilterActive =>
      _searchController.text.trim().isNotEmpty ||
      _categoryFilter != null ||
      _dateFilter != 'all' ||
      _selectedCalendarDay != null ||
      _priceFilter != 'all';

  String _getDateFilterLabel() {
    if (_selectedCalendarDay != null) {
      final d = _selectedCalendarDay!;
      return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    }
    switch (_dateFilter) {
      case 'today':
        return 'Hôm nay';
      case 'tomorrow':
        return 'Ngày mai';
      case 'this_weekend':
        return 'Cuối tuần này';
      case 'this_month':
        return 'Tháng này';
      default:
        return 'Tất cả các ngày';
    }
  }

  // =========================================================
  // DATE PICKER MODAL (Exact match to sample UI with app theme)
  // =========================================================
  void _showDateFilterSheet() {
    String tempDateFilter = _dateFilter;
    DateTime? tempSelectedDay = _selectedCalendarDay;
    DateTime displayMonth = _selectedCalendarDay ?? DateTime.now();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF101932),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            final now = DateTime.now();
            final daysInMonth = DateTime(displayMonth.year, displayMonth.month + 1, 0).day;
            final firstWeekday = DateTime(displayMonth.year, displayMonth.month, 1).weekday; // 1 = Mon, 7 = Sun
            final prevMonthDays = DateTime(displayMonth.year, displayMonth.month, 0).day;
            final leadingDaysCount = firstWeekday - 1;

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top drag pill
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Header Row with Title and Close X icon
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const SizedBox(width: 24),
                        const Text(
                          'Chọn thời gian',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 24),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Quick Select Buttons Grid (Rows 1 & 2 as in image)
                    Row(
                      children: [
                        Expanded(
                          flex: 12,
                          child: _buildQuickDatePill(
                            'Tất cả các ngày',
                            tempDateFilter == 'all' && tempSelectedDay == null,
                            () {
                              setModalState(() {
                                tempDateFilter = 'all';
                                tempSelectedDay = null;
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 10,
                          child: _buildQuickDatePill(
                            'Hôm nay',
                            tempDateFilter == 'today' && tempSelectedDay == null,
                            () {
                              setModalState(() {
                                tempDateFilter = 'today';
                                tempSelectedDay = null;
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _buildQuickDatePill(
                            'Ngày mai',
                            tempDateFilter == 'tomorrow' && tempSelectedDay == null,
                            () {
                              setModalState(() {
                                tempDateFilter = 'tomorrow';
                                tempSelectedDay = null;
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildQuickDatePill(
                            'Cuối tuần này',
                            tempDateFilter == 'this_weekend' && tempSelectedDay == null,
                            () {
                              setModalState(() {
                                tempDateFilter = 'this_weekend';
                                tempSelectedDay = null;
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildQuickDatePill(
                            'Tháng này',
                            tempDateFilter == 'this_month' && tempSelectedDay == null,
                            () {
                              setModalState(() {
                                tempDateFilter = 'this_month';
                                tempSelectedDay = null;
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Dashed / Subtle Divider
                    Container(
                      height: 1,
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                    const SizedBox(height: 14),

                    // Calendar Month Navigation Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.chevron_left_rounded, color: Color(0xFF06B6D4), size: 26),
                          onPressed: () {
                            setModalState(() {
                              displayMonth = DateTime(displayMonth.year, displayMonth.month - 1);
                            });
                          },
                        ),
                        Text(
                          'Tháng ${displayMonth.month}, ${displayMonth.year}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.chevron_right_rounded, color: Color(0xFF06B6D4), size: 26),
                          onPressed: () {
                            setModalState(() {
                              displayMonth = DateTime(displayMonth.year, displayMonth.month + 1);
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Weekdays Row: T2, T3, T4, T5, T6, T7, CN
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Text('T2', style: TextStyle(color: Color(0xFF8B9CB5), fontSize: 13, fontWeight: FontWeight.bold)),
                        Text('T3', style: TextStyle(color: Color(0xFF8B9CB5), fontSize: 13, fontWeight: FontWeight.bold)),
                        Text('T4', style: TextStyle(color: Color(0xFF8B9CB5), fontSize: 13, fontWeight: FontWeight.bold)),
                        Text('T5', style: TextStyle(color: Color(0xFF8B9CB5), fontSize: 13, fontWeight: FontWeight.bold)),
                        Text('T6', style: TextStyle(color: Color(0xFF8B9CB5), fontSize: 13, fontWeight: FontWeight.bold)),
                        Text('T7', style: TextStyle(color: Color(0xFF8B9CB5), fontSize: 13, fontWeight: FontWeight.bold)),
                        Text('CN', style: TextStyle(color: Color(0xFF8B9CB5), fontSize: 13, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Calendar Days Grid
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: 35, // 5 rows of 7
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 7,
                        childAspectRatio: 1.15,
                        crossAxisSpacing: 4,
                        mainAxisSpacing: 6,
                      ),
                      itemBuilder: (context, index) {
                        int dayNumber;
                        bool isCurrentMonth = true;

                        if (index < leadingDaysCount) {
                          // Previous month trailing days
                          dayNumber = prevMonthDays - leadingDaysCount + index + 1;
                          isCurrentMonth = false;
                        } else if (index >= leadingDaysCount + daysInMonth) {
                          // Next month leading days
                          dayNumber = index - (leadingDaysCount + daysInMonth) + 1;
                          isCurrentMonth = false;
                        } else {
                          dayNumber = index - leadingDaysCount + 1;
                        }

                        final thisDate = isCurrentMonth
                            ? DateTime(displayMonth.year, displayMonth.month, dayNumber)
                            : null;

                        final isSelected = isCurrentMonth &&
                            tempSelectedDay != null &&
                            tempSelectedDay!.year == thisDate!.year &&
                            tempSelectedDay!.month == thisDate.month &&
                            tempSelectedDay!.day == thisDate.day;

                        final isToday = isCurrentMonth &&
                            now.year == thisDate!.year &&
                            now.month == thisDate.month &&
                            now.day == thisDate.day;

                        return GestureDetector(
                          onTap: isCurrentMonth
                              ? () {
                                  setModalState(() {
                                    tempSelectedDay = thisDate;
                                    tempDateFilter = 'custom';
                                  });
                                }
                              : null,
                          child: Container(
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFFE6C17A).withValues(alpha: 0.18)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isSelected
                                    ? const Color(0xFFE6C17A)
                                    : (isToday
                                        ? const Color(0xFF06B6D4).withValues(alpha: 0.6)
                                        : Colors.transparent),
                                width: isSelected ? 1.8 : 1,
                              ),
                            ),
                            child: Text(
                              '$dayNumber',
                              style: TextStyle(
                                color: !isCurrentMonth
                                    ? Colors.white24
                                    : (isSelected
                                        ? const Color(0xFFE6C17A)
                                        : (isToday ? const Color(0xFF06B6D4) : Colors.white)),
                                fontSize: 14,
                                fontWeight: (isSelected || isToday) ? FontWeight.bold : FontWeight.w500,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 20),

                    // Bottom Action Buttons: "Thiết lập lại" & "Áp dụng"
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              setModalState(() {
                                tempDateFilter = 'all';
                                tempSelectedDay = null;
                              });
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white70,
                              side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            child: const Text('Thiết lập lại', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.pop(context);
                              setState(() {
                                _dateFilter = tempDateFilter;
                                _selectedCalendarDay = tempSelectedDay;
                              });
                              _applyFilters();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFE6C17A),
                              foregroundColor: const Color(0xFF070D1E),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              elevation: 4,
                            ),
                            child: const Text('Áp dụng', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildQuickDatePill(String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFE6C17A).withValues(alpha: 0.15)
              : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? const Color(0xFFE6C17A)
                : Colors.white.withValues(alpha: 0.12),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? const Color(0xFFE6C17A) : Colors.white,
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  // =========================================================
  // FILTER MODAL (Category & Price)
  // =========================================================
  void _showFilterModal() {
    String tempCategory = _categoryFilter ?? 'all';
    String tempPrice = _priceFilter;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF101932),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Bộ lọc tìm kiếm',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            setModalState(() {
                              tempCategory = 'all';
                              tempPrice = 'all';
                            });
                          },
                          child: const Text('Thiết lập lại', style: TextStyle(color: Color(0xFF8B9CB5))),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Filter By Category
                    const Text('Thể loại', style: TextStyle(color: Color(0xFF8B9CB5), fontSize: 13, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildFilterChip('Tất cả', tempCategory == 'all', () {
                          setModalState(() => tempCategory = 'all');
                        }),
                        ..._categories.map((cat) {
                          final isSel = tempCategory == cat.id;
                          return _buildFilterChip(cat.name, isSel, () {
                            setModalState(() => tempCategory = cat.id);
                          });
                        }),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Filter By Price
                    const Text('Mức giá', style: TextStyle(color: Color(0xFF8B9CB5), fontSize: 13, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildFilterChip('Tất cả', tempPrice == 'all', () {
                          setModalState(() => tempPrice = 'all');
                        }),
                        _buildFilterChip('Miễn phí', tempPrice == 'free', () {
                          setModalState(() => tempPrice = 'free');
                        }),
                        _buildFilterChip('Dưới 300k', tempPrice == 'under_300k', () {
                          setModalState(() => tempPrice = 'under_300k');
                        }),
                        _buildFilterChip('300k - 1 triệu', tempPrice == '300k_1m', () {
                          setModalState(() => tempPrice = '300k_1m');
                        }),
                        _buildFilterChip('Trên 1 triệu', tempPrice == 'over_1m', () {
                          setModalState(() => tempPrice = 'over_1m');
                        }),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Apply Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          setState(() {
                            _categoryFilter = tempCategory == 'all' ? null : tempCategory;
                            _priceFilter = tempPrice;
                          });
                          _applyFilters();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE6C17A),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: const Text(
                          'Áp dụng',
                          style: TextStyle(
                            color: Color(0xFF070D1E),
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFilterChip(String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFE6C17A) : Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFFC99A47) : Colors.white.withValues(alpha: 0.1),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? const Color(0xFF070D1E) : Colors.white,
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  String _getCategoryCoverImage(String categoryName) {
    final lower = categoryName.toLowerCase();
    if (lower.contains('nhạc') || lower.contains('music') || lower.contains('edm') || lower.contains('hát')) {
      return 'https://images.unsplash.com/photo-1470225620780-dba8ba36b745?w=500&auto=format&fit=crop&q=60';
    } else if (lower.contains('kịch') || lower.contains('sân khấu') || lower.contains('nghệ thuật') || lower.contains('art')) {
      return 'https://images.unsplash.com/photo-1507676184212-d03ab07a01bf?w=500&auto=format&fit=crop&q=60';
    } else if (lower.contains('thể thao') || lower.contains('sport') || lower.contains('chạy')) {
      return 'https://images.unsplash.com/photo-1461896836934-ffe607ba8211?w=500&auto=format&fit=crop&q=60';
    } else if (lower.contains('hội thảo') || lower.contains('workshop') || lower.contains('seminar')) {
      return 'https://images.unsplash.com/photo-1540575467063-178a50c2df87?w=500&auto=format&fit=crop&q=60';
    } else if (lower.contains('công nghệ') || lower.contains('tech')) {
      return 'https://images.unsplash.com/photo-1519389950473-47ba0277781c?w=500&auto=format&fit=crop&q=60';
    } else if (lower.contains('ẩm thực') || lower.contains('food')) {
      return 'https://images.unsplash.com/photo-1555396273-367ea4eb4db5?w=500&auto=format&fit=crop&q=60';
    }
    return 'https://images.unsplash.com/photo-1492684223066-81342ee5ff30?w=500&auto=format&fit=crop&q=60';
  }

  @override
  Widget build(BuildContext context) {
    final hasActiveFilter = _isFilterActive;

    return Scaffold(
      backgroundColor: const Color(0xFF070D1E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF070D1E),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Tìm kiếm',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // 1. Search Bar & Filter Buttons Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Column(
              children: [
                // Input TextField with bottom green/cyan highlight
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF101932),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _searchFocusNode.hasFocus
                          ? const Color(0xFF06B6D4)
                          : Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                  child: TextField(
                    controller: _searchController,
                    focusNode: _searchFocusNode,
                    onChanged: _onSearchChanged,
                    style: const TextStyle(color: Colors.white, fontSize: 15),
                    decoration: InputDecoration(
                      hintText: 'Nhập từ khóa',
                      hintStyle: const TextStyle(color: Color(0xFF8B9CB5), fontSize: 15),
                      prefixIcon: const Icon(Icons.search, color: Color(0xFF8B9CB5), size: 22),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.close_rounded, color: Colors.white60, size: 20),
                              onPressed: () {
                                _searchController.clear();
                                _onSearchChanged('');
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Filter Pills: "Tất cả các ngày" & "Bộ lọc"
                Row(
                  children: [
                    // Date Filter Pill
                    Expanded(
                      child: GestureDetector(
                        onTap: _showDateFilterSheet,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: (_dateFilter != 'all' || _selectedCalendarDay != null)
                                ? const Color(0xFFC99A47).withValues(alpha: 0.15)
                                : const Color(0xFF101932),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: (_dateFilter != 'all' || _selectedCalendarDay != null)
                                  ? const Color(0xFFE6C17A)
                                  : Colors.white.withValues(alpha: 0.08),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.calendar_today_outlined,
                                color: (_dateFilter != 'all' || _selectedCalendarDay != null)
                                    ? const Color(0xFFE6C17A)
                                    : Colors.white70,
                                size: 16,
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  _getDateFilterLabel(),
                                  style: TextStyle(
                                    color: (_dateFilter != 'all' || _selectedCalendarDay != null)
                                        ? const Color(0xFFE6C17A)
                                        : Colors.white,
                                    fontSize: 13,
                                    fontWeight: (_dateFilter != 'all' || _selectedCalendarDay != null)
                                        ? FontWeight.bold
                                        : FontWeight.w500,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                Icons.keyboard_arrow_down_rounded,
                                color: (_dateFilter != 'all' || _selectedCalendarDay != null)
                                    ? const Color(0xFFE6C17A)
                                    : Colors.white70,
                                size: 18,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Filter Modal Pill
                    Expanded(
                      child: GestureDetector(
                        onTap: _showFilterModal,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: (_categoryFilter != null || _priceFilter != 'all')
                                ? const Color(0xFF06B6D4).withValues(alpha: 0.15)
                                : const Color(0xFF101932),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: (_categoryFilter != null || _priceFilter != 'all')
                                  ? const Color(0xFF06B6D4)
                                  : Colors.white.withValues(alpha: 0.08),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.tune_rounded,
                                color: (_categoryFilter != null || _priceFilter != 'all')
                                    ? const Color(0xFF06B6D4)
                                    : Colors.white70,
                                size: 16,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                (_categoryFilter != null || _priceFilter != 'all')
                                    ? 'Đang lọc'
                                    : 'Bộ lọc',
                                style: TextStyle(
                                  color: (_categoryFilter != null || _priceFilter != 'all')
                                      ? const Color(0xFF06B6D4)
                                      : Colors.white,
                                  fontSize: 13,
                                  fontWeight: (_categoryFilter != null || _priceFilter != 'all')
                                      ? FontWeight.bold
                                      : FontWeight.w500,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                Icons.keyboard_arrow_down_rounded,
                                color: (_categoryFilter != null || _priceFilter != 'all')
                                    ? const Color(0xFF06B6D4)
                                    : Colors.white70,
                                size: 18,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // 2. Main Content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primaryContainer))
                : hasActiveFilter
                    ? _buildSearchResults()
                    : _buildDefaultDiscovery(),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // DEFAULT DISCOVERY VIEW (When no active search query/filter)
  // =========================================================
  Widget _buildDefaultDiscovery() {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),

          // 1. Khám phá theo Thể loại
          if (_categories.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Khám phá theo Thể loại',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.3,
                ),
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 100,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _categories.length,
                itemBuilder: (ctx, idx) {
                  final cat = _categories[idx];
                  final imageUrl = _getCategoryCoverImage(cat.name);

                  return GestureDetector(
                    onTap: () {
                      setState(() => _categoryFilter = cat.id);
                      _applyFilters();
                    },
                    child: Container(
                      width: 155,
                      margin: const EdgeInsets.only(right: 12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.4),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.network(
                            imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(color: const Color(0xFF1E2846)),
                          ),
                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.black.withValues(alpha: 0.25),
                                  Colors.black.withValues(alpha: 0.8),
                                ],
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: Align(
                              alignment: Alignment.topLeft,
                              child: Text(
                                cat.name,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  shadows: [
                                    Shadow(color: Colors.black, blurRadius: 8),
                                  ],
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
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

          // 2. Gợi ý dành cho bạn (Calculated by ticket sales and views, only active/upcoming events)
          if (_suggestedEvents.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Gợi ý dành cho bạn',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.3,
                ),
              ),
            ),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _suggestedEvents.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 0.71,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 16,
                ),
                itemBuilder: (ctx, idx) {
                  final event = _suggestedEvents[idx];
                  return EventCardWidget(
                    event: event,
                    compact: true,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => EventDetailPage(event: event, eventId: event.id),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  // =========================================================
  // SEARCH RESULTS VIEW
  // =========================================================
  Widget _buildSearchResults() {
    if (_searchResults.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.05),
                ),
                child: const Icon(
                  Icons.search_off_rounded,
                  color: Color(0xFFC99A47),
                  size: 36,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Không tìm thấy sự kiện nào',
                style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              const Text(
                'Vui lòng thử lại với từ khóa hoặc bộ lọc khác',
                style: TextStyle(color: Color(0xFF8B9CB5), fontSize: 13),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 18),
              OutlinedButton(
                onPressed: () {
                  _searchController.clear();
                  setState(() {
                    _dateFilter = 'all';
                    _selectedCalendarDay = null;
                    _categoryFilter = null;
                    _priceFilter = 'all';
                  });
                  _applyFilters();
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFE6C17A),
                  side: const BorderSide(color: Color(0xFFC99A47)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
                child: const Text('Xóa tất cả bộ lọc'),
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Tìm thấy ${_searchResults.length} sự kiện',
                style: const TextStyle(
                  color: Color(0xFF8B9CB5),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              GestureDetector(
                onTap: () {
                  _searchController.clear();
                  setState(() {
                    _dateFilter = 'all';
                    _selectedCalendarDay = null;
                    _categoryFilter = null;
                    _priceFilter = 'all';
                  });
                  _applyFilters();
                },
                child: const Text(
                  'Xóa bộ lọc',
                  style: TextStyle(
                    color: Color(0xFFE6C17A),
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _searchResults.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.71,
              crossAxisSpacing: 12,
              mainAxisSpacing: 16,
            ),
            itemBuilder: (ctx, idx) {
              final event = _searchResults[idx];
              return EventCardWidget(
                event: event,
                compact: true,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => EventDetailPage(event: event, eventId: event.id),
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}
