import 'package:cloud_firestore/cloud_firestore.dart';

class Article {
  final String id;
  final String title;
  final String description;
  final String content;
  final String sourceUrl;
  final String sourceName;
  final String? imageUrl;
  final DateTime publishedAt;
  final DateTime cachedAt;

  const Article({
    required this.id,
    required this.title,
    required this.description,
    required this.content,
    required this.sourceUrl,
    required this.sourceName,
    this.imageUrl,
    required this.publishedAt,
    required this.cachedAt,
  });

  // Đọc từ Firestore
  factory Article.fromFirestore(Map<String, dynamic> data, String id) {
    return Article(
      id: id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      content: data['content'] ?? '',
      sourceUrl: data['sourceUrl'] ?? '',
      sourceName: data['sourceName'] ?? '',
      imageUrl: data['imageUrl'],
      publishedAt: (data['publishedAt'] as Timestamp).toDate(),
      cachedAt: (data['cachedAt'] as Timestamp).toDate(),
    );
  }

  // Đọc từ GNews API response
  factory Article.fromGNews(Map<String, dynamic> json) {
    final now = DateTime.now();
    // GNews trả về id không có sẵn → dùng url làm id (hash)
    final id = json['url'].toString().hashCode.abs().toString();
    return Article(
      id: id,
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      // GNews free tier cắt content kiểu "...text [1362 chars]"
      // → xóa phần " [X chars]" và dùng description ghép vào nếu content quá ngắn
      content: _cleanContent(json['content'] ?? '', json['description'] ?? ''),
      sourceUrl: json['url'] ?? '',
      sourceName: json['source']?['name'] ?? '',
      imageUrl: json['image'],
      publishedAt: DateTime.tryParse(json['publishedAt'] ?? '') ?? now,
      cachedAt: now,
    );
  }

  // Ghi vào Firestore
  Map<String, dynamic> toFirestore() => {
    'title': title,
    'description': description,
    'content': content,
    'sourceUrl': sourceUrl,
    'sourceName': sourceName,
    'imageUrl': imageUrl,
    'publishedAt': Timestamp.fromDate(publishedAt),
    'cachedAt': Timestamp.fromDate(cachedAt),
  };

  static String _cleanContent(String content, String description) {
    // Xóa các dấu hiệu bị cắt
    final cleaned = content
        .replaceAll(RegExp(r'\s*\[\d+ chars\]$'), '')
        .replaceAll(RegExp(r'\s*\.\.\.$'), '')
        .trim();

    // Nếu description dài hơn → dùng description
    if (description.length >= cleaned.length) return description;

    // content đủ dài và không bị cắt → dùng content
    return cleaned.isEmpty ? description : cleaned;
  }
}
