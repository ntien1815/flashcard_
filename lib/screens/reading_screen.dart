import 'package:flutter/material.dart';
import '../models/article_model.dart';
import '../services/news_service.dart';
import '../theme/app_colors.dart';

// ─── Reading Screen (danh sách bài) ──────────────────────────────────────────
class ReadingScreen extends StatefulWidget {
  const ReadingScreen({super.key});
  @override
  State<ReadingScreen> createState() => _ReadingScreenState();
}

class _ReadingScreenState extends State<ReadingScreen> {
  final _service = NewsService();
  List<Article> _articles = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final articles = await _service.getArticles();
      if (mounted) setState(() => _articles = articles);
    } catch (e) {
      if (mounted) setState(() => _error = 'Không thể tải bài đọc');
      debugPrint('[ReadingScreen] error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    if (_loading) {
      return Center(child: CircularProgressIndicator(color: c.primary));
    }
    if (_error != null || _articles.isEmpty) {
      return _buildError(c);
    }
    return RefreshIndicator(
      color: c.primary,
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 80),
        itemCount: _articles.length,
        itemBuilder: (context, i) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _ArticleCard(article: _articles[i]),
        ),
      ),
    );
  }

  Widget _buildError(AppColors c) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.wifi_off_rounded, size: 48, color: c.textTertiary),
          const SizedBox(height: 12),
          Text(
            _error ?? 'Chưa có bài đọc',
            style: TextStyle(fontSize: 14, color: c.textSecondary),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text('Thử lại'),
            style: FilledButton.styleFrom(
              backgroundColor: c.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Article Card ─────────────────────────────────────────────────────────────
class _ArticleCard extends StatelessWidget {
  final Article article;
  const _ArticleCard({required this.article});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => _ArticleDetailScreen(article: article),
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: c.border.withValues(alpha: 0.3),
            width: 0.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (article.imageUrl != null)
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(14),
                ),
                child: Image.network(
                  article.imageUrl!,
                  height: 160,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stack) =>
                      const SizedBox.shrink(),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: c.primaryBg,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          article.sourceName,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: c.primary,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        _timeAgo(article.publishedAt),
                        style: TextStyle(fontSize: 10, color: c.textTertiary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    article.title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: c.textPrimary,
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    article.description,
                    style: TextStyle(
                      fontSize: 12,
                      color: c.textSecondary,
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(Icons.menu_book_rounded, size: 13, color: c.coral),
                      const SizedBox(width: 4),
                      Text(
                        'Đọc bài',
                        style: TextStyle(
                          fontSize: 11,
                          color: c.coral,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const Spacer(),
                      Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 12,
                        color: c.textTertiary,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inHours < 1) return '${diff.inMinutes} phút trước';
    if (diff.inHours < 24) return '${diff.inHours} giờ trước';
    return '${diff.inDays} ngày trước';
  }
}

// ─── Article Detail Screen ────────────────────────────────────────────────────
class _ArticleDetailScreen extends StatelessWidget {
  final Article article;
  const _ArticleDetailScreen({required this.article});

  List<String> _splitParagraphs(String text) {
    final parts = text.split(RegExp(r'\n+'));
    final result = parts.where((p) => p.trim().length > 30).toList();
    if (result.length <= 1) return _splitBySentence(text);
    return result;
  }

  List<String> _splitBySentence(String text) {
    final sentences = text.split(RegExp(r'(?<=[.!?])\s+'));
    final paragraphs = <String>[];
    for (int i = 0; i < sentences.length; i += 3) {
      final end = (i + 3 < sentences.length) ? i + 3 : sentences.length;
      final para = sentences.sublist(i, end).join(' ').trim();
      if (para.isNotEmpty) paragraphs.add(para);
    }
    return paragraphs;
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final paragraphs = _splitParagraphs(article.content);

    return Scaffold(
      backgroundColor: c.bodyBg,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            backgroundColor: c.primary,
            leading: IconButton(
              icon: const Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 18,
                color: Colors.white,
              ),
              onPressed: () => Navigator.pop(context),
            ),
            expandedHeight: article.imageUrl != null ? 220 : 120,
            flexibleSpace: FlexibleSpaceBar(
              background: article.imageUrl != null
                  ? Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.network(
                          article.imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stack) =>
                              Container(color: c.primary),
                        ),
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                c.primaryDark.withValues(alpha: 0.9),
                              ],
                            ),
                          ),
                        ),
                        Positioned(
                          left: 16,
                          right: 16,
                          bottom: 16,
                          child: Text(
                            article.title,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                              height: 1.3,
                            ),
                          ),
                        ),
                      ],
                    )
                  : Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [c.primary, c.primaryDark],
                        ),
                      ),
                      child: SafeArea(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 52, 16, 16),
                          child: Align(
                            alignment: Alignment.bottomLeft,
                            child: Text(
                              article.title,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                                height: 1.3,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 80),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                Row(
                  children: [
                    Icon(Icons.public_rounded, size: 13, color: c.primary),
                    const SizedBox(width: 4),
                    Text(
                      article.sourceName,
                      style: TextStyle(
                        fontSize: 12,
                        color: c.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${article.publishedAt.day}/${article.publishedAt.month}/${article.publishedAt.year}',
                      style: TextStyle(fontSize: 11, color: c.textTertiary),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  article.description,
                  style: TextStyle(
                    fontSize: 14,
                    color: c.textSecondary,
                    height: 1.5,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(height: 14),
                Divider(color: c.border.withValues(alpha: 0.5)),
                const SizedBox(height: 12),
                ...paragraphs.asMap().entries.map(
                  (e) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _ParagraphCard(text: e.value, index: e.key),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.link_rounded, size: 14, color: c.textTertiary),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        'Nguồn: ${article.sourceName}',
                        style: TextStyle(fontSize: 11, color: c.textTertiary),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Paragraph Card (có nút dịch) ────────────────────────────────────────────
class _ParagraphCard extends StatefulWidget {
  final String text;
  final int index;
  const _ParagraphCard({required this.text, required this.index});
  @override
  State<_ParagraphCard> createState() => _ParagraphCardState();
}

class _ParagraphCardState extends State<_ParagraphCard> {
  String? _translation;
  bool _loadingTranslation = false;
  bool _showTranslation = false;

  Future<void> _translate() async {
    // Đã có bản dịch rồi → chỉ toggle ẩn/hiện, không gọi API lại
    if (_translation != null) {
      setState(() => _showTranslation = !_showTranslation);
      return;
    }
    setState(() => _loadingTranslation = true);
    try {
      final result = await NewsService().translateToVietnamese(widget.text);
      if (mounted) {
        setState(() {
          _translation = result ?? 'Không thể dịch đoạn này';
          _showTranslation = true;
        });
      }
    } finally {
      if (mounted) setState(() => _loadingTranslation = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _showTranslation
              ? c.primary.withValues(alpha: 0.25)
              : c.border.withValues(alpha: 0.3),
          width: _showTranslation ? 1.0 : 0.5,
        ),
      ),
      padding: const EdgeInsets.all(13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: c.primaryBg,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Center(
                  child: Text(
                    '${widget.index + 1}',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: c.primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.text,
                  style: TextStyle(
                    fontSize: 14,
                    color: c.textPrimary,
                    height: 1.55,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: _loadingTranslation ? null : _translate,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_loadingTranslation)
                  SizedBox(
                    width: 13,
                    height: 13,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      color: c.primary,
                    ),
                  )
                else
                  Icon(
                    _showTranslation
                        ? Icons.visibility_off_outlined
                        : Icons.translate_rounded,
                    size: 14,
                    color: c.primary,
                  ),
                const SizedBox(width: 4),
                Text(
                  _loadingTranslation
                      ? 'Đang dịch...'
                      : (_showTranslation ? 'Ẩn bản dịch' : 'Dịch đoạn này'),
                  style: TextStyle(
                    fontSize: 11,
                    color: c.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 200),
            crossFadeState: _showTranslation && _translation != null
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: const SizedBox.shrink(),
            secondChild: _translation == null
                ? const SizedBox.shrink()
                : Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: c.primaryBg.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Text(
                        _translation!,
                        style: TextStyle(
                          fontSize: 13,
                          color: c.textSecondary,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
