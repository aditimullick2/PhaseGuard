import 'package:flutter/material.dart';
import 'app_theme.dart';
import 'animated_gradient_bg.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/locale_provider.dart';
import '../l10n/app_translations.dart';

//  AppBottomNav 

class AppBottomNav extends ConsumerWidget {
  final int selectedIndex;
  final void Function(int) onTap;

  static const _tabs = [
    _NavTab(icon: Icons.home_rounded, labelKey: 'home'),
    _NavTab(icon: Icons.people_rounded, labelKey: 'contacts'),
    _NavTab(icon: Icons.history_rounded, labelKey: 'history'),
    _NavTab(icon: Icons.settings_rounded, labelKey: 'settings'),
  ];

  const AppBottomNav({
    super.key,
    required this.selectedIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    return GlassmorphicContainer(
      borderRadius: BorderRadius.zero,
      padding: EdgeInsets.zero,
      color: const Color(0xF2080808),
      border: const Border(top: BorderSide(color: Color(0x14FFFFFF), width: 1)),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(_tabs.length, (i) {
              final isSelected = i == selectedIndex;
              final tab = _tabs[i];
              return _NavItem(
                icon: tab.icon,
                label: AppTranslations.get(locale, tab.labelKey),
                isSelected: isSelected,
                onTap: () => onTap(i),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _NavTab {
  final IconData icon;
  final String labelKey;
  const _NavTab({required this.icon, required this.labelKey});
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color =
        isSelected ? const Color(0xFF2678FF) : const Color(0xFF8A8F98);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0x2E2678FF) : Colors.transparent,
                borderRadius: BorderRadius.circular(AppRadius.full),
                border: isSelected
                    ? Border.all(color: const Color(0x402678FF), width: 1)
                    : null,
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: const Color(0xFF2678FF).withValues(alpha: 0.40),
                          blurRadius: 16,
                          spreadRadius: 0,
                        ),
                      ]
                    : null,
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 2),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 180),
              style: AppTextStyles.labelSmall.copyWith(
                color: color,
                fontWeight:
                    isSelected ? FontWeight.w700 : FontWeight.w500,
                shadows: isSelected
                    ? [
                        Shadow(
                          color: const Color(0xFF2678FF).withValues(alpha: 0.55),
                          blurRadius: 10,
                        ),
                      ]
                    : null,
              ),
              child: Text(label),
            ),
          ],
        ),
      ),
    );
  }
}
