import '../core/constants/app_constants.dart';
import 'source_reference_model.dart';

class ChatMessageModel {
  final String id;
  final MessageSender sender;
  final String text;
  final DateTime timestamp;
  final QuestionType? questionType; // set on assistant replies
  final List<SourceReferenceModel> sources;
  final bool isStreaming;

  const ChatMessageModel({
    required this.id,
    required this.sender,
    required this.text,
    required this.timestamp,
    this.questionType,
    this.sources = const [],
    this.isStreaming = false,
  });

  ChatMessageModel copyWith({String? text, bool? isStreaming}) => ChatMessageModel(
        id: id,
        sender: sender,
        text: text ?? this.text,
        timestamp: timestamp,
        questionType: questionType,
        sources: sources,
        isStreaming: isStreaming ?? this.isStreaming,
      );

  factory ChatMessageModel.fromJson(Map<String, dynamic> json) => ChatMessageModel(
        id: json['id'].toString(),
        sender: json['sender'] == 'user' ? MessageSender.user : MessageSender.assistant,
        text: json['text'] as String? ?? '',
        timestamp: DateTime.parse(json['created_at'] as String),
        questionType: json['question_type'] != null
            ? QuestionType.values.firstWhere(
                (e) => e.name == json['question_type'],
                orElse: () => QuestionType.factual,
              )
            : null,
        sources: (json['sources'] as List? ?? [])
            .map((s) => SourceReferenceModel.fromJson(s as Map<String, dynamic>))
            .toList(),
      );
}

class ChatSessionModel {
  final String id;
  final String title;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<ChatMessageModel> messages;
  final List<String> documentIds; // documents scoped to this session
  final String? previewText; // used when this came from the lightweight /chat/sessions list

  const ChatSessionModel({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    this.messages = const [],
    this.documentIds = const [],
    this.previewText,
  });

  String get lastMessagePreview {
    if (previewText != null) return previewText!;
    if (messages.isEmpty) return 'No messages yet';
    final last = messages.last;
    return last.text.length > 64 ? '${last.text.substring(0, 64)}…' : last.text;
  }

  ChatSessionModel copyWithMessages(List<ChatMessageModel> messages) {
    return ChatSessionModel(
      id: id,
      title: title,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      messages: messages,
      documentIds: documentIds,
      previewText: null,
    );
  }

  /// Full conversation, from GET /chat/sessions/{id} or the `session` field
  /// of POST /chat/message.
  factory ChatSessionModel.fromJson(Map<String, dynamic> json) => ChatSessionModel(
        id: json['id'].toString(),
        title: json['title'] as String? ?? 'New conversation',
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
        messages: (json['messages'] as List? ?? [])
            .map((m) => ChatMessageModel.fromJson(m as Map<String, dynamic>))
            .toList(),
        documentIds: (json['document_ids'] as List? ?? []).map((e) => e.toString()).toList(),
      );

  /// Lightweight row from GET /chat/sessions (no message list, just a preview).
  factory ChatSessionModel.fromSummaryJson(Map<String, dynamic> json) => ChatSessionModel(
        id: json['id'].toString(),
        title: json['title'] as String? ?? 'New conversation',
        createdAt: DateTime.parse(json['updated_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
        previewText: json['last_message_preview'] as String? ?? 'No messages yet',
      );
}
