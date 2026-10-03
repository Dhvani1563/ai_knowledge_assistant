import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../models/chat_message_model.dart';
import 'question_type_badge.dart';
import 'source_citation_card.dart';

/// User messages: solid violet, right-aligned (mine = strong).
/// Assistant messages: soft lavender, left-aligned, with the classifier
/// badge above and evidence cards below (theirs = calm, but inspectable).
class ChatBubble extends StatelessWidget {
  final ChatMessageModel message;
  final void Function(int sourceIndex)? onSourceTap;

  const ChatBubble({super.key, required this.message, this.onSourceTap});

  bool get _isUser => message.sender == MessageSender.user;

  @override
  Widget build(BuildContext context) {
    final maxW = MediaQuery.of(context).size.width * 0.8;
    final textColor = _isUser ? Colors.white : AppColors.textPrimary;

    final bubble = Container(
      constraints: BoxConstraints(maxWidth: maxW),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _isUser ? AppColors.brand : AppColors.lavender50,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(20),
          topRight: const Radius.circular(20),
          bottomLeft: Radius.circular(_isUser ? 20 : 6),
          bottomRight: Radius.circular(_isUser ? 6 : 20),
        ),
        border: _isUser ? null : Border.all(color: AppColors.lavender100),
      ),
      child: MarkdownBody(
        data: message.text,
        softLineBreak: true,
        shrinkWrap: true,
        styleSheet: MarkdownStyleSheet(
          p: AppTextStyles.bodyMd.copyWith(color: textColor, height: 1.55),
          strong: AppTextStyles.bodyMd.copyWith(color: textColor, fontWeight: FontWeight.w700),
          listBullet: AppTextStyles.bodyMd.copyWith(color: textColor),
          code: AppTextStyles.bodyMd.copyWith(color: AppColors.brandDeep, backgroundColor: AppColors.lavender100),
          tableBorder: TableBorder.all(color: AppColors.lavender200),
          tableHead: AppTextStyles.bodyMd.copyWith(color: textColor, fontWeight: FontWeight.w700),
          tableBody: AppTextStyles.bodyMd.copyWith(color: textColor),
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Column(
        crossAxisAlignment: _isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (_isUser)
            bubble
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _AssistantAvatar(),
                const SizedBox(width: 10),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (message.questionType != null)
                        Padding(padding: const EdgeInsets.only(bottom: 6), child: QuestionTypeBadge(type: message.questionType!, compact: true)),
                      bubble,
                    ],
                  ),
                ),
              ],
            ),
          if (!_isUser && message.sources.isNotEmpty) ...[
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.only(left: 42),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${message.sources.length} source${message.sources.length == 1 ? '' : 's'}', style: AppTextStyles.label),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 122,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      clipBehavior: Clip.none,
                      itemCount: message.sources.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, i) => SourceCitationCard(source: message.sources[i], index: i + 1, onTap: () => onSourceTap?.call(i)),
                    ),
                  ),
                ],
              ),
            ),
          ],
          Padding(
            padding: EdgeInsets.only(top: 5, left: _isUser ? 0 : 42, right: _isUser ? 4 : 0),
            child: Text(_time(message.timestamp), style: AppTextStyles.caption),
          ),
        ],
      ),
    );
  }

  String _time(DateTime t) {
    final l = t.toLocal();
    final h = l.hour % 12 == 0 ? 12 : l.hour % 12;
    return '$h:${l.minute.toString().padLeft(2, '0')} ${l.hour >= 12 ? 'PM' : 'AM'}';
  }
}

class _AssistantAvatar extends StatelessWidget {
  const _AssistantAvatar();

  @override
  Widget build(BuildContext context) => Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(color: AppColors.lavender100, shape: BoxShape.circle, border: Border.all(color: AppColors.lavender200)),
        child: const Icon(Icons.auto_awesome_rounded, size: 16, color: AppColors.brand),
      );
}
