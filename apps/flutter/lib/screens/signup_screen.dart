import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/providers.dart';
import '../components/app_theme.dart';
import '../components/app_button.dart';
import '../components/app_text_field.dart';
import '../components/animated_gradient_bg.dart';

import 'home_screen.dart';

class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await ref.read(authServiceProvider).signUp(
            email: _emailCtrl.text,
            password: _passwordCtrl.text,
            name: _nameCtrl.text,
          );

      // Update FCM token after sign up
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryBackground,
      extendBody: true,
      extendBodyBehindAppBar: true,
      body: SizedBox.expand(
        child: Stack(
        children: [
          // Pure-black gradient background — same as Home/Call screens
          const Positioned.fill(
            child: AnimatedGradientBg(preset: GradientPreset.subtle),
          ),

          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 24),

                    // Back button / Top bar
                    Align(
                      alignment: Alignment.centerLeft,
                      child: GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: GlassmorphicContainer(
                          padding: const EdgeInsets.all(8),
                          borderRadius: BorderRadius.circular(12),
                          color: Colors.white.withValues(alpha: 0.1),
                          child: const Icon(Icons.arrow_back_rounded,
                              color: AppColors.primaryText),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    Text(
                      'Create Account',
                      style: AppTextStyles.titleLarge,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Join PhaseGuard to get started',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.secondaryText,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 48),

                    // Name Input
                    AuthInput(
                      label: 'Full Name',
                      hint: 'Alex Rivera',
                      controller: _nameCtrl,
                      icon: const Icon(Icons.person_outline_rounded,
                          color: AppColors.secondaryText, size: 22),
                      validator: (v) => v == null || v.trim().isEmpty
                          ? 'Enter your name'
                          : null,
                    ),
                    const SizedBox(height: 20),

                    // Email Input
                    AuthInput(
                      label: 'Email',
                      hint: 'you@example.com',
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      icon: const Icon(Icons.email_outlined,
                          color: AppColors.secondaryText, size: 22),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Enter your email';
                        }
                        if (!v.contains('@')) return 'Invalid email address';
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),

                    // Password Input
                    AuthInput(
                      label: 'Password',
                      hint: '••••••••',
                      controller: _passwordCtrl,
                      obscureText: _obscurePassword,
                      icon: const Icon(Icons.lock_outline_rounded,
                          color: AppColors.secondaryText, size: 22),
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
                    const SizedBox(height: 28),

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

                    AppButton(
                      content: 'Sign Up',
                      fullWidth: true,
                      size: 'large',
                      loading: _isLoading,
                      onTap: _signUp,
                    ),
                    const SizedBox(height: 24),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "Already have an account? ",
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.secondaryText,
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            Navigator.pop(context);
                          },
                          child: Text(
                            'Sign In',
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
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
