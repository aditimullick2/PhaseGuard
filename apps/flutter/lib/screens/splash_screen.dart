import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/providers.dart';
import '../components/animated_gif_background.dart';
import '../components/connect_call_logo.dart';
import 'login_screen.dart';
import 'home_screen.dart';

class SplashScreen extends ConsumerWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(currentUserProvider);

    // React to auth state changes
    ref.listen(currentUserProvider, (previous, next) {
      next.whenData((user) {
        Navigator.of(context).pushAndRemoveUntil(
          PageRouteBuilder(
            pageBuilder: (_, __, ___) =>
                user != null ? const HomeScreen() : const LoginScreen(),
            transitionsBuilder: (_, animation, __, child) =>
                FadeTransition(opacity: animation, child: child),
            transitionDuration: const Duration(milliseconds: 600),
          ),
          (route) => false,
        );
      });
    });

    return Scaffold(
      backgroundColor: const Color(0xFF0F0E1A),
      body: AnimatedGifBackground(
        assetPath: 'assets/background/splash_bg.gif',
        overlayOpacity: 0.3,
        child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // App icon with scale+fade entrance
                TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0.0, end: 1.0),
                  duration: const Duration(milliseconds: 800),
                  curve: Curves.easeOutBack,
                  builder: (context, value, child) {
                    return Transform.scale(
                      scale: value,
                      child: Opacity(opacity: value.clamp(0.0, 1.0), child: child),
                    );
                  },
                  child: const PhaseGuardLogo(
                    size: 120,
                    showGlow: true,
                  ),
                ),
                const SizedBox(height: 32),

                const Text(
                  'Crystal-clear calls, always.',
                  style: TextStyle(
                    color: Color(0xFF9A97C5),
                    fontSize: 15,
                    letterSpacing: 0.3,
                  ),
                ),

                const SizedBox(height: 64),

                // Loading indicator or error
                authState.when(
                  data: (_) => const _ThreeDotLoader(),
                  loading: () => const _ThreeDotLoader(),
                  error: (error, _) => Flexible(
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.error_outline,
                              color: Colors.redAccent, size: 36),
                          const SizedBox(height: 12),
                          Text(
                            '$error',
                            style: const TextStyle(
                                color: Color(0xFF9A97C5), fontSize: 13),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
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

/// Three-dot breathing animation
class _ThreeDotLoader extends StatefulWidget {
  const _ThreeDotLoader();

  @override
  State<_ThreeDotLoader> createState() => _ThreeDotLoaderState();
}

class _ThreeDotLoaderState extends State<_ThreeDotLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Widget _buildDot(int index) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        // Offset phases slightly
        final phase = (_ctrl.value - (index * 0.2)).clamp(0.0, 1.0);
        final opacity = 0.3 + (0.7 * phase);
        final scale = 0.8 + (0.2 * phase);

        return Transform.scale(
          scale: scale,
          child: Opacity(
            opacity: opacity,
            child: Container(
              width: 10,
              height: 10,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: const BoxDecoration(
                color: Color(0xFF6C63FF),
                shape: BoxShape.circle,
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (index) => _buildDot(index)),
    );
  }
}
