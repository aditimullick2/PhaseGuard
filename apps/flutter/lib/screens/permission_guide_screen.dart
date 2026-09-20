import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../components/app_theme.dart';
import '../components/animated_gradient_bg.dart';
import '../components/app_button.dart';

class PermissionGuideScreen extends StatefulWidget {
  const PermissionGuideScreen({super.key});

  @override
  State<PermissionGuideScreen> createState() => _PermissionGuideScreenState();
}

class _PermissionGuideScreenState extends State<PermissionGuideScreen> {
  bool _micGranted = false;
  bool _camGranted = false;
  bool _notifGranted = false;
  bool _isRequesting = false;

  @override
  void initState() {
    super.initState();
    _refreshStatuses();
  }

  Future<void> _refreshStatuses() async {
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

  Future<void> _requestAll() async {
    setState(() => _isRequesting = true);
    try {
      final results = await [
        Permission.microphone,
        Permission.camera,
        Permission.notification,
      ].request();

      if (mounted) {
        setState(() {
          _micGranted = results[Permission.microphone]?.isGranted ?? false;
          _camGranted = results[Permission.camera]?.isGranted ?? false;
          _notifGranted = results[Permission.notification]?.isGranted ?? false;
        });
      }

      // If at least microphone is granted, proceed
      if ((_micGranted) && mounted) {
        // Show success briefly then pop
        await Future.delayed(const Duration(milliseconds: 600));
        if (mounted) Navigator.of(context).pop();
      } else if (mounted) {
        // Some permissions denied — show dialog
        final anyPermanent = (results[Permission.microphone]?.isPermanentlyDenied ?? false) ||
            (results[Permission.camera]?.isPermanentlyDenied ?? false);
        if (anyPermanent) {
          await showDialog<void>(
            context: context,
            builder: (ctx) => Dialog(
              backgroundColor: AppColors.secondaryBackground,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.settings_rounded,
                        color: AppColors.primary, size: 40),
                    const SizedBox(height: 16),
                    Text('Open Settings', style: AppTextStyles.titleMedium),
                    const SizedBox(height: 12),
                    Text(
                      'Some permissions were permanently denied. Please open Settings and grant them manually.',
                      style: AppTextStyles.bodyMedium
                          .copyWith(color: AppColors.secondaryText),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: AppButton(
                            content: 'Later',
                            variant: 'ghost',
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
        }
      }
    } finally {
      if (mounted) setState(() => _isRequesting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final allGranted = _micGranted && _camGranted;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: AppColors.primaryBackground,
        body: Stack(
          alignment: const AlignmentDirectional(-1, -1),
          children: [
            const AnimatedGradientBg(
              preset: GradientPreset.hero,
              height: 200,
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.max,
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Hero Icon
                    SizedBox(
                      height: 240,
                      child: Stack(
                        alignment: const AlignmentDirectional(0, 0),
                        children: [
                          ClipRect(
                            child: ImageFiltered(
                              imageFilter: ImageFilter.blur(
                                sigmaX: 40,
                                sigmaY: 40,
                              ),
                              child: Container(
                                width: 180,
                                height: 180,
                                decoration: BoxDecoration(
                                  color: AppColors.primary10,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                          ),
                          Align(
                            alignment: const AlignmentDirectional(0, 0),
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 400),
                              child: allGranted
                                  ? const Icon(Icons.verified_rounded,
                                      key: ValueKey('check'),
                                      size: 100,
                                      color: AppColors.success)
                                  : const Icon(Icons.security_rounded,
                                      key: ValueKey('shield'),
                                      size: 100,
                                      color: AppColors.primaryLight),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Title
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          allGranted ? 'You\'re all set!' : 'Let\'s get connected',
                          textAlign: TextAlign.center,
                          style: AppTextStyles.titleLarge.copyWith(
                            fontWeight: FontWeight.w800,
                            fontSize: 28,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          allGranted
                              ? 'All required permissions are granted. You can now make high-quality calls.'
                              : 'To start high-quality video and audio calls, ConnectCall needs a few permissions.',
                          textAlign: TextAlign.center,
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.secondaryText,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),

                    // Permission Items
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        _PermissionRow(
                          icon: Icons.mic_rounded,
                          title: 'Microphone Access',
                          description: 'Required for others to hear your voice clearly.',
                          isGranted: _micGranted,
                          isRequired: true,
                        ),
                        const SizedBox(height: 16),
                        _PermissionRow(
                          icon: Icons.videocam_rounded,
                          title: 'Camera Access',
                          description: 'Used so friends can see you during video calls.',
                          isGranted: _camGranted,
                          isRequired: true,
                        ),
                        const SizedBox(height: 16),
                        _PermissionRow(
                          icon: Icons.notifications_active_rounded,
                          title: 'Notifications',
                          description: 'Stay updated when you have an incoming call.',
                          isGranted: _notifGranted,
                          isRequired: false,
                        ),
                      ],
                    ),
                    const Spacer(flex: 2),

                    // Buttons
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        if (allGranted)
                          AppButton(
                            content: 'Continue',
                            variant: 'primary',
                            size: 'large',
                            fullWidth: true,
                            onTap: () => Navigator.of(context).pop(),
                          )
                        else
                          AppButton(
                            content: _isRequesting
                                ? 'Requesting...'
                                : 'Enable Access',
                            variant: 'primary',
                            size: 'large',
                            fullWidth: true,
                            loading: _isRequesting,
                            onTap: _isRequesting ? null : _requestAll,
                          ),
                        const SizedBox(height: 16),
                        AppButton(
                          content: 'Maybe Later',
                          variant: 'ghost',
                          size: 'medium',
                          fullWidth: true,
                          onTap: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PermissionRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final bool isGranted;
  final bool isRequired;

  const _PermissionRow({
    required this.icon,
    required this.title,
    required this.description,
    required this.isGranted,
    this.isRequired = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isGranted
                ? AppColors.success.withValues(alpha: 0.12)
                : AppColors.primary10,
            shape: BoxShape.circle,
            border: Border.all(
              color: isGranted
                  ? AppColors.success.withValues(alpha: 0.3)
                  : AppColors.primary20,
              width: 1,
            ),
          ),
          child: Icon(icon,
              color: isGranted ? AppColors.success : AppColors.primaryLight,
              size: 28),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(title, style: AppTextStyles.titleMedium),
                  if (isRequired) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primary10,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text('Required',
                          style: AppTextStyles.labelSmall.copyWith(
                              color: AppColors.primary, fontSize: 10)),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.secondaryText,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(
                    isGranted
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked_rounded,
                    color:
                        isGranted ? AppColors.success : AppColors.secondaryText,
                    size: 14,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    isGranted ? 'Granted' : 'Not yet granted',
                    style: AppTextStyles.labelSmall.copyWith(
                      color: isGranted
                          ? AppColors.success
                          : AppColors.secondaryText,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
