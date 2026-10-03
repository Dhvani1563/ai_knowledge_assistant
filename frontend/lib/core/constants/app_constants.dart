class AppConstants {
  AppConstants._();

  static const String appName = 'Archive';
  static const String appTagline = 'Your private AI for documents';

  // Backend base URL.
  // - iOS simulator / desktop / web: http://localhost:8000/api/v1 (default below)
  // - Android emulator: use http://10.0.2.2:8000/api/v1 instead (localhost
  //   inside the emulator refers to the emulator itself, not your machine)
  // - Physical device: use your machine's LAN IP, e.g. http://192.168.1.23:8000/api/v1
  static const String apiBaseUrl = 'http://192.168.31.217:8000/api/v1';

  // Google Sign-In: paste your *Web application* OAuth client ID here (the
  // same value as GOOGLE_CLIENT_ID in backend/.env). See AUTH_SETUP.md.
  static const String googleWebClientId = '184169250041-9qvkgitbd6be6n7g7d658p2m3e4u8jq3.apps.googleusercontent.com';

  static const List<String> supportedFileTypes = ['pdf', 'docx', 'txt', 'md'];
  static const int maxFileSizeMb = 25;
}

/// Mirrors the backend's ML question-classifier output. Shown in the UI so
/// users can see *how* the system reasoned about their question, not just
/// the final answer — this is the ML/AI reasoning surface of the app.
enum QuestionType { factual, summarization, comparison, retrieval }

extension QuestionTypeX on QuestionType {
  String get label {
    switch (this) {
      case QuestionType.factual:
        return 'Factual';
      case QuestionType.summarization:
        return 'Summarization';
      case QuestionType.comparison:
        return 'Comparison';
      case QuestionType.retrieval:
        return 'Retrieval';
    }
  }

  String get description {
    switch (this) {
      case QuestionType.factual:
        return 'Looking up a specific fact in your documents';
      case QuestionType.summarization:
        return 'Condensing a document or section';
      case QuestionType.comparison:
        return 'Comparing information across documents';
      case QuestionType.retrieval:
        return 'Finding the most relevant passages';
    }
  }
}

enum DocumentStatus { uploading, processing, ready, failed }

enum MessageSender { user, assistant }
