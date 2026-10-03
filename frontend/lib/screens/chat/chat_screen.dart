import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../providers/chat_provider.dart';
import '../../providers/document_provider.dart';
import '../../widgets/chat/chat_bubble.dart';
import '../../widgets/chat/chat_input_field.dart';
import '../../widgets/chat/pipeline_status_indicator.dart';
import '../../widgets/chat/suggested_prompts.dart';
import '../../models/document_model.dart';

class ChatScreen extends StatefulWidget {
  final String? sessionId;
  const ChatScreen({super.key, this.sessionId});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    if (widget.sessionId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.read<ChatProvider>().setActiveSession(widget.sessionId!);
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 160,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send(String text) async {
    final chat = context.read<ChatProvider>();
    _scrollToBottom();
    await chat.sendMessage(text);
    _scrollToBottom();
  }

  void _openDocumentPicker() {
    final docs = context.read<DocumentProvider>().readyDocuments;
    showModalBottomSheet(
      context: context,
      builder: (context) => _DocumentScopeSheet(documents: docs),
    );
  }

  @override
  Widget build(BuildContext context) {
    final chat = context.watch<ChatProvider>();
    final session = chat.activeSession;
    final messages = session?.messages ?? [];

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(color: AppColors.lavender100, shape: BoxShape.circle, border: Border.all(color: AppColors.lavender200)),
              child: const Icon(Icons.auto_awesome_rounded, size: 17, color: AppColors.brand),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(session?.title ?? 'New conversation', style: AppTextStyles.h3, maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text('Grounded in your documents', style: AppTextStyles.caption),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _openDocumentPicker,
            icon: const Icon(Icons.folder_outlined),
            tooltip: 'Scope to documents',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: messages.isEmpty
                ? _EmptyChatState(onPromptTap: _send)
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                    itemCount: messages.length + (chat.isAssistantTyping ? 1 : 0),
                    itemBuilder: (context, i) {
                      if (i == messages.length) {
                        return PipelineStatusIndicator(classification: chat.liveClassification);
                      }
                      return ChatBubble(message: messages[i]);
                    },
                  ),
          ),
          ChatInputField(onSend: _send, onAttach: _openDocumentPicker, enabled: !chat.isAssistantTyping),
        ],
      ),
    );
  }
}

class _EmptyChatState extends StatelessWidget {
  final void Function(String) onPromptTap;
  const _EmptyChatState({required this.onPromptTap});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(color: AppColors.lavender100, borderRadius: BorderRadius.circular(22)),
              child: const Icon(Icons.auto_awesome_rounded, color: AppColors.brand, size: 30),
            ),
            const SizedBox(height: 18),
            Text('Ask about your documents', style: AppTextStyles.h1, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(
              'Every answer is grounded in your files and comes with source citations.',
              style: AppTextStyles.bodyMd.copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SuggestedPrompts(onTap: onPromptTap),
          ],
        ),
      ),
    );
  }
}

class _DocumentScopeSheet extends StatelessWidget {
  final List<DocumentModel> documents;
  const _DocumentScopeSheet({required this.documents});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Scope this conversation', style: AppTextStyles.h2),
            const SizedBox(height: 4),
            Text('Choose which documents the assistant should search.', style: AppTextStyles.bodySm),
            const SizedBox(height: 16),
            if (documents.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Text('No processed documents yet. Upload one from the Documents tab.', style: AppTextStyles.bodyMd),
              )
            else
              ...documents.map((d) => CheckboxListTile(
                    value: true,
                    onChanged: (_) {},
                    contentPadding: EdgeInsets.zero,
                    activeColor: AppColors.brand,
                    title: Text(d.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTextStyles.bodyMd),
                    subtitle: Text('${d.pageCount} pages · ${d.chunkCount} chunks', style: AppTextStyles.caption),
                  )),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Done'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
