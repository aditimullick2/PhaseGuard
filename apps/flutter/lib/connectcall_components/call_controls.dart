import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  ControlButton — solid call control button (matches ControlButtonWidget)
//  Used in audio call screen.
// ─────────────────────────────────────────────────────────────────────────────

class ControlButton extends StatelessWidget {
  final Widget icon;
  final bool isDanger;
  final double size;
  final VoidCallback? onTap;
  final String? label;

  const ControlButton({
    super.key,
    required this.icon,
    this.isDanger = false,
    this.size = 64,
    this.onTap,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: isDanger ? AppColors.tertiary : AppColors.onPrimary10,
              shape: BoxShape.circle,
              boxShadow: isDanger
                  ? [
                      BoxShadow(
                        color: AppColors.tertiary.withValues(alpha: 0.4),
                        blurRadius: 20,
                        spreadRadius: 4,
                      )
                    ]
                  : null,
            ),
            child: Center(child: icon),
          ),
        ),
        if (label != null) ...[
          const SizedBox(height: 6),
          Text(
            label!,
            style: AppTextStyles.bodySmall,
          ),
        ] else ...[
          const SizedBox(height: 6),
          Text(
            ' ', // Placeholder to keep the icons vertically aligned
            style: AppTextStyles.bodySmall,
          ),
        ],
      ],
    );
  }
}


//  ControlButton2 
class ControlButton2 extends StatelessWidget {
  final Widget icon;
  final bool isDanger;
  final bool isActive;
  final Color? activeColor;
  final double size;
  final VoidCallback? onTap;
  final String? label;

  const ControlButton2({
    super.key,
    required this.icon,
    this.isDanger = false,
    this.isActive = false,
    this.activeColor,
    this.size = 56,
    this.onTap,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = isDanger
        ? AppColors.tertiary
        : isActive
            ? (activeColor ?? AppColors.primary).withValues(alpha: 0.3)
            : AppColors.surface30;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onTap,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.full),
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  color: effectiveColor,
                  shape: BoxShape.circle,
                  border: isActive && !isDanger
                      ? Border.all(
                          color: (activeColor ?? AppColors.primary)
                              .withValues(alpha: 0.5),
                          width: 1.5)
                      : null,
                ),
                child: Center(child: icon),
              ),
            ),
          ),
        ),
        if (label != null) ...[
          const SizedBox(height: 6),
          Text(label!, style: AppTextStyles.bodySmall),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  ActionButton — large action with shadow + label (matches ActionButtonWidget)
//  Used for Accept / Decline buttons on incoming call screen.
// ─────────────────────────────────────────────────────────────────────────────

class ActionButton extends StatelessWidget {
  final Widget icon;
  final Color bg;
  final String label;
  final VoidCallback? onTap;
  final double size;

  const ActionButton({
    super.key,
    required this.icon,
    required this.bg,
    required this.label,
    this.onTap,
    this.size = 72,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: bg,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: bg.withValues(alpha: 0.4),
                  blurRadius: 20,
                  spreadRadius: 4,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Center(child: icon),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: AppTextStyles.labelMedium.copyWith(
            color: AppColors.onPrimary,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  QualityPill — frosted glass quality indicator (matches QualityPillWidget)
// ─────────────────────────────────────────────────────────────────────────────

class QualityPill extends StatelessWidget {
  final String quality;
  final Color tone;

  const QualityPill({
    super.key,
    this.quality = 'HD High',
    this.tone = AppColors.success,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.full),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surface40,
            borderRadius: BorderRadius.circular(AppRadius.full),
            border: Border.all(color: AppColors.surface20, width: 1),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: tone,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  quality,
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.onSurface,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  SettingRow — settings list row (matches SettingRowWidget from FlutterFlow)
// ─────────────────────────────────────────────────────────────────────────────

class SettingRow extends StatelessWidget {
  final Widget icon;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const SettingRow({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle = '',
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          children: [
            // Icon circle
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.primary10,
                shape: BoxShape.circle,
              ),
              child: Center(child: icon),
            ),
            const SizedBox(width: AppSpacing.md),

            // Title + subtitle
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.titleMedium.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: AppTextStyles.labelSmall,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.md),

            // Trailing widget or chevron
            trailing ??
                Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.alternate,
                  size: 20,
                ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  PermissionItem — permission explanation card (matches PermissionItemWidget)
// ─────────────────────────────────────────────────────────────────────────────

class PermissionItem extends StatelessWidget {
  final Widget icon;
  final String title;
  final String description;

  const PermissionItem({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.secondaryBackground,
        borderRadius: BorderRadius.circular(AppRadius.large),
        border: Border.all(color: AppColors.alternate, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            // Icon
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.primary10,
                shape: BoxShape.circle,
              ),
              child: Center(child: icon),
            ),
            const SizedBox(width: AppSpacing.md),

            // Text
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.titleSmall.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Add AppColors extension for easy access in components
extension AppColorsExt on AppColors {
  static const primary10 = Color(0x1A6C63FF);
}
