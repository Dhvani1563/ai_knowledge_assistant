import 'package:flutter/material.dart';
import '../core/constants/app_constants.dart';
import '../core/network/api_client.dart';
import '../models/document_model.dart';

class DocumentProvider extends ChangeNotifier {
  final _api = ApiClient.instance;

  List<DocumentModel> _documents = [];
  bool _isLoading = false;
  String? _errorMessage;
  final Set<String> _polling = {};

  List<DocumentModel> get documents => List.unmodifiable(_documents);
  List<DocumentModel> get readyDocuments => _documents.where((d) => d.status == DocumentStatus.ready).toList();
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  int get totalDocuments => _documents.length;
  int get totalChunks => _documents.fold(0, (sum, d) => sum + d.chunkCount);

  Future<void> fetchDocuments() async {
    _isLoading = true;
    notifyListeners();
    try {
      final data = await _api.get('/documents') as Map<String, dynamic>;
      _documents = (data['documents'] as List)
          .map((d) => DocumentModel.fromJson(d as Map<String, dynamic>))
          .toList();
      _errorMessage = null;
      // Resume progress tracking for anything still being processed
      // (e.g. the app was reopened mid-upload).
      for (final d in _documents) {
        if (d.status == DocumentStatus.uploading || d.status == DocumentStatus.processing) _poll(d.id);
      }
    } catch (e) {
      _errorMessage = e is ApiException ? e.message : 'Could not load documents.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Uploads the file, then polls GET /documents/{id} every couple of
  /// seconds until the backend's BackgroundTask finishes chunking + embedding
  /// (status flips to "ready" or "failed"). Swap this for a websocket if you
  /// add one later — polling is simplest for a portfolio project.
  Future<bool> uploadDocument({required List<int> bytes, required String name}) async {
    late DocumentModel uploaded;
    try {
      final data = await _api.uploadFile('/documents/upload', bytes: bytes, filename: name) as Map<String, dynamic>;
      uploaded = DocumentModel.fromJson(data);
      _documents.insert(0, uploaded);
      notifyListeners();
    } catch (e) {
      _errorMessage = e is ApiException ? e.message : 'Upload failed. Is the backend reachable?';
      notifyListeners();
      return false;
    }

    _poll(uploaded.id); // intentionally not awaited: progress updates in the background
    return true;
  }

  /// Polls GET /documents/{id} until the backend finishes (ready/failed).
  /// `stage` in the response ("Creating embeddings…") drives the card text.
  Future<void> _poll(String id) async {
    if (!_polling.add(id)) return; // already being tracked
    try {
      for (int i = 0; i < 120; i++) {
        await Future.delayed(const Duration(seconds: 2));
        final data = await _api.get('/documents/$id') as Map<String, dynamic>;
        final refreshed = DocumentModel.fromJson(data);
        final idx = _documents.indexWhere((d) => d.id == id);
        if (idx == -1) break; // deleted meanwhile
        _documents[idx] = refreshed;
        notifyListeners();
        if (refreshed.status == DocumentStatus.ready || refreshed.status == DocumentStatus.failed) break;
      }
    } catch (_) {
      // network hiccup: stop polling; pull-to-refresh / reopening resumes it
    } finally {
      _polling.remove(id);
    }
  }

  Future<void> deleteDocument(String id) async {
    final backup = List<DocumentModel>.from(_documents);
    _documents.removeWhere((d) => d.id == id);
    notifyListeners();
    try {
      await _api.delete('/documents/$id');
    } catch (e) {
      _documents = backup; // roll back on failure
      _errorMessage = e is ApiException ? e.message : 'Could not delete this document.';
      notifyListeners();
    }
  }
}
