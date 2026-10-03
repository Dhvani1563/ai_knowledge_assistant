import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

enum SocialProvider { google, facebook }

/// Full-width, white "Continue with …" button. Stacked full-width buttons
/// are easier to hit with a thumb than two half-width ones.
class SocialButton extends StatelessWidget {
  final SocialProvider provider;
  final VoidCallback? onPressed;
  final bool disabled;

  const SocialButton({super.key, required this.provider, required this.onPressed, this.disabled = false});

  @override
  Widget build(BuildContext context) {
    final isGoogle = provider == SocialProvider.google;
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: disabled ? null : onPressed,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            isGoogle
                ? Container(
                    width: 22,
                    height: 22,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
                    child: Text('G', style: AppTextStyles.h2.copyWith(color: AppColors.google, fontWeight: FontWeight.w800, height: 1)),
                  )
                : const Icon(Icons.facebook_rounded, color: AppColors.facebook, size: 24),
            const SizedBox(width: 12),
            Text(isGoogle ? 'Continue with Google' : 'Continue with Facebook', style: AppTextStyles.button.copyWith(color: AppColors.textPrimary)),
          ],
        ),
      ),
    );
  }
}
