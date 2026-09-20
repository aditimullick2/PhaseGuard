import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'app_theme.dart';
import 'animated_gradient_bg.dart';


//  AppTextField 

class AppTextField extends StatelessWidget {
  final String? label;
  final String? helper;
  final String? hint;
  final String variant;
  final bool error;
  final Widget? leadingIcon;
  final Widget? trailingIcon;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final bool obscureText;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;

  const AppTextField({
    super.key,
    this.label,
    this.helper,
    this.hint,
    this.variant = 'outline',
    this.error = false,
    this.leadingIcon,
    this.trailingIcon,
    this.controller,
    this.focusNode,
    this.obscureText = false,
    this.keyboardType,
    this.validator,
    this.onChanged,
  });

  Color get _bg => switch (variant) {
        'filled' => AppColors.secondaryBackground,
        _ => Colors.transparent,
      };

  Color get _borderColor {
    if (error) return AppColors.error;
    return switch (variant) {
      'filled' => Colors.transparent,
      'ghost' => Colors.transparent,
      _ => AppColors.alternate,
    };
  }

  double get _borderWidth => switch (variant) {
        'ghost' => 0.0,
        _ => error ? 1.5 : 1.0,
      };

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (label != null && label!.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text(
              label!,
              style: AppTextStyles.labelMedium.copyWith(
                color: error ? AppColors.error : AppColors.secondaryText,
              ),
            ),
          ),
          const SizedBox(height: 4),
        ],
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.large),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              height: 52,
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.white.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(AppRadius.large),
                border: Border.all(color: _borderColor, width: _borderWidth),
              ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (leadingIcon != null) ...[
                  leadingIcon!,
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: TextFormField(
                    controller: controller,
                    focusNode: focusNode,
                    obscureText: obscureText,
                    keyboardType: keyboardType,
                    onChanged: onChanged,
                    style: AppTextStyles.bodyMedium,
                    validator: validator,
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
                      errorBorder: InputBorder.none,
                      focusedErrorBorder: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
                if (trailingIcon != null) ...[
                  const SizedBox(width: 8),
                  trailingIcon!,
                ],
              ],
            ),
          ),
        ),
      ),
    ),
    if (helper != null && helper!.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            helper!,
            style: AppTextStyles.bodySmall.copyWith(
              color: error ? AppColors.error : AppColors.secondaryText,
            ),
          ),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  AuthInput — full auth input with rounded border (matches AuthInputWidget)
// ─────────────────────────────────────────────────────────────────────────────

class AuthInput extends StatelessWidget {
  final String label;
  final String hint;
  final Widget? icon;
  final bool isError;
  final bool obscureText;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final Widget? trailingWidget;

  const AuthInput({
    super.key,
    required this.label,
    this.hint = '',
    this.icon,
    this.isError = false,
    this.obscureText = false,
    this.controller,
    this.focusNode,
    this.keyboardType,
    this.validator,
    this.trailingWidget,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Text(
            label,
            style: AppTextStyles.labelMedium.copyWith(
              color: isError ? AppColors.error : AppColors.secondaryText,
            ),
          ),
        ),
        const SizedBox(height: 4),
        GlassmorphicContainer(
          borderRadius: BorderRadius.circular(12),
          padding: EdgeInsets.zero,
          color: Colors.white.withValues(alpha: 0.1),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (icon != null) ...[icon!, const SizedBox(width: 14)],
                Expanded(
                  child: TextFormField(
                    controller: controller,
                    focusNode: focusNode,
                    obscureText: obscureText,
                    keyboardType: keyboardType,
                    validator: validator,
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
                      errorBorder: InputBorder.none,
                      focusedErrorBorder: InputBorder.none,
                      contentPadding:
                          const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                if (trailingWidget != null) ...[
                  const SizedBox(width: 8),
                  trailingWidget!,
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}
