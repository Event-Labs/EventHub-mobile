import 'package:flutter/material.dart';
import '../../../../core/models/event_model.dart';

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
                  height: compact ? 120 : 180,
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
              padding: EdgeInsets.all(compact ? 10 : 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: compact ? 13 : 16,
                      fontWeight: FontWeight.bold,
                      height: 1.25,
                    ),
                  ),
                  SizedBox(height: compact ? 6 : 10),
                  // Date row
                  Row(
                    children: [
                      Icon(Icons.calendar_month, color: const Color(0xFFB0CADD), size: compact ? 12 : 14),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          event.formattedDateTime,
                          style: TextStyle(
                            color: const Color(0xFFB0CADD),
                            fontSize: compact ? 11 : 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: compact ? 4 : 6),
                  // Venue row
                  Row(
                    children: [
                      Icon(Icons.location_on, color: const Color(0xFFB0CADD), size: compact ? 12 : 14),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          event.locationSummary,
                          style: TextStyle(
                            color: const Color(0xFFB0CADD),
                            fontSize: compact ? 11 : 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: compact ? 8 : 12),
                  // Price row
                  Text(
                    event.formattedPrice,
                    style: TextStyle(
                      color: const Color(0xFFFFB690),
                      fontSize: compact ? 13 : 15,
                      fontWeight: FontWeight.w800,
                    ),
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
