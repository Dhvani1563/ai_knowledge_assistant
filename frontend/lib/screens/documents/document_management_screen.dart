import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../providers/document_provider.dart';
import '../../widgets/common/empty_state.dart';
import '../../widgets/documents/document_card.dart';
import '../../widgets/documents/upload_dropzone.dart';

class DocumentManagementScreen extends StatefulWidget {
  const DocumentManagementScreen({super.key});

  @override
  State<DocumentManagementScreen> createState() => _DocumentManagementScreenState();
}

class _DocumentManagementScreenState extends State<DocumentManagementScreen> {
  String _query = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DocumentProvider>().fetchDocuments();
    });
  }

  Future<void> _pickAndUpload() async {
    try {
      // withData: true is required so `bytes` is populated on every
      // platform, including web, where there's no accessible file path.
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['pdf', 'docx', 'txt', 'md'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;
      final bytes = file.bytes;
      if (bytes == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not read the selected file.')),
        );
        return;
      }
      if (!mounted) return;
      final provider = context.read<DocumentProvider>();
      final ok = await provider.uploadDocument(name: file.name, bytes: bytes);
      if (!ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(provider.errorMessage ?? 'Upload failed.')));
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the file picker on this platform.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final docs = context.watch<DocumentProvider>().documents.where((d) {
      if (_query.isEmpty) return true;
      return d.name.toLowerCase().contains(_query.toLowerCase());
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Documents'),
        actions: [
          IconButton(onPressed: _pickAndUpload, icon: const Icon(Icons.add_rounded), tooltip: 'Upload document'),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Container(
              decoration: BoxDecoration(color: AppColors.surfaceAlt, borderRadius: BorderRadius.circular(12)),
              child: TextField(
                onChanged: (v) => setState(() => _query = v),
                style: AppTextStyles.bodyMd,
                decoration: const InputDecoration(
                  hintText: 'Search documents…',
                  prefixIcon: Icon(Icons.search_rounded, size: 20, color: AppColors.textMuted),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),
          Expanded(
            child: docs.isEmpty
                ? SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        UploadDropzone(onTap: _pickAndUpload),
                        const SizedBox(height: 24),
                        const EmptyState(
                          icon: Icons.folder_open_rounded,
                          title: 'No documents found',
                          message: 'Upload a PDF, resume, manual or research paper to start asking questions.',
                        ),
                      ],
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    children: [
                      UploadDropzone(onTap: _pickAndUpload),
                      const SizedBox(height: 16),
                      Text('${docs.length} document${docs.length == 1 ? '' : 's'}', style: AppTextStyles.label),
                      const SizedBox(height: 10),
                      ...docs.map((d) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: DocumentCard(
                              document: d,
                              onTap: () {},
                              onDelete: () => context.read<DocumentProvider>().deleteDocument(d.id),
                            ),
                          )),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
