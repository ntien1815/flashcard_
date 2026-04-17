import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_colors.dart';
import '../providers/deck_provider.dart';
import '../providers/flashcard_provider.dart';
import '../models/deck.dart';
import '../models/flashcard.dart';
import '../services/firestore_service.dart';
import 'deck_detail_screen.dart';

class DecksTabBody extends StatefulWidget {
  const DecksTabBody({super.key});
  @override
  State<DecksTabBody> createState() => _DecksTabBodyState();
}

class _DecksTabBodyState extends State<DecksTabBody> {
  String _searchQuery = '';
  String _filter = 'all'; // all, system, custom

  AppColors get _c => AppColors.of(context);

  @override
  Widget build(BuildContext context) {
    final c = _c;
    return Consumer<DeckProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading) {
          return Center(child: CircularProgressIndicator(color: c.primary));
        }

        final allDecks = provider.decks;
        final filtered = _applyFilters(allDecks);

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
              child: _buildSearchBar(c),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: _buildFilterChips(c, allDecks),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: filtered.isEmpty
                  ? _buildEmptyState(c)
                  : RefreshIndicator(
                      color: c.primary,
                      onRefresh: () => provider.loadDecks(),
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(14, 0, 14, 100),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _buildDeckCard(c, filtered[index]),
                        ),
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }

  List<Deck> _applyFilters(List<Deck> decks) {
    var result = decks;
    if (_filter == 'system') {
      result = result.where((d) => d.isSystem).toList();
    } else if (_filter == 'custom') {
      result = result.where((d) => !d.isSystem).toList();
    }
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      result = result
          .where(
            (d) =>
                d.name.toLowerCase().contains(q) ||
                (d.description?.toLowerCase().contains(q) ?? false),
          )
          .toList();
    }
    return result;
  }

  Widget _buildSearchBar(AppColors c) {
    return TextField(
      onChanged: (v) => setState(() => _searchQuery = v),
      decoration: InputDecoration(
        hintText: 'Tìm bộ thẻ...',
        hintStyle: TextStyle(fontSize: 14, color: c.textTertiary),
        prefixIcon: Icon(
          Icons.search_rounded,
          size: 20,
          color: c.textSecondary,
        ),
        filled: true,
        fillColor: c.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 10,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: c.border.withValues(alpha: 0.3),
            width: 0.5,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: c.border.withValues(alpha: 0.3),
            width: 0.5,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: c.primary, width: 1.2),
        ),
      ),
    );
  }

  Widget _buildFilterChips(AppColors c, List<Deck> allDecks) {
    final systemCount = allDecks.where((d) => d.isSystem).length;
    final customCount = allDecks.where((d) => !d.isSystem).length;
    return Row(
      children: [
        _filterChip(c, 'all', 'Tất cả (${allDecks.length})'),
        const SizedBox(width: 8),
        _filterChip(c, 'system', 'Hệ thống ($systemCount)'),
        const SizedBox(width: 8),
        _filterChip(c, 'custom', 'Của tôi ($customCount)'),
      ],
    );
  }

  Widget _filterChip(AppColors c, String value, String label) {
    final active = _filter == value;
    return GestureDetector(
      onTap: () => setState(() => _filter = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active ? c.primary : c.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: active ? c.primary : c.border.withValues(alpha: 0.3),
            width: 0.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: active ? Colors.white : c.textSecondary,
          ),
        ),
      ),
    );
  }

  // ─── Deck Card (redesigned) ─────────────────────────────────────────────────
  Widget _buildDeckCard(AppColors c, Deck deck) {
    final colors = [c.primary, c.teal, c.amber, c.coral];
    final bgColors = [c.primaryBg, c.tealBg, c.amberBg, c.coralBg];
    final icons = [
      Icons.menu_book_rounded,
      Icons.chat_bubble_outline_rounded,
      Icons.business_center_outlined,
      Icons.science_outlined,
    ];
    final idx = deck.name.hashCode.abs() % 4;
    final accent = colors[idx];
    final bg = bgColors[idx];
    final icon = icons[idx];
    final progress = deck.cardCount > 0
        ? (deck.cardCount - deck.dueCount) / deck.cardCount
        : 0.0;

    return GestureDetector(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => DeckDetailScreen(deck: deck)),
        );
        if (mounted) context.read<DeckProvider>().loadDecks();
      },
      child: Container(
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: c.border.withValues(alpha: 0.3),
            width: 0.5,
          ),
        ),
        child: Column(
          children: [
            // ── Header strip ──
            Container(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
              decoration: BoxDecoration(
                color: bg.withValues(alpha: 0.5),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Icon(icon, color: accent, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          deck.name,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: c.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (deck.description != null &&
                            deck.description!.isNotEmpty)
                          Text(
                            deck.description!,
                            style: TextStyle(
                              fontSize: 11,
                              color: c.textSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  if (deck.isSystem)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: c.primaryBg,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Hệ thống',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: c.primary,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // ── Stats row ──
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
              child: Column(
                children: [
                  Row(
                    children: [
                      _statPill(
                        c,
                        Icons.style_rounded,
                        '${deck.cardCount} thẻ',
                        accent,
                        bg,
                      ),
                      const SizedBox(width: 8),
                      if (deck.dueCount > 0)
                        _statPill(
                          c,
                          Icons.schedule_rounded,
                          '${deck.dueCount} đến hạn',
                          c.coral,
                          c.coralBg,
                        )
                      else
                        _statPill(
                          c,
                          Icons.check_circle_outline_rounded,
                          'Đã ôn xong',
                          c.teal,
                          c.tealBg,
                        ),
                      const Spacer(),
                      // Nút thêm/xóa từ (chỉ cho deck không phải hệ thống)
                      if (!deck.isSystem)
                        GestureDetector(
                          onTap: () => _showAddFromLibrary(deck),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: c.primaryBg,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.library_add_rounded,
                                  size: 13,
                                  color: c.primary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Thêm từ',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: c.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Progress bar
                  Column(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 5,
                          backgroundColor: c.bodyBg,
                          color: accent,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Tiến độ',
                            style: TextStyle(
                              fontSize: 9,
                              color: c.textTertiary,
                            ),
                          ),
                          Text(
                            '${(progress * 100).round()}%',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                              color: accent,
                            ),
                          ),
                        ],
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

  Widget _statPill(
    AppColors c,
    IconData icon,
    String label,
    Color color,
    Color bg,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(7),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(AppColors c) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off_rounded, size: 48, color: c.textTertiary),
          const SizedBox(height: 12),
          Text(
            _searchQuery.isNotEmpty
                ? 'Không tìm thấy bộ thẻ'
                : 'Chưa có bộ thẻ nào',
            style: TextStyle(fontSize: 14, color: c.textSecondary),
          ),
          const SizedBox(height: 4),
          Text(
            _searchQuery.isNotEmpty
                ? 'Thử từ khóa khác'
                : 'Tạo bộ thẻ đầu tiên nhé!',
            style: TextStyle(fontSize: 12, color: c.textTertiary),
          ),
        ],
      ),
    );
  }

  // ─── Add From Library Flow ─────────────────────────────────────────────────
  void _showAddFromLibrary(Deck targetDeck) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddFromLibrarySheet(targetDeck: targetDeck),
    ).then((_) {
      if (mounted) context.read<DeckProvider>().loadDecks();
    });
  }
}

// ─── Add From Library Sheet ───────────────────────────────────────────────────
class _AddFromLibrarySheet extends StatefulWidget {
  final Deck targetDeck;
  const _AddFromLibrarySheet({required this.targetDeck});

  @override
  State<_AddFromLibrarySheet> createState() => _AddFromLibrarySheetState();
}

class _AddFromLibrarySheetState extends State<_AddFromLibrarySheet> {
  AppColors get _c => AppColors.of(context);

  // Bước 1: chọn bộ thẻ nguồn (hệ thống)
  // Bước 2: chọn từ trong bộ đó
  int _step = 1;
  Deck? _sourceDeck;
  List<Flashcard> _sourceCards = [];
  List<Flashcard> _existingCards = []; // cards đã có trong targetDeck
  final Set<String> _selectedIds = {};
  bool _loading = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadExistingCards();
  }

  Future<void> _loadExistingCards() async {
    try {
      final fs = FirestoreService();
      final cards = await fs.getFlashcardsByDeck(widget.targetDeck.id!);
      if (mounted) setState(() => _existingCards = cards);
    } catch (e) {
      debugPrint('[AddFromLibrary] loadExisting error: $e');
    }
  }

  Future<void> _selectSourceDeck(Deck deck) async {
    setState(() {
      _loading = true;
      _sourceDeck = deck;
      _step = 2;
      _selectedIds.clear();
      _searchQuery = '';
    });
    try {
      final fs = FirestoreService();
      final cards = await fs.getFlashcardsByDeck(deck.id!);
      if (mounted) setState(() => _sourceCards = cards);
    } catch (e) {
      debugPrint('[AddFromLibrary] loadSource error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _addSelected() async {
    if (_selectedIds.isEmpty) return;
    setState(() => _loading = true);
    try {
      final fs = FirestoreService();
      int added = 0;
      for (final card in _sourceCards) {
        if (_selectedIds.contains(card.id)) {
          // Kiểm tra đã tồn tại chưa
          final alreadyExists = _existingCards.any(
            (e) => e.front.toLowerCase() == card.front.toLowerCase(),
          );
          if (!alreadyExists) {
            final newCard = Flashcard(
              deckId: widget.targetDeck.id!,
              front: card.front,
              back: card.back,
              pronunciation: card.pronunciation,
              example: card.example,
            );
            await fs.insertFlashcard(newCard);
            added++;
          }
        }
      }
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              added > 0
                  ? 'Đã thêm $added từ vào bộ thẻ'
                  : 'Các từ này đã có trong bộ thẻ của bạn',
            ),
            backgroundColor: added > 0 ? _c.teal : _c.amber,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      debugPrint('[AddFromLibrary] addSelected error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _removeCard(Flashcard card) async {
    // Xóa từ targetDeck (chỉ những từ đã add, không phải từ hệ thống)
    try {
      await context.read<FlashcardProvider>().deleteFlashcard(
        card.id!,
        widget.targetDeck.id!,
      );
      setState(() => _existingCards.removeWhere((c) => c.id == card.id));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã xóa "${card.front}" khỏi bộ thẻ'),
            backgroundColor: _c.coral,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      debugPrint('[AddFromLibrary] removeCard error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _c;
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (_, scrollController) => Container(
        decoration: BoxDecoration(
          color: c.bodyBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: c.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                children: [
                  if (_step == 2)
                    GestureDetector(
                      onTap: () => setState(() {
                        _step = 1;
                        _sourceDeck = null;
                        _sourceCards = [];
                        _selectedIds.clear();
                      }),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: c.surface,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.arrow_back_ios_new_rounded,
                          size: 14,
                          color: c.textSecondary,
                        ),
                      ),
                    ),
                  if (_step == 2) const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _step == 1
                              ? 'Thêm từ vào "${widget.targetDeck.name}"'
                              : _sourceDeck?.name ?? '',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: c.textPrimary,
                          ),
                        ),
                        Text(
                          _step == 1
                              ? 'Chọn bộ thẻ nguồn'
                              : '${_selectedIds.length} từ được chọn',
                          style: TextStyle(
                            fontSize: 12,
                            color: c.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_step == 2 && _selectedIds.isNotEmpty)
                    FilledButton(
                      onPressed: _loading ? null : _addSelected,
                      style: FilledButton.styleFrom(
                        backgroundColor: c.primary,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text(
                        'Thêm (${_selectedIds.length})',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Divider(height: 1, color: c.border.withValues(alpha: 0.5)),
            if (_loading)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else if (_step == 1)
              _buildStep1(scrollController)
            else
              _buildStep2(scrollController),
          ],
        ),
      ),
    );
  }

  // Bước 1: Chọn bộ thẻ nguồn
  Widget _buildStep1(ScrollController scrollController) {
    final c = _c;
    return Consumer<DeckProvider>(
      builder: (context, provider, _) {
        // Hiện tất cả deck (kể cả hệ thống) trừ chính targetDeck
        final sourceable = provider.decks
            .where((d) => d.id != widget.targetDeck.id)
            .toList();

        if (sourceable.isEmpty) {
          return Expanded(
            child: Center(
              child: Text(
                'Không có bộ thẻ nào để chọn',
                style: TextStyle(fontSize: 13, color: c.textSecondary),
              ),
            ),
          );
        }

        return Expanded(
          child: ListView.builder(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            itemCount: sourceable.length,
            itemBuilder: (context, i) {
              final deck = sourceable[i];
              final colors = [c.primary, c.teal, c.amber, c.coral];
              final bgs = [c.primaryBg, c.tealBg, c.amberBg, c.coralBg];
              final idx = deck.name.hashCode.abs() % 4;
              final accent = colors[idx];
              final bg = bgs[idx];
              return GestureDetector(
                onTap: () => _selectSourceDeck(deck),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: c.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: c.border.withValues(alpha: 0.3),
                      width: 0.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: bg,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.layers_rounded,
                          color: accent,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              deck.name,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: c.textPrimary,
                              ),
                            ),
                            Text(
                              '${deck.cardCount} từ${deck.isSystem ? ' · Hệ thống' : ''}',
                              style: TextStyle(
                                fontSize: 11,
                                color: c.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 18,
                        color: c.textTertiary,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  // Bước 2: Chọn từ trong bộ nguồn
  Widget _buildStep2(ScrollController scrollController) {
    final c = _c;
    // Lọc những từ chưa có trong targetDeck
    final existingFronts = _existingCards
        .map((e) => e.front.toLowerCase())
        .toSet();
    final available = _sourceCards
        .where((card) => !existingFronts.contains(card.front.toLowerCase()))
        .toList();
    final filtered = _searchQuery.isEmpty
        ? available
        : available.where((card) {
            final q = _searchQuery.toLowerCase();
            return card.front.toLowerCase().contains(q) ||
                card.back.toLowerCase().contains(q);
          }).toList();

    return Expanded(
      child: Column(
        children: [
          // Search
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
            child: TextField(
              onChanged: (v) => setState(() => _searchQuery = v),
              decoration: InputDecoration(
                hintText: 'Tìm từ...',
                hintStyle: TextStyle(fontSize: 13, color: c.textTertiary),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  size: 18,
                  color: c.textSecondary,
                ),
                filled: true,
                fillColor: c.surface,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 9,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(
                    color: c.border.withValues(alpha: 0.3),
                    width: 0.5,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(
                    color: c.border.withValues(alpha: 0.3),
                    width: 0.5,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: c.primary, width: 1),
                ),
              ),
            ),
          ),
          // Tabs: Thêm / Quản lý đã có
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _buildTabBar(c, available.length),
          ),
          const SizedBox(height: 8),
          // List
          Expanded(
            child: _showManage
                ? _buildManageList(scrollController)
                : _buildSelectList(scrollController, filtered),
          ),
        ],
      ),
    );
  }

  bool _showManage = false;

  Widget _buildTabBar(AppColors c, int availableCount) {
    return Row(
      children: [
        _tab(
          c,
          'Thêm từ ($availableCount)',
          !_showManage,
          () => setState(() => _showManage = false),
        ),
        const SizedBox(width: 8),
        _tab(
          c,
          'Đã có (${_existingCards.length})',
          _showManage,
          () => setState(() => _showManage = true),
        ),
      ],
    );
  }

  Widget _tab(AppColors c, String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: active ? c.primary : c.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: active ? c.primary : c.border.withValues(alpha: 0.3),
            width: 0.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: active ? Colors.white : c.textSecondary,
          ),
        ),
      ),
    );
  }

  // List từ có thể thêm
  Widget _buildSelectList(
    ScrollController scrollController,
    List<Flashcard> filtered,
  ) {
    final c = _c;
    if (filtered.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _searchQuery.isNotEmpty
                ? 'Không tìm thấy từ nào'
                : 'Tất cả từ đã có trong bộ thẻ của bạn',
            style: TextStyle(fontSize: 13, color: c.textSecondary),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
      itemCount: filtered.length,
      itemBuilder: (context, i) {
        final card = filtered[i];
        final isSelected = _selectedIds.contains(card.id);
        return GestureDetector(
          onTap: () {
            setState(() {
              if (isSelected) {
                _selectedIds.remove(card.id);
              } else {
                _selectedIds.add(card.id!);
              }
            });
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: isSelected ? c.primaryBg : c.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? c.primary.withValues(alpha: 0.4)
                    : c.border.withValues(alpha: 0.3),
                width: isSelected ? 1.0 : 0.5,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: isSelected ? c.primary : c.bodyBg,
                    borderRadius: BorderRadius.circular(6),
                    border: isSelected
                        ? null
                        : Border.all(color: c.border, width: 0.5),
                  ),
                  child: isSelected
                      ? const Icon(
                          Icons.check_rounded,
                          size: 14,
                          color: Colors.white,
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        card.front,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: isSelected ? c.primary : c.textPrimary,
                        ),
                      ),
                      if (card.pronunciation != null &&
                          card.pronunciation!.isNotEmpty)
                        Text(
                          card.pronunciation!,
                          style: TextStyle(
                            fontSize: 11,
                            color: c.textSecondary,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      Text(
                        card.back,
                        style: TextStyle(fontSize: 12, color: c.textSecondary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // List từ đã có trong targetDeck (để xóa)
  Widget _buildManageList(ScrollController scrollController) {
    final c = _c;
    if (_existingCards.isEmpty) {
      return Center(
        child: Text(
          'Bộ thẻ chưa có từ nào',
          style: TextStyle(fontSize: 13, color: c.textSecondary),
        ),
      );
    }
    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
      itemCount: _existingCards.length,
      itemBuilder: (context, i) {
        final card = _existingCards[i];
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: c.border.withValues(alpha: 0.3),
              width: 0.5,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      card.front,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: c.textPrimary,
                      ),
                    ),
                    if (card.pronunciation != null &&
                        card.pronunciation!.isNotEmpty)
                      Text(
                        card.pronunciation!,
                        style: TextStyle(
                          fontSize: 11,
                          color: c.textSecondary,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    Text(
                      card.back,
                      style: TextStyle(fontSize: 12, color: c.textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => _confirmRemove(card),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: c.coralBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.delete_outline_rounded,
                    size: 16,
                    color: c.coral,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _confirmRemove(Flashcard card) {
    final c = _c;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Xóa từ?',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: c.textPrimary,
          ),
        ),
        content: Text(
          'Xóa "${card.front}" khỏi bộ thẻ? Hành động này không thể hoàn tác.',
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
            onPressed: () {
              Navigator.pop(ctx);
              _removeCard(card);
            },
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
  }
}
