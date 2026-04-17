import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../providers/deck_provider.dart';
import '../models/flashcard.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../services/notification_service.dart';
import '../models/user_model.dart';
import '../main.dart';
import '../theme/app_colors.dart';
import 'add_deck_screen.dart';
import 'stats_screen.dart';
import 'decks_tab_screen.dart';
import 'profile_screen.dart';
import 'reading_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentNavIndex = 0;
  UserModel? _userModel;

  // Dữ liệu từ hot (top review)
  List<Flashcard> _hotCards = [];
  bool _loadingHot = false;

  // Search
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  List<Flashcard> _searchResults = [];
  List<Flashcard> _allCards = [];
  bool _loadingSearch = false;
  final FocusNode _searchFocusNode = FocusNode();

  AppColors get _c => AppColors.of(context);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final deckFuture = context.read<DeckProvider>().loadDecks();
    final userFuture = FirestoreService().getOrCreateUser().then<UserModel?>(
      (u) => u,
      onError: (e) {
        debugPrint('[HomeScreen] loadUser error: $e');
        return null;
      },
    );
    final results = await Future.wait([deckFuture, userFuture]);
    final user = results[1] as UserModel?;
    if (mounted && user != null) setState(() => _userModel = user);

    // Load all cards for search
    await _loadAllCards();
    // Load hot cards
    await _loadHotCards();
  }

  Future<void> _loadAllCards() async {
    if (!mounted) return;
    setState(() => _loadingSearch = true);
    try {
      final fs = FirestoreService();
      final decks = context.read<DeckProvider>().decks;
      final List<Flashcard> all = [];
      for (final deck in decks) {
        if (deck.id != null) {
          final cards = await fs.getFlashcardsByDeck(deck.id!);
          all.addAll(cards);
        }
      }
      if (mounted) setState(() => _allCards = all);
    } catch (e) {
      debugPrint('[HomeScreen] loadAllCards error: $e');
    } finally {
      if (mounted) setState(() => _loadingSearch = false);
    }
  }

  Future<void> _loadHotCards() async {
    if (!mounted) return;
    setState(() => _loadingHot = true);
    try {
      final fs = FirestoreService();
      // Lấy study_logs 30 ngày, tính top cardId được review nhiều nhất
      final logs = await fs.getStudyLogs(lastNDays: 30);
      final Map<String, int> countMap = {};
      for (final log in logs) {
        countMap[log.cardId] = (countMap[log.cardId] ?? 0) + 1;
      }
      // Sort by count desc, lấy top 10 cardId
      final topIds = countMap.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      final topCardIds = topIds.take(10).map((e) => e.key).toSet();

      // Filter từ allCards
      final hot = _allCards.where((c) => topCardIds.contains(c.id)).toList();

      // Nếu chưa đủ 5 thẻ, bổ sung từ allCards
      if (hot.length < 5 && _allCards.isNotEmpty) {
        for (final card in _allCards) {
          if (!hot.any((h) => h.id == card.id)) {
            hot.add(card);
          }
          if (hot.length >= 10) break;
        }
      }

      if (mounted) setState(() => _hotCards = hot);
    } catch (e) {
      debugPrint('[HomeScreen] loadHotCards error: $e');
    } finally {
      if (mounted) setState(() => _loadingHot = false);
    }
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
      if (query.trim().isEmpty) {
        _searchResults = [];
      } else {
        final q = query.toLowerCase();
        _searchResults = _allCards
            .where(
              (c) =>
                  c.front.toLowerCase().contains(q) ||
                  c.back.toLowerCase().contains(q) ||
                  (c.pronunciation?.toLowerCase().contains(q) ?? false),
            )
            .take(20)
            .toList();
      }
    });
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Chào buổi sáng,';
    if (h < 18) return 'Chào buổi chiều,';
    return 'Chào buổi tối,';
  }

  String _displayName() {
    final user = FirebaseAuth.instance.currentUser;
    final name = user?.displayName ?? user?.email ?? 'Bạn';
    return name.split(' ').last;
  }

  String _initials() {
    final name = FirebaseAuth.instance.currentUser?.displayName ?? '';
    if (name.isEmpty) return '?';
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return name[0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final c = _c;
    return Scaffold(
      backgroundColor: c.bodyBg,
      appBar: _buildAppBar(),
      body: switch (_currentNavIndex) {
        1 => const DecksTabBody(),
        2 => const ReadingScreen(),
        3 => const StatsBody(),
        4 => const ProfileBody(),
        _ => RefreshIndicator(
          color: c.primary,
          onRefresh: _loadData,
          child: _buildBody(),
        ),
      },
      bottomNavigationBar: _buildBottomNav(),
      floatingActionButton: _currentNavIndex == 1 ? _buildFab() : null,
    );
  }

  PreferredSizeWidget _buildAppBar() {
    final c = _c;
    final titles = {
      1: 'Bộ thẻ',
      2: 'Luyện đọc',
      3: 'Thống kê học tập',
      4: 'Hồ sơ',
    };
    if (titles.containsKey(_currentNavIndex)) {
      return AppBar(
        backgroundColor: c.primary,
        elevation: 0,
        automaticallyImplyLeading: false,
        toolbarHeight: 64,
        title: Text(
          titles[_currentNavIndex]!,
          style: const TextStyle(
            fontSize: 18,
            color: Colors.white,
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    }

    return AppBar(
      backgroundColor: c.primary,
      elevation: 0,
      automaticallyImplyLeading: false,
      toolbarHeight: 64,
      title: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _greeting(),
                  style: TextStyle(
                    fontSize: 12,
                    color: c.primaryLighter,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  _displayName(),
                  style: const TextStyle(
                    fontSize: 18,
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: _showProfileMenu,
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: c.primaryLight,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  _initials(),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: c.primaryDark,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showProfileMenu() {
    final themeProvider = context.read<ThemeProvider>();
    final c = _c;
    showModalBottomSheet(
      context: context,
      backgroundColor: c.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: c.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: Icon(
                themeProvider.isDark
                    ? Icons.dark_mode_rounded
                    : Icons.light_mode_rounded,
                color: c.primary,
              ),
              title: Text(
                'Chế độ tối',
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: c.textPrimary,
                ),
              ),
              trailing: Switch(
                value: themeProvider.isDark,
                activeThumbColor: c.primary,
                onChanged: (_) => themeProvider.toggle(),
              ),
              onTap: () => themeProvider.toggle(),
            ),
            ListTile(
              leading: Icon(Icons.notifications_outlined, color: c.primary),
              title: Text(
                'Nhắc nhở học tập',
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: c.textPrimary,
                ),
              ),
              trailing: Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: c.textTertiary,
              ),
              onTap: () {
                Navigator.pop(context);
                _showNotificationSettings();
              },
            ),
            Divider(height: 1, color: c.border),
            ListTile(
              leading: Icon(Icons.logout_rounded, color: c.error),
              title: Text(
                'Đăng xuất',
                style: TextStyle(color: c.error, fontWeight: FontWeight.w500),
              ),
              onTap: () async {
                Navigator.pop(context);
                await AuthService().signOut();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showNotificationSettings() {
    final c = _c;
    showModalBottomSheet(
      context: context,
      backgroundColor: c.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) =>
          _NotificationSettingsSheet(notifService: NotificationService()),
    );
  }

  Widget _buildBody() {
    final c = _c;
    return Consumer<DeckProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading) {
          return Center(child: CircularProgressIndicator(color: c.primary));
        }
        return GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              // ── Streak Banner ──
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
                child: _buildStreakBanner(provider.totalDueCards),
              ),
              const SizedBox(height: 14),

              // ── Search Bar ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: _buildSearchBar(),
              ),
              const SizedBox(height: 4),

              // ── Search Results (overlay-style) ──
              if (_searchQuery.isNotEmpty)
                _buildSearchResults()
              else ...[
                const SizedBox(height: 14),
                // ── Feature Cards ──
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: _buildFeatureCards(),
                ),
                const SizedBox(height: 20),
                // ── Hot Words ──
                _buildHotSection(),
                const SizedBox(height: 80),
              ],
            ],
          ),
        );
      },
    );
  }

  // ─── Search Bar ────────────────────────────────────────────────────────────
  Widget _buildSearchBar() {
    final c = _c;
    return TextField(
      controller: _searchController,
      focusNode: _searchFocusNode,
      onChanged: _onSearchChanged,
      decoration: InputDecoration(
        hintText: 'Tra từ vựng...',
        hintStyle: TextStyle(fontSize: 14, color: c.textTertiary),
        prefixIcon: Icon(
          Icons.search_rounded,
          size: 20,
          color: c.textSecondary,
        ),
        suffixIcon: _searchQuery.isNotEmpty
            ? GestureDetector(
                onTap: () {
                  _searchController.clear();
                  _onSearchChanged('');
                  FocusScope.of(context).unfocus();
                },
                child: Icon(
                  Icons.clear_rounded,
                  size: 18,
                  color: c.textTertiary,
                ),
              )
            : null,
        filled: true,
        fillColor: c.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 11,
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

  // ─── Search Results ────────────────────────────────────────────────────────
  Widget _buildSearchResults() {
    final c = _c;
    if (_loadingSearch) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator(color: c.primary)),
      );
    }
    if (_searchResults.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Column(
          children: [
            Icon(Icons.search_off_rounded, size: 40, color: c.textTertiary),
            const SizedBox(height: 8),
            Text(
              'Không tìm thấy từ nào',
              style: TextStyle(fontSize: 13, color: c.textSecondary),
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
      itemCount: _searchResults.length,
      itemBuilder: (context, i) {
        final card = _searchResults[i];
        return _SearchResultTile(card: card);
      },
    );
  }

  // ─── Streak Banner ─────────────────────────────────────────────────────────
  Widget _buildStreakBanner(int dueTotal) {
    final c = _c;
    const dayLabels = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];
    final todayIndex = DateTime.now().weekday - 1;
    final streakDays = _userModel?.streakDays ?? 0;
    final weekDone = _userModel?.weekDots ?? List.filled(7, false);

    return Container(
      decoration: BoxDecoration(
        color: c.primary,
        borderRadius: BorderRadius.circular(14),
      ),
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Chuỗi ngày học',
                  style: TextStyle(fontSize: 11, color: c.primaryLighter),
                ),
                const SizedBox(height: 3),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      '$streakDays',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'ngày',
                      style: TextStyle(fontSize: 13, color: c.primaryLighter),
                    ),
                    const SizedBox(width: 4),
                    const Text('🔥', style: TextStyle(fontSize: 14)),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(
                    7,
                    (i) => _buildDayDot(
                      dayLabels[i],
                      isDone: weekDone[i],
                      isToday: i == todayIndex,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'Đến hạn hôm nay',
                style: TextStyle(fontSize: 11, color: c.primaryLighter),
              ),
              const SizedBox(height: 2),
              Text(
                '$dueTotal',
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                  height: 1.1,
                ),
              ),
              Text(
                'thẻ cần ôn',
                style: TextStyle(fontSize: 10, color: c.primaryLighter),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(
                    alpha: dueTotal > 0 ? 0.2 : 0.08,
                  ),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.3),
                    width: 0.5,
                  ),
                ),
                child: Text(
                  dueTotal > 0 ? 'Học ngay' : 'Đã xong',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withValues(
                      alpha: dueTotal > 0 ? 1.0 : 0.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDayDot(
    String label, {
    required bool isDone,
    required bool isToday,
  }) {
    final c = _c;
    if (isDone) {
      return Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: c.primaryLight,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(Icons.check_rounded, size: 14, color: c.primaryDark),
      );
    }
    if (isToday) {
      return Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: c.primaryLight, width: 1.5),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w500,
              color: c.primary,
            ),
          ),
        ),
      );
    }
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Center(
        child: Text(
          label,
          style: TextStyle(fontSize: 9, color: c.primaryLighter),
        ),
      ),
    );
  }

  // ─── Feature Cards ─────────────────────────────────────────────────────────
  Widget _buildFeatureCards() {
    final c = _c;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Card lớn bên trái
        Expanded(
          flex: 5,
          child: GestureDetector(
            onTap: () => setState(() => _currentNavIndex = 1),
            child: Container(
              height: 176,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [c.primary, c.primaryDark],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: const Icon(
                      Icons.style_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  const Spacer(),
                  const Text(
                    'Học từ\nvựng',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Học ngay',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: c.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        // Cột phải — 3 card nhỏ
        Expanded(
          flex: 4,
          child: Column(
            children: [
              _smallFeatureCard(
                label: 'Ngữ pháp',
                sub: 'Cơ bản → nâng cao',
                icon: Icons.auto_stories_rounded,
                color: c.teal,
                bg: c.tealBg,
              ),
              const SizedBox(height: 8),
              _smallFeatureCard(
                label: 'Bài tập',
                sub: '500+ bài đa dạng',
                icon: Icons.edit_note_rounded,
                color: c.amber,
                bg: c.amberBg,
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () => setState(() => _currentNavIndex = 2),
                child: _smallFeatureCard(
                  label: 'Luyện đọc',
                  sub: 'Tin tức song ngữ',
                  icon: Icons.article_rounded,
                  color: c.coral,
                  bg: c.coralBg,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _smallFeatureCard({
    required String label,
    required String sub,
    required IconData icon,
    required Color color,
    required Color bg,
  }) {
    final c = _c;
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2), width: 0.5),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
                Text(
                  sub,
                  style: TextStyle(fontSize: 9, color: c.textSecondary),
                ),
              ],
            ),
          ),
          Icon(
            Icons.arrow_forward_ios_rounded,
            size: 11,
            color: color.withValues(alpha: 0.5),
          ),
        ],
      ),
    );
  }

  // ─── Hot Words Section ─────────────────────────────────────────────────────
  Widget _buildHotSection() {
    final c = _c;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: [
              const Text('🔥', style: TextStyle(fontSize: 16)),
              const SizedBox(width: 6),
              Text(
                'Từ được quan tâm nhiều nhất',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: c.textPrimary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (_loadingHot)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator(color: c.primary)),
          )
        else if (_hotCards.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
            child: Text(
              'Chưa có dữ liệu. Hãy bắt đầu học để xem thống kê!',
              style: TextStyle(fontSize: 12, color: c.textSecondary),
            ),
          )
        else
          SizedBox(
            height: 148,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              itemCount: _hotCards.length,
              itemBuilder: (context, i) => Padding(
                padding: const EdgeInsets.only(right: 10),
                child: _HotFlashcard(card: _hotCards[i], index: i),
              ),
            ),
          ),
      ],
    );
  }

  // ─── Bottom Nav ────────────────────────────────────────────────────────────
  Widget _buildBottomNav() {
    final c = _c;
    return BottomAppBar(
      color: c.surface,
      elevation: 0,
      child: SizedBox(
        height: 56,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavItem(0, Icons.grid_view_rounded, 'Trang chủ'),
            _buildNavItem(1, Icons.layers_outlined, 'Bộ thẻ'),
            _buildNavItem(2, Icons.article_rounded, 'Luyện đọc'),
            _buildNavItem(3, Icons.bar_chart_rounded, 'Thống kê'),
            _buildNavItem(4, Icons.person_outline_rounded, 'Hồ sơ'),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final c = _c;
    final isActive = _currentNavIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _currentNavIndex = index),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: isActive ? c.primary : c.textTertiary),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 9,
                fontWeight: isActive ? FontWeight.w500 : FontWeight.w400,
                color: isActive ? c.primary : c.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFab() {
    final c = _c;
    return FloatingActionButton(
      onPressed: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const AddDeckScreen()),
      ).then((_) => _loadData()),
      backgroundColor: c.primary,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: const Icon(Icons.add_rounded, color: Colors.white, size: 26),
    );
  }
}

