import 'package:flutter/material.dart';
import 'app_theme.dart';
import 'animated_gradient_bg.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  CallHistoryTile — matches CallHistoryTileWidget from FlutterFlow
//  Shows avatar initials, name (red if missed), direction icon, time, 
//  video/info action buttons.
// ─────────────────────────────────────────────────────────────────────────────

class CallHistoryTile extends StatelessWidget {
  final String name;
  final String time;
  final bool isMissed;
  final bool isVideo;
  final String type; // 'incoming' | 'outgoing' | 'missed'
  final VoidCallback? onCallBack;
  final VoidCallback? onDelete;
  final int? durationSeconds; // call duration in seconds, if available

  const CallHistoryTile({
    super.key,
    required this.name,
    required this.time,
    this.isMissed = false,
    this.isVideo = false,
    this.type = 'incoming',
    this.onCallBack,
    this.onDelete,
    this.durationSeconds,
  });

  String get _initials {
    final parts = name.trim().split(' ');
    if (parts.isEmpty || name.isEmpty) return '?';
    return parts.map((p) => p.isNotEmpty ? p[0] : '').take(2).join().toUpperCase();
  }

  IconData get _directionIcon {
    if (isMissed) return Icons.call_missed_rounded;
    return type == 'outgoing'
        ? Icons.north_east_rounded
        : Icons.south_west_rounded;
  }

  String? get _durationLabel {
    if (durationSeconds == null || durationSeconds! <= 0) return null;
    final m = durationSeconds! ~/ 60;
    final s = durationSeconds! % 60;
    if (m > 0) return '${m}m ${s}s';
    return '${s}s';
  }

  @override
  Widget build(BuildContext context) {
    final nameColor = isMissed ? AppColors.error : AppColors.primaryText;
    final statusColor = isMissed ? AppColors.error : AppColors.secondaryText;

    return GlassmorphicContainer(
      borderRadius: BorderRadius.circular(AppRadius.large),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            // Avatar with online dot
            SizedBox(
              width: 48,
              height: 48,
              child: Stack(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFF10141E),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0x402678FF), width: 1),
                    ),
                    child: Center(
                      child: Text(
                        _initials,
                        style: AppTextStyles.labelMedium.copyWith(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: isMissed ? AppColors.error : AppColors.success,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.secondaryBackground,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.md),

            // Name and subtitle
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: AppTextStyles.titleMedium.copyWith(color: nameColor),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(_directionIcon, color: statusColor, size: 14),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          _durationLabel != null ? '$time · $_durationLabel' : time,
                          style: AppTextStyles.bodySmall.copyWith(
                              color: statusColor),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.md),

            // Action buttons
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Video/audio call back button (electric blue tint with soft glow)
                GestureDetector(
                  onTap: onCallBack,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0x262678FF),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0x402678FF), width: 1),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF2678FF).withValues(alpha: 0.25),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: Icon(
                      isVideo ? Icons.videocam_rounded : Icons.call_rounded,
                      color: const Color(0xFF2678FF),
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Delete button
                Semantics(
                  label: 'Delete call record',
                  button: true,
                  child: GestureDetector(
                    onTap: onDelete,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(shape: BoxShape.circle),
                      child: const Icon(
                        Icons.delete_outline_rounded,
                        color: Color(0xFF8A8F98),
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  TabGroup — matches TabGroupWidget from FlutterFlow
// ─────────────────────────────────────────────────────────────────────────────

class TabGroup extends StatefulWidget {
  final List<String> labels;
  final int selectedIndex;
  final void Function(int) onChanged;

  const TabGroup({
    super.key,
    required this.labels,
    this.selectedIndex = 0,
    required this.onChanged,
  });

  @override
  State<TabGroup> createState() => _TabGroupState();
}

class _TabGroupState extends State<TabGroup> {
  late int _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.selectedIndex;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF101114),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x14FFFFFF), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Row(
          children: List.generate(widget.labels.length, (i) {
            final isSelected = i == _selected;
            return Expanded(
              child: GestureDetector(
                onTap: () {
                  setState(() => _selected = i);
                  widget.onChanged(i);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  decoration: BoxDecoration(
                    gradient: isSelected
                        ? const LinearGradient(
                            colors: [Color(0xFF1455D9), Color(0xFF2678FF)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : null,
                    color: isSelected ? null : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: const Color(0xFF2678FF).withValues(alpha: 0.40),
                              blurRadius: 12,
                              spreadRadius: 0,
                            ),
                          ]
                        : null,
                  ),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  child: Text(
                    widget.labels[i],
                    textAlign: TextAlign.center,
                    style: AppTextStyles.labelMedium.copyWith(
                      color: isSelected
                          ? Colors.white
                          : const Color(0xFF8A8F98),
                      fontWeight:
                          isSelected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}
