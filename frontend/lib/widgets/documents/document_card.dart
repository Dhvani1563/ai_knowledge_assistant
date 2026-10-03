import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../models/document_model.dart';

class DocumentCard extends StatelessWidget {
  final DocumentModel document;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  const DocumentCard({super.key, required this.document, this.onTap, this.onDelete});

  Color get _typeColor {
    switch (document.fileType) {
      case 'pdf':
        return const Color(0xFFC24545);
      case 'docx':
        return const Color(0xFF3F7EA8);
      default:
        return AppColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isProcessing = document.status == DocumentStatus.processing || document.status == DocumentStatus.uploading;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(color: _typeColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                  child: Icon(Icons.description_rounded, color: _typeColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        document.name,
                        style: AppTextStyles.bodyMd.copyWith(fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${document.category ?? document.fileType.toUpperCase()} · ${document.sizeLabel}',
                        style: AppTextStyles.caption,
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert_rounded, color: AppColors.textMuted, size: 20),
                  onSelected: (v) {
                    if (v == 'delete') onDelete?.call();
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'view', child: Text('View details')),
                    const PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (isProcessing) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: document.processingProgress,
                  minHeight: 5,
                  backgroundColor: AppColors.surfaceAlt,
                  valueColor: const AlwaysStoppedAnimation(AppColors.lavender400),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                document.stage ?? (document.status == DocumentStatus.uploading ? 'Uploading…' : 'Processing…'),
                style: AppTextStyles.caption.copyWith(color: AppColors.brandDeep),
              ),
            ] else if (document.status == DocumentStatus.failed) ...[
              Row(
                children: [
                  const Icon(Icons.error_outline_rounded, size: 14, color: AppColors.error),
                  const SizedBox(width: 6),
                  Flexible(child: Text(document.errorMessage ?? 'Processing failed', maxLines: 2, overflow: TextOverflow.ellipsis, style: AppTextStyles.caption.copyWith(color: AppColors.error))),
                ],
              ),
            ] else ...[
              Row(
                children: [
                  _statPill(Icons.layers_outlined, '${document.chunkCount} chunks'),
                  const SizedBox(width: 8),
                  _statPill(Icons.description_outlined, '${document.pageCount} pages'),
                  const Spacer(),
                  Text(DateFormat('MMM d').format(document.uploadedAt), style: AppTextStyles.caption),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _statPill(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: AppColors.textMuted),
        const SizedBox(width: 4),
        Text(label, style: AppTextStyles.caption),
      ],
    );
  }
}
