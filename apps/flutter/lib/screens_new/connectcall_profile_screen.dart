import 'dart:convert';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/user.dart';
import '../providers/providers.dart';
import '../providers/locale_provider.dart';
import '../l10n/app_translations.dart';
import '../components/app_theme.dart';
import '../components/animated_gif_background.dart';
import '../components/app_button.dart';
import 'login_screen.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  final UserModel user;

  const ProfileScreen({super.key, required this.user});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  // ── Permission status cache (refreshed on each build) ───────────────────

  bool? _micGranted;
  bool? _camGranted;
  bool? _notifGranted;

  @override
  void initState() {
    super.initState();
    _refreshPermissionStatus();
  }

  Future<void> _refreshPermissionStatus() async {
    final mic = await Permission.microphone.status;
    final cam = await Permission.camera.status;
    final notif = await Permission.notification.status;
    if (mounted) {
      setState(() {
        _micGranted = mic.isGranted;
        _camGranted = cam.isGranted;
        _notifGranted = notif.isGranted;
      });
    }
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: AppColors.secondaryBackground,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _showInfoDialog({
    required String title,
    required String body,
    IconData? icon,
  }) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: AppColors.secondaryBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Container(
                  width: 56,
                  height: 56,
                  decoration: const BoxDecoration(
                    color: AppColors.primary10,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: AppColors.primary, size: 28),
                ),
                const SizedBox(height: 16),
              ],
              Text(title,
                  style: AppTextStyles.titleMedium,
                  textAlign: TextAlign.center),
              const SizedBox(height: 12),
              Text(body,
                  style: AppTextStyles.bodyMedium
                      .copyWith(color: AppColors.secondaryText),
                  textAlign: TextAlign.center),
              const SizedBox(height: 24),
              AppButton(
                content: 'Got it',
                fullWidth: true,
                onTap: () => Navigator.pop(ctx),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: AppColors.secondaryBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.logout_rounded,
                    color: AppColors.error, size: 28),
              ),
              const SizedBox(height: 16),
              Text('Log Out?', style: AppTextStyles.titleMedium),
              const SizedBox(height: 12),
              Text(
                'You\'ll need to sign in again to make and receive calls.',
                style: AppTextStyles.bodyMedium
                    .copyWith(color: AppColors.secondaryText),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: AppButton(
                      content: 'Cancel',
                      variant: 'outline',
                      onTap: () => Navigator.pop(ctx, false),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AppButton(
                      content: 'Log Out',
                      variant: 'destructive',
                      onTap: () => Navigator.pop(ctx, true),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (confirm == true && mounted) {
      await ref.read(authServiceProvider).signOut();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }
    }
  }

  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 256,
        maxHeight: 256,
        imageQuality: 60,
      );
      if (image == null) return;
      
      final Uint8List bytes = await image.readAsBytes();
      final String base64Image = 'data:image/jpeg;base64,${base64Encode(bytes)}';
      
      await ref.read(userServiceProvider).updateProfilePhoto(widget.user.uid, base64Image);
      _showSnack('Profile photo updated ✓');
    } catch (e) {
      _showSnack('Failed to update photo.');
    }
  }

  Future<void> _handlePermission(Permission permission, String label) async {
    final status = await permission.request();
    if (!mounted) return;

    if (status.isGranted) {
      _showSnack('$label access granted ✓');
    } else if (status.isPermanentlyDenied) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => Dialog(
          backgroundColor: AppColors.secondaryBackground,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.block_rounded,
                    color: AppColors.error, size: 40),
                const SizedBox(height: 16),
                Text('$label Permission Denied',
                    style: AppTextStyles.titleMedium),
                const SizedBox(height: 12),
                Text(
                  '$label access was permanently denied. Open Settings to enable it.',
                  style: AppTextStyles.bodyMedium
                      .copyWith(color: AppColors.secondaryText),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: AppButton(
                        content: 'Cancel',
                        variant: 'outline',
                        onTap: () => Navigator.pop(ctx),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AppButton(
                        content: 'Open Settings',
                        onTap: () {
                          Navigator.pop(ctx);
                          openAppSettings();
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    } else {
      _showSnack('$label access denied. You can change this in Settings.');
    }
    _refreshPermissionStatus();
  }

  void _showHelpCenter() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: AppColors.secondaryBackground,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.alternate,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text('Help Center', style: AppTextStyles.titleLarge),
            const SizedBox(height: 16),
            ..._helpItems.map((item) => _HelpItem(
                  icon: item['icon'] as IconData,
                  title: item['title'] as String,
                  body: item['body'] as String,
                )),
            const SizedBox(height: 16),
            AppButton(
              content: 'Close',
              variant: 'ghost',
              fullWidth: true,
              onTap: () => Navigator.pop(ctx),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  static const _helpItems = [
    {
      'icon': Icons.call_rounded,
      'title': 'How do I make a call?',
      'body':
          'Go to Contacts, find a user, and tap the phone or video icon to start a call.',
    },
    {
      'icon': Icons.mic_off_rounded,
      'title': 'Call audio not working?',
      'body':
          'Ensure Microphone permission is granted in Settings → Privacy & Access → Microphone.',
    },
    {
      'icon': Icons.notifications_rounded,
      'title': 'Not receiving call notifications?',
      'body':
          'Enable Notifications in Settings → Privacy & Access → Notifications.',
    },
    {
      'icon': Icons.security_rounded,
      'title': 'Is my call secure?',
      'body':
          'Yes. All ConnectCall audio and video is encrypted end-to-end using Agora\'s secure channel protocol.',
    },
  ];

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeProvider);
    
    ImageProvider? getProfileImage() {
      final url = widget.user.photoUrl;
      if (url == null || url.isEmpty) return null;
      if (url.startsWith('data:image')) {
        return MemoryImage(base64Decode(url.split(',').last));
      }
      return NetworkImage(url);
    }

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: AppColors.primaryBackground,
        body: SingleChildScrollView(
          primary: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Profile Header with GIF Background
              SizedBox(
                height: 340,
                child: Stack(
                  alignment: const AlignmentDirectional(0, 0),
                  children: [
                    Positioned.fill(
                      child: AnimatedGifBackground(
                        assetPath: 'assets/background/profile_bg.gif',
                        overlayOpacity: 0.6,
                        child: const SizedBox.shrink(),
                      ),
                    ),
                    SafeArea(
                      bottom: false,
                      child: Align(
                        alignment: const AlignmentDirectional(0, 0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // Avatar with camera edit button
                            Stack(
                              alignment: const AlignmentDirectional(1, 1),
                              children: [
                                Container(
                                  width: 110,
                                  height: 110,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: AppColors.secondaryBackground,
                                      width: 4,
                                    ),
                                  ),
                                  child: CircleAvatar(
                                    backgroundColor: AppColors.surfaceVariant,
                                    backgroundImage: getProfileImage(),
                                    child: widget.user.photoUrl == null ||
                                            widget.user.photoUrl!.isEmpty
                                        ? Text(
                                            widget.user.name.isNotEmpty
                                                ? widget.user.name[0]
                                                    .toUpperCase()
                                                : 'U',
                                            style: AppTextStyles.titleLarge
                                                .copyWith(
                                                    color: AppColors.primary),
                                          )
                                        : null,
                                  ),
                                ),
                                // Camera edit button
                                Semantics(
                                  label: 'Edit profile photo',
                                  button: true,
                                  child: GestureDetector(
                                    onTap: _pickImage,
                                    child: Container(
                                      width: 32,
                                      height: 32,
                                      decoration: BoxDecoration(
                                        color: AppColors.primary,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: AppColors.secondaryBackground,
                                          width: 2,
                                        ),
                                      ),
                                      alignment:
                                          const AlignmentDirectional(0, 0),
                                      child: const Icon(
                                        Icons.photo_camera_rounded,
                                        color: AppColors.onPrimary,
                                        size: 16,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  widget.user.name.isNotEmpty
                                      ? widget.user.name
                                      : 'User',
                                  style: AppTextStyles.titleLarge.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${widget.user.email} • Premium',
                                  style: AppTextStyles.bodySmall.copyWith(
                                    color: AppColors.onPrimaryContainer,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Settings Body
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // PREFERENCES
                    _SettingGroup(
                      title: AppTranslations.get(locale, 'preferences'),
                      children: [
                        _buildSettingRow(
                          icon: Icons.dark_mode_rounded,
                          title: AppTranslations.get(locale, 'dark_mode'),
                          subtitle: AppTranslations.get(locale, 'dark_mode_sub'),
                          onTap: () => _showInfoDialog(
                            title: AppTranslations.get(locale, 'dark_mode'),
                            body: 'ConnectCall automatically follows your device\'s system appearance.',
                            icon: Icons.dark_mode_rounded,
                          ),
                          trailing: const Icon(Icons.info_outline_rounded,
                              color: AppColors.secondaryText, size: 18),
                        ),
                        Divider(
                            color: Colors.white.withValues(alpha: 0.05), height: 1),
                        _buildSettingRow(
                          icon: Icons.notifications_active_rounded,
                          title: AppTranslations.get(locale, 'notifications'),
                          subtitle: AppTranslations.get(locale, 'notifications_sub'),
                          trailing: Switch(
                            value: _notifGranted ?? false,
                            activeColor: AppColors.primary,
                            activeTrackColor: AppColors.primary20,
                            inactiveThumbColor: AppColors.secondaryText,
                            inactiveTrackColor: AppColors.surface30,
                            onChanged: (val) async {
                              if (val) {
                                final status = await Permission.notification.status;
                                if (!status.isGranted) {
                                  final result = await Permission.notification.request();
                                  if (result.isPermanentlyDenied) {
                                    openAppSettings();
                                  } else if (result.isGranted) {
                                    _showSnack('Notifications enabled ✓');
                                  } else {
                                    _showSnack('Notifications denied. Enable in device Settings.');
                                  }
                                }
                              } else {
                                openAppSettings(); // Can't disable programmatically, open settings
                                _showSnack('Disable notifications in device settings');
                              }
                              await _refreshPermissionStatus();
                            },
                          ),
                          onTap: () async {
                            openAppSettings();
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // PRIVACY & ACCESS
                    _SettingGroup(
                      title: AppTranslations.get(locale, 'privacy'),
                      children: [
                        _buildSettingRow(
                          icon: Icons.videocam_rounded,
                          title: AppTranslations.get(locale, 'camera_access'),
                          subtitle: _camGranted == true ? 'Granted ✓' : 'Denied ✗',
                          subtitleColor: _camGranted == true ? AppColors.success : AppColors.error,
                          trailing: Switch(
                            value: _camGranted ?? false,
                            activeColor: AppColors.primary,
                            activeTrackColor: AppColors.primary20,
                            inactiveThumbColor: AppColors.secondaryText,
                            inactiveTrackColor: AppColors.surface30,
                            onChanged: (val) async {
                              if (val) {
                                final status = await Permission.camera.request();
                                if (status.isPermanentlyDenied) openAppSettings();
                              } else {
                                openAppSettings();
                                _showSnack('Disable camera access in device settings');
                              }
                              await _refreshPermissionStatus();
                            },
                          ),
                          onTap: openAppSettings,
                        ),
                        Divider(
                            color: Colors.white.withValues(alpha: 0.05), height: 1),
                        _buildSettingRow(
                          icon: Icons.mic_rounded,
                          title: AppTranslations.get(locale, 'microphone'),
                          subtitle: _micGranted == true ? 'Granted ✓' : 'Denied ✗',
                          subtitleColor: _micGranted == true ? AppColors.success : AppColors.error,
                          trailing: Switch(
                            value: _micGranted ?? false,
                            activeColor: AppColors.primary,
                            activeTrackColor: AppColors.primary20,
                            inactiveThumbColor: AppColors.secondaryText,
                            inactiveTrackColor: AppColors.surface30,
                            onChanged: (val) async {
                              if (val) {
                                final status = await Permission.microphone.request();
                                if (status.isPermanentlyDenied) openAppSettings();
                              } else {
                                openAppSettings();
                                _showSnack('Disable microphone access in device settings');
                              }
                              await _refreshPermissionStatus();
                            },
                          ),
                          onTap: openAppSettings,
                        ),
                        Divider(
                            color: Colors.white.withValues(alpha: 0.05), height: 1),
                        _buildSettingRow(
                          icon: Icons.security_rounded,
                          title: AppTranslations.get(locale, 'e2ee'),
                          subtitle: AppTranslations.get(locale, 'e2ee_sub'),
                          onTap: () => _showInfoDialog(
                            title: AppTranslations.get(locale, 'e2ee'),
                            body: 'All ConnectCall audio and video streams are encrypted using Agora\'s secure channel encryption.',
                            icon: Icons.security_rounded,
                          ),
                          trailing: const Icon(Icons.verified_rounded,
                              color: AppColors.success, size: 18),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // ACCOUNT
                    _SettingGroup(
                      title: AppTranslations.get(locale, 'account'),
                      children: [
                        _buildSettingRow(
                          icon: Icons.language_rounded,
                          title: AppTranslations.get(locale, 'lang_title'),
                          subtitle: AppTranslations.get(locale, 'language'),
                          onTap: () {
                            ref.read(localeProvider.notifier).toggleLocale();
                          },
                        ),
                        Divider(
                            color: Colors.white.withValues(alpha: 0.05), height: 1),
                        _buildSettingRow(
                          icon: Icons.help_outline_rounded,
                          title: AppTranslations.get(locale, 'help'),
                          subtitle: AppTranslations.get(locale, 'help_sub'),
                          onTap: _showHelpCenter,
                        ),
                      ],
                    ),

                    // Log Out Button
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: AppButton(
                        content: AppTranslations.get(locale, 'logout'),
                        variant: 'destructive',
                        icon: const Icon(Icons.logout_rounded,
                            size: 24, color: Colors.white),
                        fullWidth: true,
                        onTap: _confirmLogout,
                      ),
                    ),

                    // Version
                    Padding(
                      padding: const EdgeInsets.only(bottom: 24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            'ConnectCall v2.4.0',
                            style: AppTextStyles.labelSmall.copyWith(
                              color: AppColors.accent3,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Made with precision by Design Studio',
                            style: AppTextStyles.labelSmall.copyWith(
                              color:
                                  AppColors.secondaryText.withValues(alpha: 0.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSettingRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color? subtitleColor,
    Widget? trailing,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            Icon(icon, color: AppColors.primary, size: 20),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title, style: AppTextStyles.labelMedium),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: subtitleColor ?? AppColors.secondaryText,
                    ),
                  ),
                ],
              ),
            ),
            if (trailing != null)
              trailing
            else
              const Icon(Icons.chevron_right_rounded,
                  color: AppColors.alternate, size: 18),
          ],
        ),
      ),
    );
  }
}

// Help Center Bottom Sheet Item

class _HelpItem extends StatefulWidget {
  final IconData icon;
  final String title;
  final String body;

  const _HelpItem(
      {required this.icon, required this.title, required this.body});

  @override
  State<_HelpItem> createState() => _HelpItemState();
}

class _HelpItemState extends State<_HelpItem> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTap: () => setState(() => _expanded = !_expanded),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.alternate),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(widget.icon, color: AppColors.primary, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(widget.title, style: AppTextStyles.labelMedium),
                  ),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: AppColors.secondaryText,
                    size: 20,
                  ),
                ],
              ),
              AnimatedCrossFade(
                duration: const Duration(milliseconds: 200),
                crossFadeState: _expanded
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                firstChild: const SizedBox.shrink(),
                secondChild: Padding(
                  padding: const EdgeInsets.only(top: 12, left: 32),
                  child: Text(
                    widget.body,
                    style: AppTextStyles.bodyMedium
                        .copyWith(color: AppColors.secondaryText),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

//  Setting Group 

class _SettingGroup extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _SettingGroup({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 16, bottom: 8),
          child: Text(title, style: AppTextStyles.labelSmall),
        ),
        Container(
          decoration: BoxDecoration(
            color: AppColors.secondaryBackground,
            borderRadius: BorderRadius.circular(AppRadius.large),
            border: Border.all(color: AppColors.alternate, width: 1),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: children,
          ),
        ),
      ],
    );
  }
}
