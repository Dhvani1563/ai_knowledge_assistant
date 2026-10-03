import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../models/user_model.dart';

/// Profile photo from Google/Facebook when available, initials otherwise.
class UserAvatar extends StatelessWidget {
  final UserModel? user;
  final double radius;
  const UserAvatar({super.key, required this.user, this.radius = 22});

  @override
  Widget build(BuildContext context) {
    final url = user?.avatarUrl;
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.lavender100,
      backgroundImage: url != null ? NetworkImage(url) : null,
      onBackgroundImageError: url != null ? (_, __) {} : null,
      child: url == null
          ? Text(user?.initials ?? '?', style: AppTextStyles.h3.copyWith(color: AppColors.brandDeep, fontSize: radius * 0.7))
          : null,
    );
  }
}
