import 'dart:convert';
import 'package:flutter/material.dart';
import 'app_theme.dart';


//  AvatarStatus

class AvatarStatus extends StatelessWidget {
  final String name;
  final String? photoUrl;
  final double size;
  final bool online;
  final VoidCallback? onTap;

  const AvatarStatus({
    super.key,
    required this.name,
    this.photoUrl,
    this.size = 60,
    this.online = true,
    this.onTap,
  });

  ImageProvider? get _imageProvider {
    if (photoUrl == null || photoUrl!.isEmpty) return null;
    if (photoUrl!.startsWith('data:image')) {
      final b64 = photoUrl!.split(',').last;
      return MemoryImage(base64Decode(b64));
    }
    return NetworkImage(photoUrl!);
  }

  String get _initials {
    final parts = name.trim().split(' ');
    if (parts.isEmpty || name.isEmpty) return '?';
    final first = parts.first.isNotEmpty ? parts.first[0] : '';
    final last = parts.length > 1 && parts.last.isNotEmpty ? parts.last[0] : '';
    return '$first$last'.toUpperCase();
  }

  List<Color> get _gradientColors {
    final palettes = [
      [const Color(0xFF6C63FF), const Color(0xFF9C59FF)],
      [const Color(0xFF06B6D4), const Color(0xFF3B82F6)],
      [const Color(0xFFF59E0B), const Color(0xFFEF4444)],
      [const Color(0xFF10B981), const Color(0xFF06B6D4)],
      [const Color(0xFFEC4899), const Color(0xFF8B5CF6)],
    ];
    final idx = name.isEmpty ? 0 : name.codeUnitAt(0) % palettes.length;
    return palettes[idx];
  }

  @override
  Widget build(BuildContext context) {
    final ringColor = online ? AppColors.primary : AppColors.alternate;

    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Outer ring
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: ringColor, width: 2),
              ),
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: _imageProvider == null
                        ? LinearGradient(colors: _gradientColors)
                        : null,
                    image: _imageProvider != null
                        ? DecorationImage(
                            image: _imageProvider!,
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: _imageProvider == null
                      ? Center(
                          child: Text(
                            _initials,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: size * 0.33,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        )
                      : null,
                ),
              ),
            ),

            // Online indicator dot
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: size * 0.22,
                height: size * 0.22,
                decoration: BoxDecoration(
                  color: online ? AppColors.success : AppColors.accent3,
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
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  RecentItem — matches RecentItemWidget (horizontal scroll recent contacts)
// ─────────────────────────────────────────────────────────────────────────────

class RecentItem extends StatelessWidget {
  final String name;
  final String? photoUrl;
  final bool online;
  final VoidCallback? onTap;

  const RecentItem({
    super.key,
    required this.name,
    this.photoUrl,
    this.online = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          AvatarStatus(name: name, photoUrl: photoUrl, size: 60, online: online),
          const SizedBox(height: 4),
          Text(
            name.split(' ').first, // First name only
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.primaryText,
            ),
          ),
        ],
      ),
    );
  }
}
