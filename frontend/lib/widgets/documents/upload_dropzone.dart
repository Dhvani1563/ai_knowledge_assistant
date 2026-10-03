import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

class UploadDropzone extends StatelessWidget {
  final VoidCallback onTap;
  const UploadDropzone({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: DottedBorder(
        color: AppColors.lavender300,
        strokeWidth: 1.5,
        dashPattern: const [7, 5],
        borderType: BorderType.RRect,
        radius: const Radius.circular(20),
        padding: EdgeInsets.zero,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 20),
          decoration: BoxDecoration(color: AppColors.lavender50, borderRadius: BorderRadius.circular(20)),
          child: Column(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: const BoxDecoration(color: AppColors.lavender100, shape: BoxShape.circle),
                child: const Icon(Icons.cloud_upload_outlined, color: AppColors.brand, size: 26),
              ),
              const SizedBox(height: 12),
              Text('Upload a document', style: AppTextStyles.h3),
              const SizedBox(height: 4),
              Text('PDF, DOCX, TXT or MD · up to ${AppConstants.maxFileSizeMb} MB', style: AppTextStyles.bodySm, textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}
