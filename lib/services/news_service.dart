import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/article_model.dart';

/// NewsService xử lý 3 việc:
/// 1. Lấy bài từ GNews API
/// 2. Cache vào Firestore (tránh gọi lại trong 6 tiếng)
/// 3. Dịch đoạn văn qua MyMemory API (free, không cần key)
class NewsService {
  static final NewsService _instance = NewsService._();
  factory NewsService() => _instance;
  NewsService._();

  final _db = FirebaseFirestore.instance;
  static const _cacheHours = 6; // Refresh sau 6 tiếng
  static const _articleCount = 10;

  // ─── Public: lấy danh sách bài ──────────────────────────────────────────────
  /// Trả về bài từ cache Firestore nếu còn mới,
  /// ngược lại gọi GNews và cập nhật cache.
  Future<List<Article>> getArticles() async {
    try {
      // 1. Thử đọc cache
      final cached = await _getCachedArticles();
      if (cached.isNotEmpty) {
        debugPrint('[NewsService] dùng cache (${cached.length} bài)');
        return cached;
      }

      // 2. Cache hết hạn hoặc trống → gọi GNews
      debugPrint('[NewsService] gọi GNews API...');
      final fresh = await _fetchFromGNews();
      if (fresh.isEmpty) return [];

      // 3. Lưu vào Firestore
      await _cacheArticles(fresh);
      return fresh;
    } catch (e) {
      debugPrint('[NewsService] getArticles error: $e');
      return [];
    }
  }

  // ─── Public: dịch đoạn văn ──────────────────────────────────────────────────
  /// Gọi MyMemory API để dịch [text] từ EN sang VI.
  /// MyMemory free: 5000 ký tự/ngày, không cần API key.
  Future<String?> translateToVietnamese(String text) async {
    try {
      // Giới hạn 500 ký tự/lần để tránh lỗi
      final truncated = text.length > 500 ? text.substring(0, 500) : text;
      final uri = Uri.parse(
        'https://api.mymemory.translated.net/get'
        '?q=${Uri.encodeComponent(truncated)}'
        '&langpair=en|vi',
      );
      final res = await http.get(uri).timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return null;

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      // MyMemory trả về responseStatus 200 nếu thành công
      if (data['responseStatus'] == 200) {
        return data['responseData']?['translatedText'] as String?;
      }
      return null;
    } catch (e) {
      debugPrint('[NewsService] translate error: $e');
      return null;
    }
  }

  // ─── Public: tra nghĩa từ đơn ───────────────────────────────────────────────
  /// Gọi song song 2 API:
  ///   1. Free Dictionary API (dictionaryapi.dev) → phonetic + định nghĩa EN
  ///   2. MyMemory API                            → nghĩa tiếng Việt
  /// Dùng Future.wait để chạy cả 2 cùng lúc, tổng thời gian = max(t1, t2).
  Future<WordLookupResult?> lookupWord(String word) async {
    final clean = word.trim().toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');
    if (clean.isEmpty) return null;
    try {
      // Chạy cả 2 API đồng thời
      final results = await Future.wait([
        _fetchDictionary(clean),  // kết quả [0]: Map<String,dynamic>? hoặc null
        _myMemoryWord(clean),     // kết quả [1]: String? (tiếng Việt) hoặc null
      ]);

      final dictEntry = results[0] as Map<String, dynamic>?;
      final viTranslation = results[1] as String?;

      // Nếu cả 2 đều thất bại → không tìm thấy từ
      if (dictEntry == null && viTranslation == null) return null;

      // Nếu chỉ có MyMemory (từ không có trong dictionary)
      if (dictEntry == null) {
        return WordLookupResult(
          word: clean,
          vietnameseMeaning: viTranslation,
          myMemoryFallback: viTranslation,
        );
      }

      // Parse phonetic
      String phonetic = dictEntry['phonetic'] as String? ?? '';
      if (phonetic.isEmpty) {
        final phonetics = (dictEntry['phonetics'] as List?)
            ?.map((p) => (p as Map)['text'] as String? ?? '')
            .where((p) => p.isNotEmpty)
            .toList();
        phonetic = phonetics?.isNotEmpty == true ? phonetics!.first : '';
      }

      // Parse meanings (định nghĩa tiếng Anh)
      final rawMeanings = dictEntry['meanings'] as List? ?? [];
      final meanings = <WordMeaning>[];
      for (final m in rawMeanings.take(3)) {
        final map = m as Map<String, dynamic>;
        final pos = map['partOfSpeech'] as String? ?? '';
        final defs = (map['definitions'] as List? ?? [])
            .take(3)
            .map((d) => (d as Map<String, dynamic>)['definition'] as String? ?? '')
            .where((d) => d.isNotEmpty)
            .toList();
        if (defs.isNotEmpty) {
          meanings.add(WordMeaning(partOfSpeech: pos, definitions: defs));
        }
      }

      // Merge: dict data + tiếng Việt
      return WordLookupResult(
        word: clean,
        phonetic: phonetic,
        meanings: meanings,
        vietnameseMeaning: viTranslation,
      );
    } catch (e) {
      debugPrint('[NewsService] lookupWord error: $e');
      return null;
    }
  }

