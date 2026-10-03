import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

class SuggestedPrompts extends StatelessWidget {
  final void Function(String prompt) onTap;

  const SuggestedPrompts({super.key, required this.onTap});

  static const _prompts = [
    ('What are the eligibility requirements?', Icons.fact_check_outlined),
    ('Summarize this document in 5 bullet points', Icons.short_text_rounded),
    ('Compare the two policies mentioned', Icons.compare_arrows_rounded),
    ('Find every mention of "deadline"', Icons.manage_search_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _prompts.map((p) {
        return InkWell(
          onTap: () => onTap(p.$1),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            constraints: const BoxConstraints(maxWidth: 260),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(p.$2, size: 16, color: AppColors.brand),
                const SizedBox(width: 8),
                Flexible(child: Text(p.$1, style: AppTextStyles.bodySm.copyWith(color: AppColors.textPrimary))),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
