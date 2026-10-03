import 'package:flutter/material.dart';
import '../core/constants/app_constants.dart';
import '../core/network/api_client.dart';
import '../models/chat_message_model.dart';

class ChatProvider extends ChangeNotifier {
  final _api = ApiClient.instance;

  final List<ChatSessionModel> _sessions = [];
  String? _activeSessionId;
  bool _isAssistantTyping = false;
  String? _errorMessage;

  List<ChatSessionModel> get sessions =>
      List.unmodifiable(_sessions..sort((a, b) => b.updatedAt.compareTo(a.updatedAt)));

  ChatSessionModel? get activeSession =>
      _sessions.where((s) => s.id == _activeSessionId).cast<ChatSessionModel?>().firstOrNull;

  bool get isAssistantTyping => _isAssistantTyping;
  String? get errorMessage => _errorMessage;

  // The backend classifies and answers in one request/response — there's no
  // websocket streaming the intermediate "classifying..." step yet, so this
  // stays null. The pipeline_status_indicator widget still shows a generic
  // "thinking" state while isAssistantTyping is true.
  QuestionType? get liveClassification => null;

  Future<void> fetchSessions() async {
    try {
      final data = await _api.get('/chat/sessions') as List;
      final summaries = data.map((s) => ChatSessionModel.fromSummaryJson(s as Map<String, dynamic>)).toList();
      for (final summary in summaries) {
        final idx = _sessions.indexWhere((s) => s.id == summary.id);
        if (idx == -1) {
          _sessions.add(summary);
        } else if (_sessions[idx].messages.isEmpty) {
          _sessions[idx] = summary; // don't clobber a session whose full messages we already loaded
        }
      }
      notifyListeners();
    } catch (e) {
      _errorMessage = e is ApiException ? e.message : 'Could not load conversations.';
      notifyListeners();
    }
  }

  Future<void> openSession(String sessionId) async {
    _activeSessionId = sessionId;
    notifyListeners();
    try {
      final data = await _api.get('/chat/sessions/$sessionId') as Map<String, dynamic>;
      final full = ChatSessionModel.fromJson(data);
      final idx = _sessions.indexWhere((s) => s.id == sessionId);
      if (idx != -1) {
        _sessions[idx] = full;
      } else {
        _sessions.add(full);
      }
      notifyListeners();
    } catch (e) {
      _errorMessage = e is ApiException ? e.message : 'Could not load this conversation.';
      notifyListeners();
    }
  }

  void setActiveSession(String sessionId) => openSession(sessionId);

  /// Starts a local draft session. It isn't persisted on the backend until
  /// the first message is sent — sendMessage() below creates the real
  /// session on the server and swaps this draft out for it.
  ChatSessionModel startNewSession({List<String> documentIds = const []}) {
    final draft = ChatSessionModel(
      id: 'draft-${DateTime.now().millisecondsSinceEpoch}',
      title: 'New conversation',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      documentIds: documentIds,
    );
    _sessions.insert(0, draft);
    _activeSessionId = draft.id;
    notifyListeners();
    return draft;
  }

  Future<void> deleteSession(String sessionId) async {
    _sessions.removeWhere((s) => s.id == sessionId);
    if (_activeSessionId == sessionId) _activeSessionId = null;
    notifyListeners();
    if (!sessionId.startsWith('draft-')) {
      try {
        await _api.delete('/chat/sessions/$sessionId');
      } catch (e) {
        _errorMessage = e is ApiException ? e.message : 'Could not delete this conversation.';
        notifyListeners();
      }
    }
  }

  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty) return;
    final session = activeSession ?? startNewSession();
    final isDraft = session.id.startsWith('draft-');

    // Optimistic UI: show the user's message immediately, before the
    // network round-trip (classify -> retrieve -> generate) completes.
    final optimisticUser = ChatMessageModel(
      id: 'local-${DateTime.now().millisecondsSinceEpoch}',
      sender: MessageSender.user,
      text: text.trim(),
      timestamp: DateTime.now(),
    );
    _replaceSession(session.copyWithMessages([...session.messages, optimisticUser]));

    _isAssistantTyping = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final body = <String, dynamic>{
        if (!isDraft) 'session_id': session.id,
        'text': text.trim(),
        'document_ids': session.documentIds,
      };
      final data = await _api.post('/chat/message', body: body) as Map<String, dynamic>;
      final newSession = ChatSessionModel.fromJson(data['session'] as Map<String, dynamic>);

      _sessions.removeWhere((s) => s.id == session.id); // drop the local draft / stale copy
      _sessions.removeWhere((s) => s.id == newSession.id);
      _sessions.add(newSession);
      _activeSessionId = newSession.id;
    } catch (e) {
      final message = e is ApiException ? e.message : 'Could not reach the server. Is the backend running?';
      final errorReply = ChatMessageModel(
        id: 'local-err-${DateTime.now().millisecondsSinceEpoch}',
        sender: MessageSender.assistant,
        text: 'Sorry — something went wrong: $message',
        timestamp: DateTime.now(),
      );
      final current = _sessions.where((s) => s.id == session.id).cast<ChatSessionModel?>().firstOrNull;
      if (current != null) {
        _replaceSession(current.copyWithMessages([...current.messages, errorReply]));
      }
      _errorMessage = message;
    } finally {
      _isAssistantTyping = false;
      notifyListeners();
    }
  }

  void _replaceSession(ChatSessionModel updated) {
    final idx = _sessions.indexWhere((s) => s.id == updated.id);
    if (idx != -1) {
      _sessions[idx] = updated;
    } else {
      _sessions.add(updated);
    }
    notifyListeners();
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
