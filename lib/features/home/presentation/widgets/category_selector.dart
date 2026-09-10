import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

class CategorySelector extends StatelessWidget {
  const CategorySelector({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _CategoryPill(
            label: 'All',
            icon: Icons.local_fire_department,
            isActive: true,
          ),
          const SizedBox(width: 8),
          _CategoryPill(
            label: 'Music',
            icon: Icons.music_note,
            iconColor: AppColors.tertiary,
          ),
          const SizedBox(width: 8),
          _CategoryPill(
            label: 'Festival',
            icon: Icons.festival,
            iconColor: AppColors.primaryContainer,
          ),
          const SizedBox(width: 8),
          _CategoryPill(
            label: 'Tech',
            icon: Icons.lightbulb,
            iconColor: Colors.blueAccent,
          ),
          const SizedBox(width: 8),
          _CategoryPill(
            label: 'Theatre',
            icon: Icons.theater_comedy,
            iconColor: AppColors.tertiary,
          ),
        ],
      ),
    );
  }
}

class _CategoryPill extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isActive;
  final Color? iconColor;

  const _CategoryPill({
    required this.label,
    required this.icon,
    this.isActive = false,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isActive ? AppColors.primaryContainer : AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: isActive ? null : Border.all(color: AppColors.outlineVariant.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 16,
            color: isActive ? AppColors.onPrimary : (iconColor ?? AppColors.secondary),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: isActive ? AppColors.onPrimary : AppColors.secondary,
              fontSize: 12,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
