import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../providers/chat_provider.dart';
import '../../widgets/common/empty_state.dart';
import 'chat_screen.dart';

class ChatHistoryScreen extends StatelessWidget {
  const ChatHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final chat = context.watch<ChatProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Conversations')),
      body: chat.sessions.isEmpty
          ? const EmptyState(
              icon: Icons.chat_bubble_outline_rounded,
              title: 'No conversations yet',
              message: 'Start a new chat and ask a question about your uploaded documents.',
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
              itemCount: chat.sessions.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final s = chat.sessions[i];
                return Dismissible(
                  key: ValueKey(s.id),
                  direction: DismissDirection.endToStart,
                  onDismissed: (_) => context.read<ChatProvider>().deleteSession(s.id),
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    decoration: BoxDecoration(color: AppColors.errorSoft, borderRadius: BorderRadius.circular(14)),
                    child: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
                  ),
                  child: ListTile(
                    onTap: () {
                      context.read<ChatProvider>().setActiveSession(s.id);
                      Navigator.of(context).push(MaterialPageRoute(builder: (_) => ChatScreen(sessionId: s.id)));
                    },
                    tileColor: AppColors.surface,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: AppColors.border)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    leading: const CircleAvatar(backgroundColor: AppColors.surfaceAlt, child: Icon(Icons.chat_bubble_outline_rounded, color: AppColors.brand, size: 18)),
                    title: Text(s.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTextStyles.bodyMd.copyWith(fontWeight: FontWeight.w600)),
                    subtitle: Text(s.lastMessagePreview, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTextStyles.bodySm),
                    trailing: Text(DateFormat('MMM d').format(s.updatedAt), style: AppTextStyles.caption),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.brand,
        onPressed: () {
          context.read<ChatProvider>().startNewSession();
          Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ChatScreen()));
        },
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: Text('New chat', style: AppTextStyles.button.copyWith(color: Colors.white)),
      ),
    );
  }
}
