import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../models/document_model.dart';
import '../../providers/document_provider.dart';

/// Bottom sheet where a document's OWNER decides who may ask questions about
/// it. People added here get read-only access: they can search and cite the
/// document in their own chats, but cannot delete it, re-share it, or see
/// who else has access. Removing someone takes effect immediately.
class ShareSheet extends StatefulWidget {
  final DocumentModel document;
  const ShareSheet({super.key, required this.document});

  static Future<void> show(BuildContext context, DocumentModel document) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => ShareSheet(document: document),
    );
  }

  @override
  State<ShareSheet> createState() => _ShareSheetState();
}

class _ShareSheetState extends State<ShareSheet> {
  final _emailController = TextEditingController();
  List<DocumentShareModel>? _shares;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  String _messageFor(Object e) => e is ApiException ? e.message : 'Something went wrong. Please try again.';

  Future<void> _load() async {
    try {
      final shares = await context.read<DocumentProvider>().fetchShares(widget.document.id);
      if (!mounted) return;
      setState(() {
        _shares = shares;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = _messageFor(e));
    }
  }

  Future<void> _add() async {
    final email = _emailController.text.trim();
    if (!email.contains('@') || !email.contains('.')) {
      setState(() => _error = 'Enter a valid email address.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final share = await context.read<DocumentProvider>().shareDocument(widget.document.id, email);
      if (!mounted) return;
      setState(() {
        final current = _shares ?? [];
        if (!current.any((s) => s.id == share.id)) current.add(share);
        _shares = current;
        _emailController.clear();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = _messageFor(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _remove(DocumentShareModel share) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove access?'),
        content: Text('${share.name} will no longer be able to search or ask about this document. Excerpts from it are also removed from their saved chats.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await context.read<DocumentProvider>().revokeShare(widget.document.id, share.id);
      if (!mounted) return;
      setState(() => _shares = _shares?.where((s) => s.id != share.id).toList());
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = _messageFor(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 4, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Share "${widget.document.name}"', style: AppTextStyles.h2, maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 6),
            Text(
              'People you add can ask questions about this document. They can\'t delete it, share it onward, or see who else has access. You can remove them anytime.',
              style: AppTextStyles.bodySm,
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    style: AppTextStyles.bodyMd,
                    decoration: const InputDecoration(
                      hintText: 'their@email.com',
                      prefixIcon: Icon(Icons.person_add_alt_1_outlined, size: 20, color: AppColors.textMuted),
                    ),
                    onSubmitted: (_) => _add(),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(minimumSize: const Size(72, 52)),
                    onPressed: _busy ? null : _add,
                    child: _busy
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Add'),
                  ),
                ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: AppTextStyles.bodySm.copyWith(color: AppColors.error)),
            ],
            const SizedBox(height: 20),
            Text('Who has access', style: AppTextStyles.label),
            const SizedBox(height: 8),
            if (_shares == null && _error == null)
              const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Center(child: CircularProgressIndicator(strokeWidth: 2.4, color: AppColors.brand)))
            else if (_shares != null && _shares!.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: AppColors.lavender50, borderRadius: BorderRadius.circular(12)),
                child: Text('Only you can access this document right now.', style: AppTextStyles.bodySm),
              )
            else if (_shares != null)
              ..._shares!.map(
                (s) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: AppColors.lavender100,
                    child: Text(s.name.isNotEmpty ? s.name[0].toUpperCase() : '?', style: AppTextStyles.h3.copyWith(color: AppColors.brandDeep)),
                  ),
                  title: Text(s.name, style: AppTextStyles.bodyMd.copyWith(fontWeight: FontWeight.w600)),
                  subtitle: Text('${s.email ?? 'No email'} · can view', style: AppTextStyles.caption),
                  trailing: IconButton(
                    icon: const Icon(Icons.close_rounded, color: AppColors.textMuted),
                    tooltip: 'Remove access',
                    onPressed: () => _remove(s),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
