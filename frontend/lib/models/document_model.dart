import '../core/constants/app_constants.dart';

class DocumentModel {
  final String id;
  final String name;
  final String fileType;
  final int sizeBytes;
  final DateTime uploadedAt;
  final DocumentStatus status;
  final int pageCount;
  final int chunkCount;
  final double processingProgress; // 0..1 — local-only estimate, see note below
  final String? category;
  final String? errorMessage;
  final String? stage; // e.g. "Creating embeddings (48 chunks)"

  const DocumentModel({
    required this.id,
    required this.name,
    required this.fileType,
    required this.sizeBytes,
    required this.uploadedAt,
    required this.status,
    this.pageCount = 0,
    this.chunkCount = 0,
    this.processingProgress = 0,
    this.category,
    this.errorMessage,
    this.stage,
  });

  String get sizeLabel {
    final kb = sizeBytes / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(0)} KB';
    return '${(kb / 1024).toStringAsFixed(1)} MB';
  }

  DocumentModel copyWith({
    DocumentStatus? status,
    double? processingProgress,
    int? pageCount,
    int? chunkCount,
  }) {
    return DocumentModel(
      id: id,
      name: name,
      fileType: fileType,
      sizeBytes: sizeBytes,
      uploadedAt: uploadedAt,
      status: status ?? this.status,
      pageCount: pageCount ?? this.pageCount,
      chunkCount: chunkCount ?? this.chunkCount,
      processingProgress: processingProgress ?? this.processingProgress,
      category: category,
      errorMessage: errorMessage,
      stage: stage,
    );
  }

  // The backend doesn't stream a 0..1 progress number today (see README
  // "Known limitations" — it's a plain BackgroundTask, not a queue with
  // progress events), so this fills a reasonable value from status alone.
  // Add a `progress` field to the FastAPI response later for a real bar.
  factory DocumentModel.fromJson(Map<String, dynamic> json) {
    final status = DocumentStatus.values.firstWhere(
      (e) => e.name == json['status'],
      orElse: () => DocumentStatus.processing,
    );
    return DocumentModel(
      id: json['id'].toString(),
      name: json['name'] as String,
      fileType: json['file_type'] as String,
      sizeBytes: json['size_bytes'] as int? ?? 0,
      uploadedAt: DateTime.parse(json['uploaded_at'] as String),
      status: status,
      pageCount: json['page_count'] as int? ?? 0,
      chunkCount: json['chunk_count'] as int? ?? 0,
      processingProgress: status == DocumentStatus.ready ? 1.0 : 0.55,
      category: json['category'] as String?,
      errorMessage: json['error_message'] as String?,
      stage: json['stage'] as String?,
    );
  }
}
