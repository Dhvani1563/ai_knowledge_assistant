import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

/// Shared frame for login / signup: white page with a soft lavender
/// "glow" top-right and a smaller one bottom-left — depth without noise.
class AuthScaffold extends StatelessWidget {
  final Widget child;
  const AuthScaffold({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          Positioned(
            top: -110,
            right: -90,
            child: Container(
              width: 280,
              height: 280,
              decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.lavender100),
            ),
          ),
          Positioned(
            top: 10,
            right: 40,
            child: Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.lavender200),
            ),
          ),
          Positioned(
            bottom: -80,
            left: -70,
            child: Container(
              width: 190,
              height: 190,
              decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.lavender50),
            ),
          ),
          SafeArea(child: child),
        ],
      ),
    );
  }
}
