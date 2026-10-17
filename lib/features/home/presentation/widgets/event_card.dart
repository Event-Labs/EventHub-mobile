import 'package:flutter/material.dart';
import '../../../../core/models/event_model.dart';
import '../../../../core/theme/app_colors.dart';

class EventCardWidget extends StatelessWidget {
  final EventModel event;
  final VoidCallback onTap;
  final VoidCallback? onFavoriteToggle;
  final bool isFavoriteBusy;
  final bool compact;

  const EventCardWidget({
    super.key,
    required this.event,
    required this.onTap,
    this.onFavoriteToggle,
    this.isFavoriteBusy = false,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF101932),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.08), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.35),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image with Category badge and Favorite button
            Stack(
              children: [
                SizedBox(
                  height: compact ? 150 : 180,
                  width: double.infinity,
                  child: event.coverImageUrl != null && event.coverImageUrl!.isNotEmpty
                      ? Image.network(
                          event.coverImageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _buildPlaceholder(),
                        )
                      : _buildPlaceholder(),
                ),
                // Gradient overlay
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          const Color(0xFF101932).withOpacity(0.9),
                        ],
                        stops: const [0.5, 1.0],
                      ),
                    ),
                  ),
                ),
                // Category badge
                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.65),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFC99A47).withOpacity(0.7), width: 1),
                    ),
                    child: Text(
                      event.categoryName?.toUpperCase() ?? 'SỰ KIỆN',
                      style: const TextStyle(
                        color: Color(0xFFE6C17A),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
                // Favorite Heart button
                if (onFavoriteToggle != null)
                  Positioned(
                    top: 10,
                    right: 10,
                    child: GestureDetector(
                      onTap: isFavoriteBusy ? null : onFavoriteToggle,
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.55),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: event.isFavorited
                                ? const Color(0xFFC99A47).withOpacity(0.8)
                                : Colors.white.withOpacity(0.2),
                            width: 1,
                          ),
                          boxShadow: event.isFavorited
                              ? [
                                  BoxShadow(
                                    color: const Color(0xFFC99A47).withOpacity(0.4),
                                    blurRadius: 8,
                                  ),
                                ]
                              : null,
                        ),
                        child: Center(
                          child: Icon(
                            event.isFavorited ? Icons.favorite : Icons.favorite_border,
                            color: event.isFavorited ? const Color(0xFFE6C17A) : Colors.white70,
                            size: 18,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),

            // Content
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Date row
                  Row(
                    children: [
                      const Icon(Icons.calendar_month, color: Color(0xFFB0CADD), size: 14),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          event.formattedDateTime,
                          style: const TextStyle(
                            color: Color(0xFFB0CADD),
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  // Venue row
                  Row(
                    children: [
                      const Icon(Icons.location_on, color: Color(0xFFB0CADD), size: 14),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          event.locationSummary,
                          style: const TextStyle(
                            color: Color(0xFFB0CADD),
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Price row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        event.formattedPrice,
                        style: const TextStyle(
                          color: Color(0xFFFFB690),
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primaryContainer.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.primaryContainer.withOpacity(0.4)),
                        ),
                        child: const Text(
                          'Đặt vé',
                          style: TextStyle(
                            color: AppColors.primaryContainer,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: const Color(0xFF1E2846),
      child: const Center(
        child: Icon(Icons.event, color: Colors.white24, size: 48),
      ),
    );
  }
}
