import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../models/document_model.dart';
import 'share_sheet.dart';

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
                      if (!document.isOwner || document.flaggedChunks > 0) ...[
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            if (!document.isOwner)
                              _badge(Icons.people_outline_rounded, 'Shared by ${document.sharedBy ?? 'someone'}', AppColors.brandDeep, AppColors.lavender100),
                            if (document.flaggedChunks > 0)
                              _badge(Icons.shield_outlined, '${document.flaggedChunks} passages quarantined', AppColors.tagComparison, const Color(0xFFFFF1DE)),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert_rounded, color: AppColors.textMuted, size: 20),
                  onSelected: (v) {
                    if (v == 'details') _showDetails(context);
                    if (v == 'share') ShareSheet.show(context, document);
                    if (v == 'delete') onDelete?.call();
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'details', child: Text('View details')),
                    // Only the owner sees these. The server enforces the same rule,
                    // so hiding them is convenience, not the security boundary.
                    if (document.isOwner) const PopupMenuItem(value: 'share', child: Text('Share access')),
                    if (document.isOwner) const PopupMenuItem(value: 'delete', child: Text('Delete')),
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

  Widget _badge(IconData icon, String label, Color fg, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: fg),
          const SizedBox(width: 4),
          Text(label, style: AppTextStyles.caption.copyWith(color: fg, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  void _showDetails(BuildContext context) {
    Widget row(IconData icon, String title, String value) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 18, color: AppColors.brand),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppTextStyles.label),
                    const SizedBox(height: 2),
                    Text(value, style: AppTextStyles.bodyMd),
                  ],
                ),
              ),
            ],
          ),
        );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(22, 4, 22, 28),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(document.name, style: AppTextStyles.h2),
              const SizedBox(height: 10),
              row(Icons.description_outlined, 'File', '${document.fileType.toUpperCase()} · ${document.sizeLabel} · uploaded ${DateFormat('MMM d, y').format(document.uploadedAt)}'),
              row(Icons.layers_outlined, 'Searchable content', '${document.pageCount} pages · ${document.chunkCount} passages'),
              row(
                Icons.lock_outline_rounded,
                'Your access',
                document.isOwner ? 'You own this document. Only you decide who else can use it.' : 'Shared with you by ${document.sharedBy ?? 'its owner'}. You can ask questions about it but not delete or share it.',
              ),
              row(
                Icons.enhanced_encryption_outlined,
                'Stored file',
                document.isEncrypted ? 'Encrypted on the server\'s disk.' : 'Not encrypted on disk (the server has no encryption key set).',
              ),
              row(
                Icons.shield_outlined,
                'Safety scan',
                document.flaggedChunks == 0
                    ? 'No hidden instructions found.'
                    : '${document.flaggedChunks} passages looked like instructions aimed at an AI, so they are excluded from answers.',
              ),
            ],
          ),
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
