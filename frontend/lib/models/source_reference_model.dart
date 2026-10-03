class SourceReferenceModel {
  final String documentId;
  final String documentName;
  final int pageNumber;
  final String excerpt;
  final double relevanceScore; // 0..1, from vector similarity

  const SourceReferenceModel({
    required this.documentId,
    required this.documentName,
    required this.pageNumber,
    required this.excerpt,
    required this.relevanceScore,
  });

  factory SourceReferenceModel.fromJson(Map<String, dynamic> json) => SourceReferenceModel(
        documentId: json['document_id'].toString(),
        documentName: json['document_name'] as String,
        pageNumber: json['page_number'] as int? ?? 1,
        excerpt: json['excerpt'] as String? ?? '',
        relevanceScore: (json['relevance_score'] as num?)?.toDouble() ?? 0.0,
      );
}
