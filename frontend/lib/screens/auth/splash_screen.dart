import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_constants.dart';
import '../../core/routes/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/common/app_logo.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _navigate());
  }

  Future<void> _navigate() async {
    final auth = context.read<AuthProvider>();
    // Validate any saved session while the minimum splash time elapses.
    await Future.wait([auth.tryAutoLogin(), Future.delayed(const Duration(milliseconds: 1200))]);
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed(auth.isAuthenticated ? AppRoutes.home : AppRoutes.login);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 132,
              height: 132,
              alignment: Alignment.center,
              decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.lavender50),
              child: Container(
                width: 96,
                height: 96,
                alignment: Alignment.center,
                decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.lavender100),
                child: const AppLogo(size: 60),
              ),
            ),
            const SizedBox(height: 26),
            Text(AppConstants.appName, style: AppTextStyles.displayMd),
            const SizedBox(height: 6),
            Text(AppConstants.appTagline, style: AppTextStyles.bodyMd.copyWith(color: AppColors.textSecondary)),
            const SizedBox(height: 40),
            const SizedBox(
              width: 120,
              child: ClipRRect(
                borderRadius: BorderRadius.all(Radius.circular(8)),
                child: LinearProgressIndicator(minHeight: 4, color: AppColors.brand, backgroundColor: AppColors.lavender100),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
