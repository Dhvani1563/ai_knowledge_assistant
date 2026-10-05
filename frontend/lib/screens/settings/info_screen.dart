import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

/// One reusable screen for all three "info" rows on the Profile tab —
/// avoids three near-identical files for what is fundamentally the same
/// "title + body text" layout.
class InfoScreen extends StatelessWidget {
  final String title;
  final List<InfoSection> sections;

  const InfoScreen({super.key, required this.title, required this.sections});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          for (final section in sections) ...[
            if (section.heading != null) ...[
              Text(section.heading!, style: AppTextStyles.h2),
              const SizedBox(height: 8),
            ],
            if (section.body != null) ...[
              Text(section.body!, style: AppTextStyles.bodyMd.copyWith(height: 1.6)),
              const SizedBox(height: 20),
            ],
            if (section.link != null) ...[
              InkWell(
                onTap: () => launchUrl(Uri.parse(section.link!.url), mode: LaunchMode.externalApplication),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: AppColors.lavender50, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.lavender100)),
                  child: Row(
                    children: [
                      const Icon(Icons.open_in_new_rounded, size: 18, color: AppColors.brand),
                      const SizedBox(width: 10),
                      Expanded(child: Text(section.link!.label, style: AppTextStyles.bodyMd.copyWith(color: AppColors.brandDeep, fontWeight: FontWeight.w600))),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ],
        ],
      ),
    );
  }
}

class InfoSection {
  final String? heading;
  final String? body;
  final InfoLink? link;
  const InfoSection({this.heading, this.body, this.link});
}

class InfoLink {
  final String label;
  final String url;
  const InfoLink({required this.label, required this.url});
}

/// Real content for each of the three rows. Edit the placeholder email,
/// company name, and URLs below to your actual details before publishing.
class AppInfoContent {
  AppInfoContent._();

  static const privacy = [
    InfoSection(
      body: 'This explains what Archive stores and why, in plain language.',
    ),
    InfoSection(
      heading: 'What we store',
      body: 'Your name, email (or phone number), and a securely hashed password '
          '(we never store your actual password — only Google/Facebook/phone sign-ins '
          'skip a password entirely). Documents you upload, their extracted text, '
          'and the AI-searchable chunks generated from them. Your chat history, so '
          'you can revisit past conversations.',
    ),
    InfoSection(
      heading: 'Where it lives',
      body: 'Account and chat data is stored in a PostgreSQL database. Document text '
          'used for search is stored as vectors in a dedicated vector database. '
          'Both are access-controlled so only you can retrieve your own data.',
    ),
    InfoSection(
      heading: 'What we never do',
      body: 'We don\u2019t sell your data, show you ads, or share your documents with '
          'other users. Questions you ask are sent to the AI model provider '
          'solely to generate your answer, not for any other purpose.',
    ),
    InfoSection(
      heading: 'Deleting your data',
      body: 'Deleting a document removes its text and search vectors immediately. '
          'To delete your entire account, contact us using the link below.',
      link: InfoLink(label: 'Contact us about your data', url: 'mailto:privacy@example.com'),
    ),
  ];

  static const help = [
    InfoSection(
      body: 'Quick answers to the most common questions.',
    ),
    InfoSection(
      heading: 'What file types can I upload?',
      body: 'PDF, DOCX (Word), TXT, and Markdown (.md) files, up to 25 MB each.',
    ),
    InfoSection(
      heading: 'Why is my document stuck on "processing"?',
      body: 'Large documents take longer — a 50-page PDF usually finishes in under '
          'a minute. If it\u2019s been stuck for several minutes, try deleting and '
          're-uploading it; scanned PDFs with no selectable text currently aren\u2019t supported.',
    ),
    InfoSection(
      heading: 'How does Archive decide how to answer?',
      body: 'Every question is classified as factual, a summary request, a comparison, '
          'or a broad search — that classification changes how many passages are '
          'retrieved and how the answer is structured, so you get the right kind '
          'of response for the kind of question you asked.',
    ),
    InfoSection(
      heading: 'Can I ask by voice?',
      body: 'Yes — tap the microphone icon in the chat box, speak your question, '
          'and it sends automatically once you stop talking.',
    ),
    InfoSection(
      heading: 'Still stuck?',
      body: 'Reach out and we\u2019ll help directly.',
      link: InfoLink(label: 'Email support', url: 'mailto:support@example.com'),
    ),
  ];

  static const about = [
    InfoSection(
      body: 'Archive is a private AI assistant for your own documents — upload a PDF, '
          'resume, manual, or research paper, and ask it questions in plain English. '
          'Every answer comes with the exact source passage and page it was found on, '
          'so you can verify it yourself rather than just trusting the AI.',
    ),
    InfoSection(heading: 'Version', body: '1.0.0'),
    InfoSection(
      heading: 'How it works',
      body: 'Documents are split into small passages and converted into searchable '
          '"embeddings." When you ask a question, Archive finds the most relevant '
          'passages and asks an AI model to answer using only that material — '
          'not its general knowledge — which is what keeps answers grounded in '
          'your actual documents instead of invented.',
    ),
  ];
}
