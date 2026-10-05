class UserModel {
  final String id;
  final String name;
  final String? email;
  final String? phone;
  final String? avatarUrl;
  final String? oauthProvider; // 'google' | 'facebook' | 'phone' | null (email/password)
  final DateTime joinedAt;
  final int documentCount;
  final int queryCount;

  const UserModel({
    required this.id,
    required this.name,
    this.email,
    this.phone,
    this.avatarUrl,
    this.oauthProvider,
    required this.joinedAt,
    this.documentCount = 0,
    this.queryCount = 0,
  });

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
  }

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
        id: json['id'].toString(),
        name: json['name'] as String,
        email: json['email'] as String?,
        phone: json['phone'] as String?,
        avatarUrl: json['avatar_url'] as String?,
        oauthProvider: json['oauth_provider'] as String?,
        joinedAt: DateTime.parse(json['created_at'] as String),
        documentCount: json['document_count'] as int? ?? 0,
        queryCount: json['query_count'] as int? ?? 0,
      );
}
