import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import 'question_type_badge.dart';

/// Visualizes the classifier -> pipeline routing step live, in-context.
/// This is the piece that makes the ML step visible to the user instead of
/// hiding it behind a single "thinking..." spinner.
class PipelineStatusIndicator extends StatelessWidget {
  final QuestionType? classification;

  const PipelineStatusIndicator({super.key, this.classification});

  @override
  Widget build(BuildContext context) {
    final classified = classification != null;
    return Padding(
      padding: const EdgeInsets.only(left: 38, bottom: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.lavender50,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.lavender100),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.brand.withValues(alpha: 0.5)),
            ),
            const SizedBox(width: 10),
            Text(
              classified ? 'Searching your documents' : 'Reading your documents…',
              style: AppTextStyles.bodySm.copyWith(color: AppColors.textSecondary),
            ),
            if (classified) ...[
              const SizedBox(width: 8),
              QuestionTypeBadge(type: classification!, compact: true),
            ],
          ],
        ),
      ),
    );
  }
}