  /// Gọi Free Dictionary API, trả về raw entry Map hoặc null nếu thất bại.
  Future<Map<String, dynamic>?> _fetchDictionary(String word) async {
    try {
      final uri = Uri.parse(
        'https://api.dictionaryapi.dev/api/v2/entries/en/$word',
      );
      final res = await http.get(uri).timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return null;
      final list = jsonDecode(res.body) as List<dynamic>;
      if (list.isEmpty) return null;
      return list.first as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<String?> _myMemoryWord(String word) async {
    try {
      final uri = Uri.parse(
        'https://api.mymemory.translated.net/get'
        '?q=${Uri.encodeComponent(word)}'
        '&langpair=en|vi',
      );
      final res = await http.get(uri).timeout(const Duration(seconds: 6));
      if (res.statusCode != 200) return null;
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      if (data['responseStatus'] == 200) {
        return data['responseData']?['translatedText'] as String?;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  // ─── Private: đọc cache Firestore ───────────────────────────────────────────
  Future<List<Article>> _getCachedArticles() async {
    final cutoff = DateTime.now().subtract(const Duration(hours: _cacheHours));
    final snap = await _db
        .collection('reading_articles')
        .where('cachedAt', isGreaterThan: Timestamp.fromDate(cutoff))
        .orderBy('cachedAt', descending: true)
        .limit(_articleCount)
        .get();

    return snap.docs.map((d) => Article.fromFirestore(d.data(), d.id)).toList();
  }

  // ─── Private: gọi GNews ─────────────────────────────────────────────────────
  Future<List<Article>> _fetchFromGNews() async {
    // Đọc key từ .env
    final apiKey = dotenv.env['GNEWS_API_KEY'] ?? '';
    if (apiKey.isEmpty) {
      debugPrint('[NewsService] GNEWS_API_KEY chưa được set trong .env');
      return [];
    }

    // GNews API: lấy tin tiếng Anh, chủ đề general, 10 bài
    // Docs: https://gnews.io/docs/v4
    final uri = Uri.parse(
      'https://gnews.io/api/v4/top-headlines'
      '?lang=en'
      '&country=us'
      '&max=$_articleCount'
      '&apikey=$apiKey',
    );

    final res = await http.get(uri).timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) {
      debugPrint('[NewsService] GNews status: ${res.statusCode}');
      return [];
    }

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final articles = (data['articles'] as List? ?? [])
        .map((j) => Article.fromGNews(j as Map<String, dynamic>))
        .toList();

    debugPrint('[NewsService] GNews trả về ${articles.length} bài');
    return articles;
  }

  // ─── Private: lưu cache vào Firestore ───────────────────────────────────────
  Future<void> _cacheArticles(List<Article> articles) async {
    // Xóa bài cũ trước
    final oldSnap = await _db.collection('reading_articles').get();
    final batch = _db.batch();
    for (final doc in oldSnap.docs) {
      batch.delete(doc.reference);
    }
    // Ghi bài mới
    for (final article in articles) {
      final ref = _db.collection('reading_articles').doc(article.id);
      batch.set(ref, article.toFirestore());
    }
    await batch.commit();
    debugPrint('[NewsService] đã cache ${articles.length} bài vào Firestore');
  }
}

// ─── Data models cho tra từ ──────────────────────────────────────────────────
class WordMeaning {
  final String partOfSpeech;
  final List<String> definitions;
  const WordMeaning({required this.partOfSpeech, required this.definitions});
}

class WordLookupResult {
  final String word;
  final String phonetic;
  final List<WordMeaning> meanings;

  /// Nghĩa tiếng Việt từ MyMemory API — luôn được điền nếu API trả về thành công.
  /// Ví dụ: "executive" → "giám đốc điều hành"
  final String? vietnameseMeaning;

  /// Chỉ set khi Dictionary API không có từ (fallback thuần MyMemory).
  final String? myMemoryFallback;

  const WordLookupResult({
    required this.word,
    this.phonetic = '',
    this.meanings = const [],
    this.vietnameseMeaning,
    this.myMemoryFallback,
  });

  bool get hasDictData => meanings.isNotEmpty;
}
