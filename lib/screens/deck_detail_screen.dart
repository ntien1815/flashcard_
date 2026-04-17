import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
import '../models/deck.dart';
import '../models/flashcard.dart';
import '../providers/deck_provider.dart';
import '../providers/flashcard_provider.dart';
import '../services/firestore_service.dart';
import '../theme/app_colors.dart';
import 'add_card_screen.dart';
import 'study_screen.dart';

class DeckDetailScreen extends StatefulWidget {
  final Deck deck;
  const DeckDetailScreen({super.key, required this.deck});

  @override
  State<DeckDetailScreen> createState() => _DeckDetailScreenState();
}

class _DeckDetailScreenState extends State<DeckDetailScreen> {
  final FirestoreService _fs = FirestoreService();
  bool _isImporting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _reload());
  }

  Future<void> _reload() async {
    try {
      final fp = context.read<FlashcardProvider>();
      final dp = context.read<DeckProvider>();
      await fp.loadFlashcards(widget.deck.id!);
      await dp.loadDecks();
    } catch (e) {
      debugPrint('[DeckDetail] reload error: $e');
    }
  }

  Future<void> _goStudy() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            StudyScreen(deckId: widget.deck.id!, deckName: widget.deck.name),
      ),
    );
    if (mounted) await _reload();
  }

  Future<void> _goAddCard() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AddCardScreen(deckId: widget.deck.id!)),
    );
    if (mounted) await _reload();
  }

  // ─── CSV Import ────────────────────────────────────────────────────────────

  Future<void> _importCsv() async {
    try {
      // 1. Chọn file
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;

      final bytes = result.files.first.bytes;
      if (bytes == null) {
        if (mounted) {
          _showSnackBar('Không đọc được file', isError: true);
        }
        return;
      }

      setState(() => _isImporting = true);

      // 2. Decode UTF-8
      final csvString = utf8.decode(bytes, allowMalformed: true);

      // 3. Parse CSV
      final rows = CsvCodec().decoder.convert(csvString);

      if (rows.isEmpty) {
        setState(() => _isImporting = false);
        if (mounted) _showSnackBar('File CSV trống', isError: true);
        return;
      }

      // 4. Tìm header → xác định cột
      final header = rows.first
          .map((e) => e.toString().trim().toLowerCase())
          .toList();
      final frontIdx = _findColumn(header, [
        'front',
        'từ',
        'word',
        'english',
        'tiếng anh',
      ]);
      final backIdx = _findColumn(header, [
        'back',
        'nghĩa',
        'meaning',
        'vietnamese',
        'tiếng việt',
      ]);
      final pronIdx = _findColumn(header, [
        'pronunciation',
        'phát âm',
        'phonetic',
        'ipa',
      ]);
      final exIdx = _findColumn(header, [
        'example',
        'ví dụ',
        'câu ví dụ',
        'sentence',
      ]);

      if (frontIdx == -1 || backIdx == -1) {
        setState(() => _isImporting = false);
        if (mounted) {
          _showSnackBar(
            'CSV cần có cột "front" và "back" (hoặc "từ" và "nghĩa")',
            isError: true,
          );
        }
        return;
      }

      // 5. Insert từng thẻ (bỏ qua header)
      int success = 0;
      int skipped = 0;
      final deckId = widget.deck.id!;

      for (int i = 1; i < rows.length; i++) {
        final row = rows[i];
        final front = _cellValue(row, frontIdx);
        final back = _cellValue(row, backIdx);

        if (front.isEmpty || back.isEmpty) {
          skipped++;
          continue;
        }

        final pron = pronIdx != -1 ? _cellValue(row, pronIdx) : '';
        final example = exIdx != -1 ? _cellValue(row, exIdx) : '';

        try {
          final card = Flashcard(
            deckId: deckId,
            front: front,
            back: back,
            pronunciation: pron.isNotEmpty ? pron : null,
            example: example.isNotEmpty ? example : null,
          );
          await _fs.insertFlashcard(card);
          success++;
        } catch (e) {
          debugPrint('[CSV import] row $i error: $e');
          skipped++;
        }
      }

      setState(() => _isImporting = false);
      if (mounted) {
        await _reload();
        _showImportResult(success, skipped);
      }
    } catch (e) {
      debugPrint('[CSV import] error: $e');
      setState(() => _isImporting = false);
      if (mounted) {
        _showSnackBar('Lỗi khi nhập CSV: $e', isError: true);
      }
    }
  }

  int _findColumn(List<String> header, List<String> aliases) {
    for (int i = 0; i < header.length; i++) {
      if (aliases.contains(header[i])) return i;
    }
    return -1;
  }

  String _cellValue(List<dynamic> row, int index) {
    if (index >= row.length) return '';
    return row[index].toString().trim();
  }

  void _showSnackBar(String msg, {bool isError = false}) {
    final c = AppColors.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? c.error : c.teal,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showImportResult(int success, int skipped) {
    final c = AppColors.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: c.tealBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.check_circle_rounded, color: c.teal, size: 20),
            ),
            const SizedBox(width: 10),
            Text(
              'Nhập CSV xong',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: c.textPrimary,
              ),
            ),
          ],
        ),
        content: Text(
          'Đã nhập thành công $success thẻ.'
          '${skipped > 0 ? '\nBỏ qua $skipped dòng (thiếu dữ liệu).' : ''}',
          style: TextStyle(fontSize: 13, color: c.textSecondary),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            style: FilledButton.styleFrom(
              backgroundColor: c.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  // ─── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Scaffold(
      backgroundColor: c.bodyBg,
      body: Stack(
        children: [
          RefreshIndicator(
            color: c.primary,
            onRefresh: _reload,
            child: Consumer<FlashcardProvider>(
              builder: (context, provider, _) {
                if (provider.isLoading) {
                  return CustomScrollView(
                    slivers: [
                      _buildSliverAppBar(0, 0),
                      SliverFillRemaining(
                        child: Center(
                          child: CircularProgressIndicator(color: c.primary),
                        ),
                      ),
                    ],
                  );
                }

                final cards = provider.flashcards;
                final dueCount = provider.dueCount;

                return CustomScrollView(
                  slivers: [
                    _buildSliverAppBar(cards.length, dueCount),
                    if (cards.isEmpty)
                      SliverFillRemaining(child: _buildEmptyState())
                    else ...[
                      if (dueCount > 0)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
                            child: _buildStudyBanner(dueCount),
                          ),
                        ),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(14, 16, 14, 8),
                          child: Row(
                            children: [
                              Text(
                                'Danh sách thẻ'.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                  color: c.textSecondary,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                '${cards.length} thẻ',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: c.textTertiary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(14, 0, 14, 100),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: _FlashcardTile(
                                card: cards[index],
                                deckId: widget.deck.id!,
                                index: index,
                                isSystemDeck: widget.deck.isSystem,
                                onDeleted: _reload,
                              ),
                            ),
                            childCount: cards.length,
                          ),
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
          // Loading overlay khi đang import
          if (_isImporting)
            Container(
              color: Colors.black.withValues(alpha: 0.3),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: c.surface,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: c.primary),
                      const SizedBox(height: 16),
                      Text(
                        'Đang nhập thẻ từ CSV...',
                        style: TextStyle(fontSize: 13, color: c.textSecondary),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: widget.deck.isSystem ? null : _buildFab(),
    );
  }

  // ─── Sliver AppBar ─────────────────────────────────────────────────────────
  SliverAppBar _buildSliverAppBar(int cardCount, int dueCount) {
    final c = AppColors.of(context);
    final deckColor = _parseDeckColor(widget.deck.color);
    final learnedCount = cardCount > 0 ? cardCount - dueCount : 0;
    final progress = cardCount > 0 ? learnedCount / cardCount : 0.0;

    return SliverAppBar(
      expandedHeight: 185,
      pinned: true,
      backgroundColor: c.primary,
      leading: IconButton(
        icon: Icon(
          Icons.arrow_back_ios_new_rounded,
          color: c.primaryLighter,
          size: 18,
        ),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        PopupMenuButton<String>(
          icon: Icon(Icons.more_vert_rounded, color: c.primaryLighter),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          onSelected: (value) {
            if (value == 'study_all') {
              _goStudy();
            } else if (value == 'import_csv') {
              _importCsv();
            }
          },
          itemBuilder: (_) => [
            PopupMenuItem(
              value: 'study_all',
              child: Row(
                children: [
                  Icon(Icons.play_arrow_rounded, size: 18, color: c.primary),
                  const SizedBox(width: 8),
                  const Text('Học tất cả'),
                ],
              ),
            ),
            // Chỉ hiện nhập CSV cho deck không phải hệ thống
            if (!widget.deck.isSystem)
              PopupMenuItem(
                value: 'import_csv',
                child: Row(
                  children: [
                    Icon(Icons.upload_file_rounded, size: 18, color: c.primary),
                    const SizedBox(width: 8),
                    const Text('Nhập CSV'),
                  ],
                ),
              ),
          ],
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [c.primary, c.primaryDark],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 56, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: Icon(
                          Icons.menu_book_rounded,
                          color: deckColor,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          widget.deck.name,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  if (widget.deck.description != null &&
                      widget.deck.description!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Padding(
                      padding: const EdgeInsets.only(left: 46),
                      child: Text(
                        widget.deck.description!,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.65),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      _buildStatChip(
                        '$cardCount',
                        'tổng thẻ',
                        Colors.white.withValues(alpha: 0.12),
                        Colors.white,
                      ),
                      const SizedBox(width: 8),
                      _buildStatChip(
                        '$dueCount',
                        'đến hạn',
                        dueCount > 0
                            ? c.coral.withValues(alpha: 0.25)
                            : Colors.white.withValues(alpha: 0.12),
                        dueCount > 0 ? const Color(0xFFFFB4A0) : Colors.white,
                      ),
                      const SizedBox(width: 8),
                      _buildStatChip(
                        '$learnedCount',
                        'đã thuộc',
                        c.teal.withValues(alpha: 0.25),
                        const Color(0xFFA0E8D0),
                      ),
                      const Spacer(),
                      SizedBox(
                        width: 36,
                        height: 36,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            CircularProgressIndicator(
                              value: progress,
                              strokeWidth: 3.5,
                              backgroundColor: Colors.white.withValues(
                                alpha: 0.12,
                              ),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                c.primaryLight,
                              ),
                            ),
                            Text(
                              '${(progress * 100).round()}%',
                              style: const TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatChip(String value, String label, Color bg, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: textColor.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudyBanner(int dueCount) {
    final c = AppColors.of(context);
    return GestureDetector(
      onTap: _goStudy,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [const Color(0xFF6C5FD7), c.primary],
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: c.primary.withValues(alpha: 0.25),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.play_arrow_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Bắt đầu ôn tập',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    '$dueCount thẻ đang chờ bạn hôm nay',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              color: Colors.white.withValues(alpha: 0.6),
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final c = AppColors.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: c.primaryBg,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(
                Icons.style_outlined,
                size: 36,
                color: c.primaryLight,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Chưa có thẻ nào',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: c.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Thêm thẻ đầu tiên để bắt đầu học nhé!',
              style: TextStyle(fontSize: 13, color: c.textSecondary),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _goAddCard,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Thêm thẻ mới'),
              style: FilledButton.styleFrom(
                backgroundColor: c.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFab() {
    final c = AppColors.of(context);
    return FloatingActionButton(
      onPressed: _goAddCard,
      backgroundColor: c.primary,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: const Icon(Icons.add_rounded, color: Colors.white, size: 26),
    );
  }

  Color _parseDeckColor(String? hex) {
    final c = AppColors.of(context);
    if (hex == null || hex.isEmpty) return c.primaryLight;
    try {
      final colorHex = hex.replaceFirst('#', '');
      return Color(int.parse('FF$colorHex', radix: 16));
    } catch (_) {
      return c.primaryLight;
    }
  }
}

// ─── FlashcardTile (giữ nguyên) ──────────────────────────────────────────────
class _FlashcardTile extends StatefulWidget {
  final Flashcard card;
  final String deckId;
  final int index;
  final bool isSystemDeck;
  final VoidCallback onDeleted;

  const _FlashcardTile({
    required this.card,
    required this.deckId,
    required this.index,
    this.isSystemDeck = false,
    required this.onDeleted,
  });

  @override
  State<_FlashcardTile> createState() => _FlashcardTileState();
}

class _FlashcardTileState extends State<_FlashcardTile> {
  bool _isFlipped = false;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final isDue = !widget.card.nextReview.isAfter(DateTime.now());
    final isLearned = widget.card.isLearned;

    return GestureDetector(
      onTap: () => setState(() => _isFlipped = !_isFlipped),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _isFlipped
                ? c.primary.withValues(alpha: 0.25)
                : c.border.withValues(alpha: 0.3),
            width: _isFlipped ? 1.0 : 0.5,
          ),
        ),
        padding: const EdgeInsets.all(13),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: isDue ? c.coralBg : c.tealBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    isDue
                        ? Icons.schedule_rounded
                        : Icons.check_circle_outline_rounded,
                    color: isDue ? c.coral : c.teal,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.card.front,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: c.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (widget.card.pronunciation != null &&
                          widget.card.pronunciation!.isNotEmpty)
                        Text(
                          widget.card.pronunciation!,
                          style: TextStyle(
                            fontSize: 11,
                            color: c.primary,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                    ],
                  ),
                ),
                if (isDue)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: c.coralBg,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Đến hạn',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w500,
                        color: c.coral,
                      ),
                    ),
                  )
                else if (isLearned)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: c.tealBg,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Đã thuộc',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w500,
                        color: c.teal,
                      ),
                    ),
                  ),
                const SizedBox(width: 4),
                if (!widget.isSystemDeck)
                  GestureDetector(
                    onTap: () => _confirmDelete(context),
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.delete_outline_rounded,
                        color: c.textTertiary,
                        size: 17,
                      ),
                    ),
                  ),
              ],
            ),
            AnimatedCrossFade(
              duration: const Duration(milliseconds: 250),
              crossFadeState: _isFlipped
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              firstChild: Padding(
                padding: const EdgeInsets.only(left: 42, top: 2),
                child: Text(
                  'Nhấn để xem nghĩa',
                  style: TextStyle(fontSize: 11, color: c.textTertiary),
                ),
              ),
              secondChild: Container(
                width: double.infinity,
                margin: const EdgeInsets.only(top: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: c.primaryBg.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.card.back,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: c.primary,
                      ),
                    ),
                    if (widget.card.example != null &&
                        widget.card.example!.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        widget.card.example!,
                        style: TextStyle(
                          fontSize: 12,
                          color: c.textSecondary,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          Icons.repeat_rounded,
                          size: 11,
                          color: c.textTertiary,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          'Đã ôn ${widget.card.reviewCount} lần',
                          style: TextStyle(fontSize: 10, color: c.textTertiary),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    final c = AppColors.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Xoá thẻ?',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: c.textPrimary,
          ),
        ),
        content: Text(
          'Xoá "${widget.card.front}" khỏi bộ thẻ? Hành động này không thể hoàn tác.',
          style: TextStyle(fontSize: 13, color: c.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Huỷ', style: TextStyle(color: c.textSecondary)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: c.error,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await context.read<FlashcardProvider>().deleteFlashcard(
                  widget.card.id!,
                  widget.deckId,
                );
                widget.onDeleted();
              } catch (e) {
                debugPrint('[FlashcardTile] delete error: $e');
              }
            },
            child: const Text('Xoá'),
          ),
        ],
      ),
    );
  }
}
