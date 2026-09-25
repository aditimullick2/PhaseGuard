import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'app_theme.dart';


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
//  AuthInput — full auth input with electric-blue focus glow
// ─────────────────────────────────────────────────────────────────────────────

class AuthInput extends StatefulWidget {
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
  State<AuthInput> createState() => _AuthInputState();
}

class _AuthInputState extends State<AuthInput> {
  late final FocusNode _focusNode;
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? FocusNode();
    _focusNode.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    setState(() => _isFocused = _focusNode.hasFocus);
  }

  @override
  void dispose() {
    // Only dispose if we created it (not passed in from outside)
    if (widget.focusNode == null) {
      _focusNode.removeListener(_onFocusChange);
      _focusNode.dispose();
    } else {
      _focusNode.removeListener(_onFocusChange);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Color borderColor = widget.isError
        ? AppColors.error
        : _isFocused
            ? const Color(0xFF2678FF)
            : const Color(0x14FFFFFF); // rgba(255,255,255,0.08) hairline

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Text(
            widget.label,
            style: AppTextStyles.labelMedium.copyWith(
              color: widget.isError
                  ? AppColors.error
                  : _isFocused
                      ? const Color(0xFF2678FF)
                      : AppColors.secondaryText,
            ),
          ),
        ),
        const SizedBox(height: 6),
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            color: const Color(0xFF101114), // dark charcoal surface
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor, width: _isFocused ? 1.5 : 1.0),
            boxShadow: _isFocused
                ? [
                    BoxShadow(
                      color: const Color(0xFF2678FF).withValues(alpha: 0.18),
                      blurRadius: 16,
                      spreadRadius: 0,
                    ),
                  ]
                : null,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (widget.icon != null) ...[widget.icon!, const SizedBox(width: 14)],
                Expanded(
                  child: TextFormField(
                    controller: widget.controller,
                    focusNode: _focusNode,
                    obscureText: widget.obscureText,
                    keyboardType: widget.keyboardType,
                    validator: widget.validator,
                    style: AppTextStyles.bodyMedium,
                    cursorColor: const Color(0xFF2678FF),
                    decoration: InputDecoration(
                      isDense: true,
                      filled: false,
                      fillColor: Colors.transparent,
                      hintText: widget.hint,
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
                if (widget.trailingWidget != null) ...[
                  const SizedBox(width: 8),
                  widget.trailingWidget!,
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}