// ─── Hot Flashcard Widget ─────────────────────────────────────────────────────
class _HotFlashcard extends StatefulWidget {
  final Flashcard card;
  final int index;
  const _HotFlashcard({required this.card, required this.index});

  @override
  State<_HotFlashcard> createState() => _HotFlashcardState();
}

class _HotFlashcardState extends State<_HotFlashcard> {
  bool _flipped = false;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final colors = [c.primary, c.teal, c.amber, c.coral];
    final bgs = [c.primaryBg, c.tealBg, c.amberBg, c.coralBg];
    final accent = colors[widget.index % 4];
    final bg = bgs[widget.index % 4];

    return GestureDetector(
      onTap: () => setState(() => _flipped = !_flipped),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 130,
        decoration: BoxDecoration(
          color: _flipped ? accent : c.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _flipped ? accent : c.border.withValues(alpha: 0.3),
            width: _flipped ? 0 : 0.5,
          ),
          boxShadow: _flipped
              ? [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: _flipped ? Colors.white.withValues(alpha: 0.2) : bg,
                borderRadius: BorderRadius.circular(7),
              ),
              child: Icon(
                Icons.style_rounded,
                size: 14,
                color: _flipped ? Colors.white : accent,
              ),
            ),
            const Spacer(),
            Text(
              _flipped ? widget.card.back : widget.card.front,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: _flipped ? Colors.white : c.textPrimary,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              _flipped
                  ? (widget.card.pronunciation ?? widget.card.front)
                  : (widget.card.pronunciation ?? 'Nhấn để xem nghĩa'),
              style: TextStyle(
                fontSize: 10,
                color: _flipped
                    ? Colors.white.withValues(alpha: 0.7)
                    : c.textTertiary,
                fontStyle: FontStyle.italic,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Search Result Tile ───────────────────────────────────────────────────────
class _SearchResultTile extends StatefulWidget {
  final Flashcard card;
  const _SearchResultTile({required this.card});

  @override
  State<_SearchResultTile> createState() => _SearchResultTileState();
}

class _SearchResultTileState extends State<_SearchResultTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return GestureDetector(
      onTap: () => setState(() => _expanded = !_expanded),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _expanded
                ? c.primary.withValues(alpha: 0.3)
                : c.border.withValues(alpha: 0.3),
            width: _expanded ? 1.0 : 0.5,
          ),
        ),
        padding: const EdgeInsets.all(13),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.card.front,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: c.primary,
                        ),
                      ),
                      if (widget.card.pronunciation != null &&
                          widget.card.pronunciation!.isNotEmpty)
                        Text(
                          widget.card.pronunciation!,
                          style: TextStyle(
                            fontSize: 11,
                            color: c.textSecondary,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                    ],
                  ),
                ),
                Icon(
                  _expanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  size: 20,
                  color: c.textTertiary,
                ),
              ],
            ),
            if (_expanded) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
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
                  ],
                ),
              ),
            ] else
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  widget.card.back,
                  style: TextStyle(fontSize: 13, color: c.textSecondary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Notification Settings Sheet ──────────────────────────────────────────────
class _NotificationSettingsSheet extends StatefulWidget {
  final NotificationService notifService;
  const _NotificationSettingsSheet({required this.notifService});
  @override
  State<_NotificationSettingsSheet> createState() =>
      _NotificationSettingsSheetState();
}

class _NotificationSettingsSheetState
    extends State<_NotificationSettingsSheet> {
  AppColors get _c => AppColors.of(context);
  bool _enabled = false;
  TimeOfDay _time = const TimeOfDay(hour: 20, minute: 0);
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final enabled = await widget.notifService.isEnabled();
    final time = await widget.notifService.getReminderTime();
    if (mounted) {
      setState(() {
        _enabled = enabled;
        _time = time;
        _loading = false;
      });
    }
  }

  Future<void> _toggleEnabled(bool value) async {
    setState(() => _enabled = value);
    if (value) {
      await widget.notifService.scheduleDailyReminder(_time.hour, _time.minute);
    } else {
      await widget.notifService.cancelAll();
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _time,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(
            context,
          ).colorScheme.copyWith(primary: _c.primary),
        ),
        child: child!,
      ),
    );
    if (picked != null && mounted) {
      setState(() => _time = picked);
      if (_enabled) {
        await widget.notifService.scheduleDailyReminder(
          picked.hour,
          picked.minute,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _c;
    if (_loading) {
      return SizedBox(
        height: 150,
        child: Center(child: CircularProgressIndicator(color: c.primary)),
      );
    }
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: c.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Nhắc nhở học tập',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: c.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Đặt lịch nhắc nhở để duy trì thói quen học mỗi ngày',
              style: TextStyle(fontSize: 12, color: c.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                color: c.bodyBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.notifications_active_rounded,
                    size: 20,
                    color: c.primary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Bật nhắc nhở',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: c.textPrimary,
                      ),
                    ),
                  ),
                  Switch(
                    value: _enabled,
                    activeThumbColor: c.primary,
                    onChanged: _toggleEnabled,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: _enabled ? _pickTime : null,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: c.bodyBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.access_time_rounded, size: 20, color: c.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Giờ nhắc',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: c.textPrimary,
                        ),
                      ),
                    ),
                    Text(
                      _time.format(context),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _enabled ? c.primary : c.textSecondary,
                      ),
                    ),
                    if (_enabled) ...[
                      const SizedBox(width: 4),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 18,
                        color: c.primary.withValues(alpha: 0.5),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (_enabled)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_rounded, size: 14, color: c.teal),
                  const SizedBox(width: 4),
                  Text(
                    'Sẽ nhắc bạn lúc ${_time.format(context)} mỗi ngày',
                    style: TextStyle(fontSize: 11, color: c.teal),
                  ),
                ],
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
