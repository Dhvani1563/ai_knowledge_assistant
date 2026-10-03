import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

enum ButtonVariant { primary, outlined, text }

class CustomButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final ButtonVariant variant;
  final IconData? icon;
  final double? width;

  const CustomButton({
    super.key,
    required this.label,
    this.onPressed,
    this.isLoading = false,
    this.variant = ButtonVariant.primary,
    this.icon,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    final child = isLoading
        ? SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2.4,
              valueColor: AlwaysStoppedAnimation<Color>(
                variant == ButtonVariant.primary ? Colors.white : AppColors.brand,
              ),
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[Icon(icon, size: 18), const SizedBox(width: 8)],
              Text(label),
            ],
          );

    final button = switch (variant) {
      ButtonVariant.primary => ElevatedButton(onPressed: isLoading ? null : onPressed, child: child),
      ButtonVariant.outlined => OutlinedButton(onPressed: isLoading ? null : onPressed, child: child),
      ButtonVariant.text => TextButton(onPressed: isLoading ? null : onPressed, child: child),
    };

    return SizedBox(width: width ?? double.infinity, child: button);
  }
}
