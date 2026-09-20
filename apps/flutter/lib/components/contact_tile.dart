import 'package:flutter/material.dart';
import 'app_theme.dart';
import 'avatar_status.dart';
import 'animated_gradient_bg.dart';


//  ContactTile 


class ContactTile extends StatelessWidget {
  final String name;
  final String? photoUrl;
  final bool isOnline;
  final String status;
  final String time;
  final VoidCallback? onTap;
  final VoidCallback? onAudioCall;
  final VoidCallback? onVideoCall;

  const ContactTile({
    super.key,
    required this.name,
    this.photoUrl,
    this.isOnline = true,
    this.status = 'Active now',
    this.time = '',
    this.onTap,
    this.onAudioCall,
    this.onVideoCall,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: GlassmorphicContainer(
        borderRadius: BorderRadius.circular(AppRadius.large),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              AvatarStatus(name: name, photoUrl: photoUrl, size: 52, online: isOnline),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: AppTextStyles.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      status,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: isOnline
                            ? AppColors.success
                            : AppColors.secondaryText,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Call action buttons
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (onAudioCall != null)
                        _CallIconButton(
                          icon: Icons.call_rounded,
                          color: AppColors.success,
                          onTap: onAudioCall!,
                        ),
                      if (onVideoCall != null) ...[
                        const SizedBox(width: 8),
                        _CallIconButton(
                          icon: Icons.videocam_rounded,
                          color: AppColors.primary,
                          onTap: onVideoCall!,
                        ),
                      ],
                    ],
                  ),
                  if (time.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      time,
                      style: AppTextStyles.labelSmall,
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CallIconButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _CallIconButton(
      {required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withValues(alpha: 0.15),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Icon(icon, color: color, size: 18),
      ),
    );
  }
}


//  AppSearchBar 

class AppSearchBar extends StatelessWidget {
  final String hint;
  final String value;
  final void Function(String) onChanged;
  final VoidCallback? onClear;

  const AppSearchBar({
    super.key,
    this.hint = 'Search by name or number',
    this.value = '',
    required this.onChanged,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return GlassmorphicContainer(
      borderRadius: BorderRadius.circular(AppRadius.full),
      color: Colors.white.withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        child: Row(
          children: [
            Icon(Icons.search_rounded,
                color: AppColors.secondaryText, size: 20),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: TextField(
                onChanged: onChanged,
                style: AppTextStyles.bodyMedium,
                decoration: InputDecoration(
                  isDense: true,
                  filled: false,
                  fillColor: Colors.transparent,
                  hintText: hint,
                  hintStyle: AppTextStyles.bodyMedium
                      .copyWith(color: AppColors.accent3),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            if (value.isNotEmpty && onClear != null)
              GestureDetector(
                onTap: onClear,
                child: Icon(Icons.clear_rounded,
                    color: AppColors.secondaryText, size: 18),
              )
            else
              Icon(Icons.mic_rounded, color: AppColors.secondaryText, size: 20),
          ],
        ),
      ),
    );
  }
}


//  ShimmerItem 


class ShimmerItem extends StatefulWidget {
  const ShimmerItem({super.key});

  @override
  State<ShimmerItem> createState() => _ShimmerItemState();
}

class _ShimmerItemState extends State<ShimmerItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.3, end: 0.7).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) {
        final shimmerColor =
            AppColors.alternate.withValues(alpha: _anim.value);
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
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: shimmerColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 120,
                        height: 16,
                        decoration: BoxDecoration(
                          color: shimmerColor,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: 80,
                        height: 12,
                        decoration: BoxDecoration(
                          color: shimmerColor,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
