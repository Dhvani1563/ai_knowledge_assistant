import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

class QuestionTypeBadge extends StatelessWidget {
  final QuestionType type;
  final bool compact;

  const QuestionTypeBadge({super.key, required this.type, this.compact = false});

  Color get _color {
    switch (type) {
      case QuestionType.factual:
        return AppColors.tagFactual;
      case QuestionType.summarization:
        return AppColors.tagSummarization;
      case QuestionType.comparison:
        return AppColors.tagComparison;
      case QuestionType.retrieval:
        return AppColors.tagRetrieval;
    }
  }

  IconData get _icon {
    switch (type) {
      case QuestionType.factual:
        return Icons.check_circle_outline;
      case QuestionType.summarization:
        return Icons.short_text_rounded;
      case QuestionType.comparison:
        return Icons.compare_arrows_rounded;
      case QuestionType.retrieval:
        return Icons.manage_search_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: type.description,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 10, vertical: compact ? 3 : 5),
        decoration: BoxDecoration(
          color: _color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _color.withValues(alpha: 0.28)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_icon, size: compact ? 12 : 14, color: _color),
            const SizedBox(width: 5),
            Text(
              type.label,
              style: AppTextStyles.caption.copyWith(color: _color, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}
