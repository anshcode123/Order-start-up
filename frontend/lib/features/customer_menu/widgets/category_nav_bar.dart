import 'package:flutter/material.dart';
import 'package:scanserve/core/theme/app_colors.dart';
import 'package:scanserve/core/theme/app_text_styles.dart';
import 'package:scanserve/shared/models/public_menu.dart';

/// "All | Starters | Main Course | ..." - selecting a chip filters which
/// category sections the menu screen shows. Scrolls horizontally on
/// narrow screens so it never wraps awkwardly on mobile.
class CategoryNavBar extends StatelessWidget {
  const CategoryNavBar({
    super.key,
    required this.categories,
    required this.selectedCategoryId,
    required this.onSelect,
  });

  final List<PublicMenuCategory> categories;
  final String? selectedCategoryId; // null means "All"
  final ValueChanged<String?> onSelect;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _Chip(label: 'All', selected: selectedCategoryId == null, onTap: () => onSelect(null)),
          for (final category in categories)
            _Chip(
              label: category.name,
              selected: selectedCategoryId == category.id,
              onTap: () => onSelect(category.id),
            ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: Material(
        color: selected ? AppColors.primary : AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: selected ? AppColors.primary : AppColors.border),
            ),
            child: Text(
              label,
              style: AppTextStyles.bodySmall.copyWith(
                color: selected ? Colors.white : AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
