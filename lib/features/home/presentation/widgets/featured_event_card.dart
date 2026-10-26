import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

import '../pages/event_detail_page.dart';

class FeaturedEventCard extends StatelessWidget {
  const FeaturedEventCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(Icons.bolt, color: AppColors.primaryContainer, size: 18),
                const SizedBox(width: 6),
                Text(
                  'Featured Spotlight',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const Text(
              'View all (12)',
              style: TextStyle(color: AppColors.secondary, fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const EventDetailPage()),
            );
          },
          child: Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.outlineVariant.withOpacity(0.2)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
                      child: Image.network(
                        'https://lh3.googleusercontent.com/aida-public/AB6AXuCsh1MyeOrExv0OTGWPXymZBnHdDiqnLogqJTML1O6osQPpeQP11Xa069TLuCwM-qYBI6xOmazp-7pg5MCxPM4TcaDHr7rhFP7PRyR7QS79TjINZdZ4k4DfgPm1umU1TYFb7w-_8bpoVl9R1VTWzNVop69NIQAPIhcnx8LZ1FDgsJ4ME58mNas6uSxXTAiSOwUKbbgiKBdEG1KIhXlEOKa-7pEzLNe1z7_DJbEJhZKSIizd6czYP7-3',
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(color: const Color(0xFF1E2846)),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.primaryContainer,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'HOT SELLING',
                            style: TextStyle(color: AppColors.onPrimary, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppColors.tertiaryContainer.withOpacity(0.3)),
                          ),
                          child: const Text(
                            '18+ VIP Lounge',
                            style: TextStyle(color: AppColors.tertiary, fontSize: 9, fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.outlineVariant.withOpacity(0.3)),
                      ),
                      child: const Column(
                        children: [
                          Text('DEC', style: TextStyle(color: AppColors.primary, fontSize: 8, fontWeight: FontWeight.bold)),
                          Text('28', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'NEON HORIZON FESTIVAL 2025',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.schedule, color: AppColors.primaryContainer, size: 14),
                        const SizedBox(width: 4),
                        const Text('18:00 - 02:00', style: TextStyle(color: AppColors.secondary, fontSize: 12)),
                        const SizedBox(width: 8),
                        Container(width: 4, height: 4, decoration: const BoxDecoration(color: Colors.white24, shape: BoxShape.circle)),
                        const SizedBox(width: 8),
                        const Icon(Icons.pin_drop, color: AppColors.secondary, size: 14),
                        const SizedBox(width: 4),
                        const Text('SECC District 7, HCMC', style: TextStyle(color: AppColors.secondary, fontSize: 12)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Divider(color: Colors.white10),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('TICKETS FROM', style: TextStyle(color: Colors.white38, fontSize: 9, fontWeight: FontWeight.bold)),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                const Text('450.000', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                                const SizedBox(width: 4),
                                const Text('VND', style: TextStyle(color: AppColors.primaryContainer, fontSize: 11, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          decoration: BoxDecoration(
                            color: AppColors.primaryContainer,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primaryContainer.withOpacity(0.35),
                                blurRadius: 24,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: const Row(
                            children: [
                              Text('Get Tickets', style: TextStyle(color: AppColors.onPrimary, fontWeight: FontWeight.w600)),
                              SizedBox(width: 6),
                              Icon(Icons.arrow_forward, color: AppColors.onPrimary, size: 18),
                            ],
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
      ),
      ],
    );
  }
}
