import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/providers.dart';
import '../components/app_theme.dart';
import '../components/app_button.dart';
import '../components/app_text_field.dart';
import '../components/animated_gif_background.dart';
import '../components/animated_gradient_bg.dart';
import '../components/connect_call_logo.dart';
import 'signup_screen.dart';
import 'home_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await ref.read(authServiceProvider).signIn(
            email: _emailCtrl.text,
            password: _passwordCtrl.text,
          );

      // Update FCM token after login
      final token =
          await ref.read(notificationServiceProvider).getFcmToken();
      if (token != null) {
        final userAsync =
            await ref.read(currentUserModelProvider.future);
        if (userAsync != null) {
          await ref
              .read(userServiceProvider)
              .updateFcmToken(userAsync.uid, token);
        }
      }

      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await ref.read(authServiceProvider).signInWithGoogle();

      // Update FCM token after login
      final token =
          await ref.read(notificationServiceProvider).getFcmToken();
      if (token != null) {
        final userAsync =
            await ref.read(currentUserModelProvider.future);
        if (userAsync != null) {
          await ref
              .read(userServiceProvider)
              .updateFcmToken(userAsync.uid, token);
        }
      }

      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryBackground,
      extendBody: true,
      extendBodyBehindAppBar: true,
      body: SizedBox.expand(
        child: Stack(
        children: [
          // Animated GIF Background
          const Positioned.fill(
            child: AnimatedGifBackground(
              assetPath: 'assets/background/login_bg.gif',
              overlayOpacity: 0.55,
              child: SizedBox.shrink(),
            ),
          ),
          
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 48),
                    // Floating Logo / Icon (Center Aligned)
                    const Center(
                      child: PhaseGuardLogo(
                        size: 80, 
                        showGlow: true,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Title
                    Text(
                      'Welcome back',
                      style: AppTextStyles.titleLarge.copyWith(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    
                    // Subtitle
                    Text(
                      'Connect with anyone, anywhere.',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.secondaryText,
                        fontSize: 15,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 40),

                    // Email Auth Input
                    AuthInput(
                      label: 'Email Address',
                      hint: 'alex@example.com',
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      icon: const Icon(Icons.email_outlined,
                          color: AppColors.primary, size: 22),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Enter your email';
                        }
                        if (!v.contains('@')) return 'Invalid email address';
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),

                    // Password Auth Input
                    AuthInput(
                      label: 'Password',
                      hint: '••••••••',
                      controller: _passwordCtrl,
                      obscureText: _obscurePassword,
                      icon: const Icon(Icons.lock_outline_rounded,
                          color: AppColors.primary, size: 22),
                      trailingWidget: GestureDetector(
                        onTap: () => setState(
                            () => _obscurePassword = !_obscurePassword),
                        child: Icon(
                          _obscurePassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: AppColors.secondaryText,
                          size: 20,
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Enter your password';
                        if (v.length < 6) {
                          return 'Password must be at least 6 characters';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    
                    // Forgot Password
                    Align(
                      alignment: Alignment.centerRight,
                      child: GestureDetector(
                        onTap: () async {
                          if (_emailCtrl.text.isEmpty) {
                            setState(() {
                              _error = 'Enter your email first to reset password.';
                            });
                            return;
                          }
                          try {
                            await ref.read(authServiceProvider).resetPassword(_emailCtrl.text);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Password reset email sent!')),
                              );
                            }
                          } catch (e) {
                            setState(() {
                              _error = e.toString().replaceFirst('Exception: ', '');
                            });
                          }
                        },
                        child: Text(
                          'Forgot Password?',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Error message
                    if (_error != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: AppColors.error.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline,
                                color: AppColors.error, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _error!,
                                style: const TextStyle(
                                    color: AppColors.error, fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // Sign In Button
                    AppButton(
                      content: 'Sign In',
                      fullWidth: true,
                      size: 'large',
                      loading: _isLoading,
                      onTap: _signIn,
                    ),
                    const SizedBox(height: 32),

                    // Divider
                    Row(
                      children: [
                        Expanded(child: Divider(color: AppColors.secondaryText.withValues(alpha: 0.3))),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            'or continue with',
                            style: AppTextStyles.labelSmall.copyWith(
                              color: AppColors.secondaryText,
                            ),
                          ),
                        ),
                        Expanded(child: Divider(color: AppColors.secondaryText.withValues(alpha: 0.3))),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Social Buttons
                    Row(
                      children: [
                        Expanded(
                          child: _SocialButton(
                            icon: Icons.g_mobiledata,
                            label: 'Google',
                            onTap: _isLoading ? () {} : _signInWithGoogle,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _SocialButton(
                            icon: Icons.apple,
                            label: 'Apple',
                            onTap: _isLoading ? () {} : () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Apple Sign-In is coming soon!')),
                                );
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 48),

                    // Sign up link
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Don't have an account?",
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.secondaryText,
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const SignupScreen()),
                            );
                          },
                          child: Text(
                            'Create Account',
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
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

class _SocialButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _SocialButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: GlassmorphicContainer(
        padding: const EdgeInsets.symmetric(vertical: 14),
        borderRadius: BorderRadius.circular(12),
        color: Colors.white.withValues(alpha: 0.1),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 24),
            const SizedBox(width: 8),
            Text(
              label,
              style: AppTextStyles.labelMedium.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
