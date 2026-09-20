import 'package:flutter/material.dart';
import 'app_theme.dart';


//  AppButton 

class AppButton extends StatefulWidget {
  final String content;
  final String variant;
  final String size;
  final bool fullWidth;
  final bool loading;
  final bool disabled;
  final Widget? icon;
  final Widget? iconEnd;
  final VoidCallback? onTap;

  const AppButton({
    super.key,
    this.content = 'Get Started',
    this.variant = 'primary',
    this.size = 'medium',
    this.fullWidth = false,
    this.loading = false,
    this.disabled = false,
    this.icon,
    this.iconEnd,
    this.onTap,
  });

  @override
  State<AppButton> createState() => _AppButtonState();
}

class _AppButtonState extends State<AppButton> {
  bool _isPressed = false;

  Color get _bgColor {
    if (widget.disabled) {
      return switch (widget.variant) {
        'secondary' => AppColors.secondary.withValues(alpha: 0.55),
        'destructive' => AppColors.error.withValues(alpha: 0.55),
        'outline' || 'ghost' => Colors.transparent,
        _ => AppColors.primary.withValues(alpha: 0.55),
      };
    }
    return switch (widget.variant) {
      'secondary' => AppColors.secondary,
      'outline' || 'ghost' => Colors.transparent,
      'destructive' => AppColors.error,
      _ => AppColors.primary,
    };
  }

  Color get _textColor => switch (widget.variant) {
        'secondary' => AppColors.onSecondary,
        'outline' => AppColors.primaryText,
        'ghost' => AppColors.primary,
        'destructive' => AppColors.onError,
        _ => AppColors.onPrimary,
      };

  Color get _borderColor =>
      widget.variant == 'outline' ? AppColors.alternate : Colors.transparent;

  double get _radius => switch (widget.size) {
        'small' => 8.0,
        'large' => 20.0,
        _ => 12.0,
      };

  EdgeInsets get _padding => switch (widget.size) {
        'small' => const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        'large' => const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        _ => const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      };

  double get _fontSize => switch (widget.size) {
        'small' => 13.0,
        'large' => 16.0,
        _ => 14.0,
      };

  @override
  Widget build(BuildContext context) {
    final button = GestureDetector(
      onTapDown: (_) {
        if (!widget.disabled && !widget.loading) {
          setState(() => _isPressed = true);
        }
      },
      onTapUp: (_) {
        if (!widget.disabled && !widget.loading) {
          setState(() => _isPressed = false);
          widget.onTap?.call();
        }
      },
      onTapCancel: () {
        if (_isPressed) {
          setState(() => _isPressed = false);
        }
      },
      child: AnimatedScale(
        scale: _isPressed ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
        child: AnimatedOpacity(
          opacity: widget.disabled ? 0.55 : 1.0,
          duration: const Duration(milliseconds: 200),
          child: Container(
            decoration: BoxDecoration(
              color: _bgColor,
              borderRadius: BorderRadius.circular(_radius),
              border: Border.all(color: _borderColor, width: 1),
              boxShadow: widget.variant == 'primary' && !widget.disabled
                  ? [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      )
                    ]
                  : null,
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                AnimatedOpacity(
                  opacity: widget.loading ? 0.0 : 1.0,
                  duration: const Duration(milliseconds: 150),
                  child: Padding(
                    padding: _padding,
                    child: Row(
                      mainAxisSize:
                          widget.fullWidth ? MainAxisSize.max : MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        if (widget.icon != null) ...[widget.icon!, const SizedBox(width: 8)],
                        Flexible(
                          child: Text(
                            widget.content,
                            maxLines: 1,
                            overflow: TextOverflow.clip,
                            style: TextStyle(
                              fontSize: _fontSize,
                              fontWeight: FontWeight.w600,
                              color: _textColor,
                              letterSpacing: 0.3,
                              height: 1.3,
                            ),
                          ),
                        ),
                        if (widget.iconEnd != null) ...[
                          const SizedBox(width: 8),
                          widget.iconEnd!
                        ],
                      ],
                    ),
                  ),
                ),
                if (widget.loading)
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: _textColor,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );

    return widget.fullWidth ? SizedBox(width: double.infinity, child: button) : button;
  }
}
