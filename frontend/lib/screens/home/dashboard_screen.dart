import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../../providers/document_provider.dart';
import '../../widgets/common/user_avatar.dart';
import '../chat/chat_screen.dart';
import '../documents/document_management_screen.dart';
import '../settings/settings_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 18) return 'Good afternoon';
    return 'Good evening';
  }

  void _newChat(BuildContext context) {
    context.read<ChatProvider>().startNewSession();
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ChatScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final docs = context.watch<DocumentProvider>();
    final chat = context.watch<ChatProvider>();
    final firstName = (auth.user?.name ?? 'there').split(' ').first;
    final recent = chat.sessions.take(3).toList();

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          children: [
            // Header
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_greeting(), style: AppTextStyles.bodyMd.copyWith(color: AppColors.textSecondary)),
                      const SizedBox(height: 2),
                      Text(firstName, style: AppTextStyles.displaySm),
                    ],
                  ),
                ),
                InkWell(
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsScreen())),
                  customBorder: const CircleBorder(),
                  child: UserAvatar(user: auth.user, radius: 24),
                ),
              ],
            ),
            const SizedBox(height: 22),

            // Primary action: looks like a search box, because the mental model is "just ask".
            InkWell(
              onTap: () => _newChat(context),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.fromLTRB(18, 18, 14, 18),
                decoration: BoxDecoration(
                  color: AppColors.lavender50,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.lavender200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('What do you want to know?', style: AppTextStyles.h1),
                    const SizedBox(height: 4),
                    Text('Answers come with the exact page they were found on.', style: AppTextStyles.bodySm),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.fromLTRB(16, 6, 6, 6),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.lavender100)),
                      child: Row(
                        children: [
                          Expanded(child: Text('Ask about your documents…', style: AppTextStyles.bodyMd.copyWith(color: AppColors.textMuted))),
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(color: AppColors.brand, borderRadius: BorderRadius.circular(12)),
                            child: const Icon(Icons.arrow_upward_rounded, color: Colors.white, size: 20),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),

            // Stats
            Row(
              children: [
                Expanded(child: _StatTile(icon: Icons.folder_outlined, value: '${docs.totalDocuments}', label: 'Documents')),
                const SizedBox(width: 10),
                Expanded(child: _StatTile(icon: Icons.layers_outlined, value: '${docs.totalChunks}', label: 'Passages')),
                const SizedBox(width: 10),
                Expanded(child: _StatTile(icon: Icons.forum_outlined, value: '${chat.sessions.length}', label: 'Chats')),
              ],
            ),
            const SizedBox(height: 26),

            // Quick actions
            Row(
              children: [
                Expanded(
                  child: _ActionTile(
                    icon: Icons.upload_file_rounded,
                    title: 'Add a document',
                    subtitle: 'PDF, DOCX, TXT, MD',
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const DocumentManagementScreen())),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(child: _ActionTile(icon: Icons.add_comment_outlined, title: 'New chat', subtitle: 'Start fresh', onTap: () => _newChat(context))),
              ],
            ),
            const SizedBox(height: 28),

            // Recent
            Text('Recent chats', style: AppTextStyles.h2),
            const SizedBox(height: 12),
            if (recent.isEmpty)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: AppColors.lavender50, borderRadius: BorderRadius.circular(16)),
                child: Text('Your conversations will show up here.', style: AppTextStyles.bodySm, textAlign: TextAlign.center),
              )
            else
              ...recent.map((s) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: InkWell(
                      onTap: () {
                        context.read<ChatProvider>().setActiveSession(s.id);
                        Navigator.of(context).push(MaterialPageRoute(builder: (_) => ChatScreen(sessionId: s.id)));
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(color: AppColors.lavender100, borderRadius: BorderRadius.circular(12)),
                              child: const Icon(Icons.chat_bubble_outline_rounded, color: AppColors.brand, size: 19),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(s.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTextStyles.bodyMd.copyWith(fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 2),
                                  Text(s.lastMessagePreview, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTextStyles.bodySm),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
                          ],
                        ),
                      ),
                    ),
                  )),
          ],
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  const _StatTile({required this.icon, required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppColors.lavender500),
          const SizedBox(height: 10),
          Text(value, style: AppTextStyles.h1),
          Text(label, style: AppTextStyles.caption),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _ActionTile({required this.icon, required this.title, required this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: AppColors.lavender50, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.lavender100)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(11)),
              child: Icon(icon, color: AppColors.brand, size: 20),
            ),
            const SizedBox(height: 12),
            Text(title, style: AppTextStyles.h3),
            Text(subtitle, style: AppTextStyles.caption),
          ],
        ),
      ),
    );
  }
}
