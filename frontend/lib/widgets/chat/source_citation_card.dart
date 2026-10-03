import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../models/source_reference_model.dart';

/// Evidence card. The numbered dot matches the [1], [2] markers the model
/// writes in its answer, so users can trace any claim to its passage.
class SourceCitationCard extends StatelessWidget {
  final SourceReferenceModel source;
  final int index;
  final VoidCallback? onTap;

  const SourceCitationCard({super.key, required this.source, required this.index, this.onTap});

  @override
  Widget build(BuildContext context) {
    final pct = (source.relevanceScore.clamp(0, 1) * 100).round();
    return InkWell(
      onTap: onTap ?? () => _showDetail(context),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 232,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.lavender200)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                width: 20,
                height: 20,
                alignment: Alignment.center,
                decoration: const BoxDecoration(color: AppColors.brand, shape: BoxShape.circle),
                child: Text('$index', style: AppTextStyles.caption.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(source.documentName, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTextStyles.bodySm.copyWith(fontWeight: FontWeight.w700, color: AppColors.textPrimary))),
            ]),
            const SizedBox(height: 8),
            Expanded(child: Text(source.excerpt, maxLines: 3, overflow: TextOverflow.ellipsis, style: AppTextStyles.bodySm)),
            const SizedBox(height: 6),
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: AppColors.lavender100, borderRadius: BorderRadius.circular(20)),
                child: Text('Page ${source.pageNumber}', style: AppTextStyles.caption.copyWith(color: AppColors.brandDeep, fontWeight: FontWeight.w600)),
              ),
              const Spacer(),
              Text('$pct% match', style: AppTextStyles.caption),
            ]),
          ],
        ),
      ),
    );
  }

  void _showDetail(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(22, 4, 22, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(source.documentName, style: AppTextStyles.h2),
            const SizedBox(height: 4),
            Text('Page ${source.pageNumber} · ${(source.relevanceScore * 100).round()}% match', style: AppTextStyles.bodySm),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: AppColors.lavender50, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.lavender100)),
              child: Text(source.excerpt, style: AppTextStyles.bodyMd.copyWith(height: 1.6)),
            ),
          ],
        ),
      ),
    );
  }
}
