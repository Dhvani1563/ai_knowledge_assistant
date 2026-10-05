import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/routes/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../providers/auth_provider.dart';
import '../../providers/document_provider.dart';
import '../../widgets/common/user_avatar.dart';
import 'info_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  String? _providerLabel(String? p) {
    switch (p) {
      case 'google':
        return 'Signed in with Google';
      case 'facebook':
        return 'Signed in with Facebook';
      case 'phone':
        return 'Signed in with phone number';
      default:
        return 'Email account';
    }
  }

  void _openInfo(BuildContext context, String title, List<InfoSection> sections) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => InfoScreen(title: title, sections: sections)));
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final docs = context.watch<DocumentProvider>();
    final user = auth.user;

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(color: AppColors.lavender50, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.lavender100)),
            child: Row(
              children: [
                UserAvatar(user: user, radius: 34),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user?.name ?? 'Guest', style: AppTextStyles.h1, maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 2),
                      Text(user?.email ?? user?.phone ?? '', style: AppTextStyles.bodySm, maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                        child: Text(_providerLabel(user?.oauthProvider) ?? '', style: AppTextStyles.caption.copyWith(color: AppColors.brandDeep, fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _Stat(label: 'Documents', value: '${docs.totalDocuments}')),
              const SizedBox(width: 12),
              Expanded(child: _Stat(label: 'Passages indexed', value: '${docs.totalChunks}')),
            ],
          ),
          const SizedBox(height: 26),
          Text('Account', style: AppTextStyles.label),
          const SizedBox(height: 8),
          _Group(children: [
            _Row(
              icon: Icons.security_outlined,
              title: 'Privacy & data',
              onTap: () => _openInfo(context, 'Privacy & data', AppInfoContent.privacy),
            ),
            _Row(
              icon: Icons.help_outline_rounded,
              title: 'Help center',
              onTap: () => _openInfo(context, 'Help center', AppInfoContent.help),
            ),
            _Row(
              icon: Icons.info_outline_rounded,
              title: 'About Archive',
              onTap: () => _openInfo(context, 'About Archive', AppInfoContent.about),
              last: true,
            ),
          ]),
          const SizedBox(height: 26),
          OutlinedButton.icon(
            onPressed: () async {
              await context.read<AuthProvider>().logout();
              if (context.mounted) Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.login, (route) => false);
            },
            icon: const Icon(Icons.logout_rounded, color: AppColors.error, size: 18),
            label: Text('Log out', style: AppTextStyles.button.copyWith(color: AppColors.error)),
            style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.errorSoft, width: 1.4)),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  const _Stat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(value, style: AppTextStyles.displaySm),
          Text(label, style: AppTextStyles.caption),
        ]),
      );
}

class _Group extends StatelessWidget {
  final List<Widget> children;
  const _Group({required this.children});

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
        child: Column(children: children),
      );
}

class _Row extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final bool last;
  const _Row({required this.icon, required this.title, required this.onTap, this.last = false});

  @override
  Widget build(BuildContext context) => Column(children: [
        ListTile(
          onTap: onTap,
          leading: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: AppColors.lavender100, borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, size: 19, color: AppColors.brand),
          ),
          title: Text(title, style: AppTextStyles.bodyMd.copyWith(fontWeight: FontWeight.w500)),
          trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
        ),
        if (!last) const Divider(indent: 68),
      ]);
}
