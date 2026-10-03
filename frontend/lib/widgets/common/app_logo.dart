import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

/// Mark: a lavender tile holding three "text lines" (a document), the top
/// one in solid brand violet like a highlighted passage — i.e. "answers
/// pulled out of documents". Pure shapes, no image assets needed.
class AppLogo extends StatelessWidget {
  final double size;
  const AppLogo({super.key, this.size = 48});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.25),
      decoration: BoxDecoration(
        color: AppColors.lavender100,
        borderRadius: BorderRadius.circular(size * 0.32),
        border: Border.all(color: AppColors.lavender200),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _line(1.0, AppColors.brand),
          SizedBox(height: size * 0.075),
          _line(0.72, AppColors.lavender400),
          SizedBox(height: size * 0.075),
          _line(0.88, AppColors.lavender300),
        ],
      ),
    );
  }

  Widget _line(double factor, Color color) => FractionallySizedBox(
        widthFactor: factor,
        child: Container(
          height: size * 0.09,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(size)),
        ),
      );
}
