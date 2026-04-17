import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:provider/provider.dart';
import '../models/flashcard.dart';
import '../models/study_log.dart';
import '../providers/flashcard_provider.dart';
import '../services/firestore_service.dart';
import '../theme/app_colors.dart';

// ─── SM-2 Algorithm ───────────────────────────────────────────────────────────
Flashcard applySmTwo(Flashcard card, int quality) {
  double ef = card.easeFactor;
  int rep = card.repetitions;
  int interval = card.interval;

  if (quality >= 3) {
    if (rep == 0) {
      interval = 1;
    } else if (rep == 1) {
      interval = 6;
    } else {
      interval = (interval * ef).round();
    }
    rep += 1;
  } else {
    rep = 0;
    interval = 1;
  }

  ef = ef + (0.1 - (5 - quality) * (0.08 + (5 - quality) * 0.02));
  if (ef < 1.3) ef = 1.3;

  final nextReview = DateTime.now().add(Duration(days: interval));
  return card.copyWith(
    easeFactor: ef,
    interval: interval,
    repetitions: rep,
    nextReview: nextReview,
    reviewCount: card.reviewCount + 1,
    isLearned: rep >= 2,
  );
}

// ─── Levenshtein distance ─────────────────────────────────────────────────────
int _levenshtein(String a, String b) {
  if (a.isEmpty) return b.length;
  if (b.isEmpty) return a.length;
  final m = a.length, n = b.length;
  var prev = List<int>.generate(n + 1, (j) => j);
  var curr = List<int>.filled(n + 1, 0);
  for (int i = 1; i <= m; i++) {
    curr[0] = i;
    for (int j = 1; j <= n; j++) {
      final cost = a[i - 1] == b[j - 1] ? 0 : 1;
      curr[j] = [prev[j] + 1, curr[j - 1] + 1, prev[j - 1] + cost].reduce(min);
    }
    final tmp = prev;
    prev = curr;
    curr = tmp;
  }
  return prev[n];
}

int calcPronunciationScore(String recognized, String expected) {
  final a = recognized.trim().toLowerCase();
  final b = expected.trim().toLowerCase();
  if (b.isEmpty) return 0;
  if (a == b) return 100;
  final dist = _levenshtein(a, b);
  final maxLen = max(a.length, b.length);
  return ((1 - dist / maxLen) * 100).round().clamp(0, 100);
}

// ─── Pending result: lưu tạm trong RAM ───────────────────────────────────────
class _PendingResult {
  final Flashcard updatedCard;
  final StudyLog log;
  const _PendingResult({required this.updatedCard, required this.log});
}

// ─── 3 vòng học ───────────────────────────────────────────────────────────────
enum StudyPhase { flashcard, quiz, typing }

class StudyScreen extends StatefulWidget {
  final String deckId;
  final String deckName;
  const StudyScreen({super.key, required this.deckId, required this.deckName});
  @override
  State<StudyScreen> createState() => _StudyScreenState();
}

class _StudyScreenState extends State<StudyScreen>
    with SingleTickerProviderStateMixin {
  // ─── State ─────────────────────────────────────────────────────────────────
  List<Flashcard> _sessionCards = [];
  List<Flashcard> _allCards = [];
  bool _isLoading = true;

  StudyPhase _phase = StudyPhase.flashcard;
  List<Flashcard> _phaseQueue = [];
  int _phaseIndex = 0;

  int _score = 0;
  int _maxScore = 15;
  bool _sessionDone = false;

  bool _isFlipped = false;
  late AnimationController _flipController;
  late Animation<double> _flipAnimation;

  List<String> _quizChoices = [];
  int? _selectedChoice;
  bool _quizAnswered = false;

  final _typingCtrl = TextEditingController();
  bool _typingChecked = false;
  bool _typingCorrect = false;

  final FlutterTts _tts = FlutterTts();
  bool _ttsReady = false;

  final stt.SpeechToText _stt = stt.SpeechToText();
  bool _sttAvailable = false;

  int? _pronScore;
  String _pronText = '';
  bool _isPronChecking = false;

  final FirestoreService _fs = FirestoreService();
  final List<_PendingResult> _pendingResults = [];

  // ─── Lifecycle ─────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _flipController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _flipAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _flipController, curve: Curves.easeInOut),
    );
    _typingCtrl.addListener(() {
      if (mounted) setState(() {});
    });
    _initAll();
  }

  @override
  void dispose() {
    _flipController.dispose();
    _typingCtrl.dispose();
    _tts.stop();
    _stt.stop();
    super.dispose();
  }

  Future<void> _initAll() async {
    await Future.wait([_setupTts(), _setupStt(), _loadCards()]);
  }

  Future<void> _setupTts() async {
    try {
      await _tts.setLanguage('en-US');
      await _tts.setSpeechRate(0.5);
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);
      _tts.setErrorHandler((msg) => debugPrint('TTS error: $msg'));
      if (mounted) setState(() => _ttsReady = true);
    } catch (e) {
      debugPrint('TTS setup error: $e');
    }
  }

  Future<void> _setupStt() async {
    try {
      _sttAvailable = await _stt.initialize(
        onError: (e) {
          debugPrint('STT error: $e');
          if (mounted) setState(() => _isPronChecking = false);
        },
        onStatus: (s) => debugPrint('STT status: $s'),
      );
    } catch (e) {
      debugPrint('STT setup error: $e');
      _sttAvailable = false;
    }
  }

  Future<void> _loadCards() async {
    try {
      if (mounted) setState(() => _isLoading = true);
      final provider = context.read<FlashcardProvider>();
      await provider.loadFlashcards(widget.deckId);

      final allCards = provider.flashcards;
      final dueCards = await _fs.getDueCardsByDeck(widget.deckId);

      final pool = dueCards.isNotEmpty
          ? dueCards
          : List<Flashcard>.from(allCards);
      pool.shuffle(Random());

      final count = pool.length.clamp(1, 5).toInt();
      final selected = pool.take(count).toList();

      _pendingResults.clear();

      if (mounted) {
        setState(() {
          _allCards = allCards;
          _sessionCards = selected;
          _maxScore = (selected.length * 3).clamp(3, 15);
          _isLoading = false;
        });
        _startPhase(StudyPhase.flashcard);
      }
    } catch (e) {
      debugPrint('_loadCards error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _speak(String text) async {
    if (!_ttsReady || text.trim().isEmpty) return;
    try {
      await _tts.stop();
      await _tts.speak(text.trim());
    } catch (e) {
      debugPrint('_speak error: $e');
    }
  }

  // ─── Phase management ──────────────────────────────────────────────────────

  void _startPhase(StudyPhase phase) {
    _flipController.reset();
    setState(() {
      _phase = phase;
      _isFlipped = false;
      _phaseQueue = List.from(_sessionCards)..shuffle(Random());
      _phaseIndex = 0;
      _quizChoices = [];
      _selectedChoice = null;
      _quizAnswered = false;
      _typingCtrl.clear();
      _typingChecked = false;
      _typingCorrect = false;
      _pronScore = null;
      _pronText = '';
      _isPronChecking = false;
    });
    if (phase == StudyPhase.quiz) _buildQuizChoices();
  }

  Flashcard get _currentCard => _phaseQueue[_phaseIndex];

  void _advanceOrNextPhase() {
    if (_score >= _maxScore) {
      setState(() => _sessionDone = true);
      _commitResults();
      return;
    }
    if (_phaseIndex < _phaseQueue.length - 1) {
      _flipController.reset();
      setState(() {
        _phaseIndex++;
        _isFlipped = false;
        _quizChoices = [];
        _selectedChoice = null;
        _quizAnswered = false;
        _typingCtrl.clear();
        _typingChecked = false;
        _typingCorrect = false;
        _pronScore = null;
        _pronText = '';
        _isPronChecking = false;
      });
      if (_phase == StudyPhase.quiz) _buildQuizChoices();
    } else {
      switch (_phase) {
        case StudyPhase.flashcard:
          _startPhase(StudyPhase.quiz);
        case StudyPhase.quiz:
          _startPhase(StudyPhase.typing);
        case StudyPhase.typing:
          _startPhase(StudyPhase.quiz);
      }
    }
  }

  // ─── Score + Pending results ───────────────────────────────────────────────

  void _onCorrect(Flashcard card, int q) {
    setState(() => _score = (_score + 1).clamp(0, _maxScore));
    _recordResult(card, q, true);
  }

  void _onWrong(Flashcard card, int q) {
    setState(() => _score = (_score - 1).clamp(0, _maxScore));
    _phaseQueue.add(card);
    _recordResult(card, q, false);
  }

  /// Ghi tạm vào RAM — chưa lưu Firestore
  void _recordResult(Flashcard card, int quality, bool correct) {
    final updated = applySmTwo(card, quality);
    _pendingResults.add(
      _PendingResult(
        updatedCard: updated,
        log: StudyLog(
          userId: _fs.uid,
          deckId: widget.deckId,
          cardId: card.id!,
          rating: quality,
          isCorrect: correct,
          studyMode: _phase.name,
        ),
      ),
    );
  }

  /// Commit tất cả kết quả lên Firestore — chỉ gọi khi hoàn thành session
  Future<void> _commitResults() async {
    if (_pendingResults.isEmpty) return;
    try {
      for (final r in _pendingResults) {
        await _fs.updateFlashcard(r.updatedCard);
        await _fs.insertStudyLog(r.log);
      }
      await _fs.updateStreak();
      debugPrint('✅ Committed ${_pendingResults.length} results to Firestore');
    } catch (e) {
      debugPrint('❌ _commitResults error: $e');
    }
  }

  // ─── Flashcard flip ────────────────────────────────────────────────────────

  void _flipCard() {
    if (_isFlipped) {
      _flipController.reverse();
    } else {
      _flipController.forward();
      _speak(_currentCard.front);
    }
    setState(() => _isFlipped = !_isFlipped);
  }

  void _rateFlashcard(int quality) {
    final card = _currentCard;
    quality >= 3 ? _onCorrect(card, quality) : _onWrong(card, quality);
    _advanceOrNextPhase();
  }

  // ─── Quiz ──────────────────────────────────────────────────────────────────

  void _buildQuizChoices() {
    if (_phaseQueue.isEmpty) return;
    final current = _currentCard;
    final wrongs =
        _allCards.where((c) => c.id != current.id).map((c) => c.back).toList()
          ..shuffle(Random());
    final choices = [current.back, ...wrongs.take(3)]..shuffle(Random());
    setState(() => _quizChoices = choices);
  }

  Future<void> _selectQuizAnswer(int index) async {
    if (_quizAnswered) return;
    final card = _currentCard;
    final correct = _quizChoices[index] == card.back;
    setState(() {
      _selectedChoice = index;
      _quizAnswered = true;
    });
    correct ? _onCorrect(card, 3) : _onWrong(card, 0);
    await Future.delayed(const Duration(milliseconds: 800));
    _advanceOrNextPhase();
  }

  // ─── Typing ────────────────────────────────────────────────────────────────

  void _checkTyping() {
    final correct =
        _typingCtrl.text.trim().toLowerCase() ==
        _currentCard.front.trim().toLowerCase();
    setState(() {
      _typingChecked = true;
      _typingCorrect = correct;
    });
    correct ? _onCorrect(_currentCard, 5) : _onWrong(_currentCard, 0);
  }

  // ─── STT chấm điểm phát âm ────────────────────────────────────────────────

  Future<void> _startPronCheck() async {
    if (!_sttAvailable || _isPronChecking) return;
    setState(() {
      _isPronChecking = true;
      _pronScore = null;
      _pronText = '';
    });
    try {
      await _stt.listen(
        localeId: 'en_US',
        onResult: (result) {
          if (!mounted) return;
          setState(() => _pronText = result.recognizedWords);
          if (result.finalResult) _finishPronCheck(result.recognizedWords);
        },
        listenFor: const Duration(seconds: 10),
        pauseFor: const Duration(seconds: 5),
      );
    } catch (e) {
      debugPrint('_startPronCheck error: $e');
      if (mounted) setState(() => _isPronChecking = false);
    }
  }

  void _finishPronCheck(String recognized) {
    try {
      _stt.stop();
    } catch (_) {}
    if (!mounted) return;
    final score = calcPronunciationScore(recognized, _currentCard.front);
    setState(() {
      _isPronChecking = false;
      _pronScore = score;
      _pronText = recognized;
    });
  }

  Future<void> _stopPronCheck() async {
    try {
      await _stt.stop();
    } catch (_) {}
    if (!mounted) return;
    if (_pronText.isNotEmpty) {
      _finishPronCheck(_pronText);
    } else {
      setState(() => _isPronChecking = false);
    }
  }

  Color _pronColor(AppColors c, int s) => s >= 80
      ? c.teal
      : s >= 60
      ? c.amber
      : c.coral;
  Color _pronBg(AppColors c, int s) => s >= 80
      ? c.tealBg
      : s >= 60
      ? c.amberBg
      : c.coralBg;
  String _pronLabel(int s) => s >= 80
      ? 'Tuyệt vời!'
      : s >= 60
      ? 'Khá tốt'
      : 'Thử lại nhé';
  IconData _pronIcon(int s) => s >= 80
      ? Icons.sentiment_very_satisfied_rounded
      : s >= 60
      ? Icons.sentiment_satisfied_rounded
      : Icons.sentiment_dissatisfied_rounded;

  // ═════════════════════════════════════════════════════════════════════════════
  // ─── BUILD ─────────────────────────────────────────────────────────────────
  // ═════════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Scaffold(
      backgroundColor: c.bodyBg,
      appBar: AppBar(
        backgroundColor: c.primary,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: c.primaryLighter,
            size: 18,
          ),
          onPressed: _showExitDialog,
        ),
        title: Text(
          widget.deckName,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w500,
            color: Colors.white,
          ),
        ),
        actions: [
          if (!_isLoading && !_sessionDone)
            Container(
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _phaseLabel(),
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: c.primary))
          : _sessionCards.isEmpty
          ? _buildEmptyState()
          : _sessionDone
          ? _buildDoneState()
          : Column(
              children: [
                _buildScoreBar(),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: switch (_phase) {
                      StudyPhase.flashcard => _buildFlashcardPhase(),
                      StudyPhase.quiz => _buildQuizPhase(),
                      StudyPhase.typing => _buildTypingPhase(),
                    },
                  ),
                ),
              ],
            ),
    );
  }

  String _phaseLabel() => switch (_phase) {
    StudyPhase.flashcard => 'Vòng 1: Lật thẻ',
    StudyPhase.quiz => 'Vòng 2: Trắc nghiệm',
    StudyPhase.typing => 'Vòng 3: Tự nhập',
  };

  void _showExitDialog() {
    final c = AppColors.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Thoát bài học?',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: c.textPrimary,
          ),
        ),
        content: Text(
          'Tiến độ bài học hiện tại sẽ không được lưu.',
          style: TextStyle(fontSize: 13, color: c.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Tiếp tục học', style: TextStyle(color: c.primary)),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(
                context,
              ); // Thoát → không commit → Firestore giữ nguyên
            },
            style: FilledButton.styleFrom(
              backgroundColor: c.error,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Thoát'),
          ),
        ],
      ),
    );
  }

  // ─── Score bar ─────────────────────────────────────────────────────────────

  Widget _buildScoreBar() {
    final c = AppColors.of(context);
    final progress = _score / _maxScore;
    final phaseIcon = switch (_phase) {
      StudyPhase.flashcard => Icons.style_rounded,
      StudyPhase.quiz => Icons.quiz_rounded,
      StudyPhase.typing => Icons.keyboard_rounded,
    };
    final phaseShort = switch (_phase) {
      StudyPhase.flashcard => 'Lật thẻ',
      StudyPhase.quiz => 'Trắc nghiệm',
      StudyPhase.typing => 'Tự nhập',
    };

    return Container(
      color: c.surface,
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      child: Column(
        children: [
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(5),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 10,
                  backgroundColor: c.bodyBg,
                  valueColor: AlwaysStoppedAnimation(
                    _score >= _maxScore ? c.teal : c.primary,
                  ),
                ),
              ),
              Positioned.fill(
                child: Center(
                  child: Text(
                    '$_score / $_maxScore',
                    style: const TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _chip(phaseIcon, phaseShort, c.primaryBg, c.primary),
              const Spacer(),
              Text(
                '${_phaseIndex + 1} / ${_phaseQueue.length} từ',
                style: TextStyle(fontSize: 11, color: c.textSecondary),
              ),
              const Spacer(),
              _chip(
                Icons.stars_rounded,
                '$_score đ',
                _score > 0 ? c.tealBg : c.bodyBg,
                _score > 0 ? c.teal : c.textTertiary,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chip(IconData icon, String label, Color bg, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════════════════════
  // ─── VÒNG 1: Lật thẻ ──────────────────────────────────────────────────────
  // ═════════════════════════════════════════════════════════════════════════════

  Widget _buildFlashcardPhase() {
    final card = _currentCard;
    return Column(
      children: [
        Expanded(child: _buildFlipCard(card)),
        const SizedBox(height: 14),
        if (!_isFlipped)
          _buildHint('Chạm vào thẻ để lật')
        else ...[
          if (_sttAvailable) _buildPronSection(card),
          const SizedBox(height: 10),
          _buildRatingButtons(),
        ],
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildFlipCard(Flashcard card) {
    return GestureDetector(
      onTap: _flipCard,
      child: AnimatedBuilder(
        animation: _flipAnimation,
        builder: (context, _) {
          final angle = _flipAnimation.value * pi;
          final front = angle < pi / 2;
          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001)
              ..rotateY(angle),
            child: front
                ? _cardFace(card.front, card.pronunciation, true)
                : Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()..rotateY(pi),
                    child: _cardFace(card.back, card.example, false),
                  ),
          );
        },
      ),
    );
  }

  Widget _cardFace(String content, String? sub, bool isFront) {
    final c = AppColors.of(context);
    final accent = isFront ? c.primary : c.teal;
    final accentBg = isFront ? c.primaryBg : c.tealBg;
    final label = isFront ? 'TIẾNG ANH' : 'NGHĨA';

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.15)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: 14,
            left: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
              decoration: BoxDecoration(
                color: accentBg,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                label,
                style: TextStyle(
                  color: accent,
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.8,
                ),
              ),
            ),
          ),
          if (isFront)
            Positioned(
              top: 8,
              right: 8,
              child: GestureDetector(
                onTap: _ttsReady ? () => _speak(content) : null,
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: _ttsReady ? c.primaryBg : c.bodyBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.volume_up_rounded,
                    color: _ttsReady ? c.primary : c.textTertiary,
                    size: 19,
                  ),
                ),
              ),
            ),
          Center(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 56, 24, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    content,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: content.length > 30 ? 22 : 28,
                      fontWeight: FontWeight.w600,
                      color: c.textPrimary,
                    ),
                  ),
                  if (sub != null && sub.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      sub,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        color: accent.withValues(alpha: 0.7),
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Pronunciation section (vòng 1) ────────────────────────────────────────

  Widget _buildPronSection(Flashcard card) {
    final c = AppColors.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _pronScore != null
              ? _pronColor(c, _pronScore!).withValues(alpha: 0.3)
              : c.primary.withValues(alpha: 0.1),
          width: 0.5,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                Icons.record_voice_over_rounded,
                size: 16,
                color: c.textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                'Luyện phát âm',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: c.textSecondary,
                ),
              ),
              const Spacer(),
              _pronButton(
                Icons.volume_up_rounded,
                'Nghe',
                c.primaryBg,
                c.primary,
                () => _speak(card.front),
              ),
              const SizedBox(width: 6),
              _pronButton(
                _isPronChecking ? Icons.stop_rounded : Icons.mic_rounded,
                _isPronChecking ? 'Dừng' : 'Đọc',
                _isPronChecking ? c.coralBg : c.tealBg,
                _isPronChecking ? c.coral : c.teal,
                _isPronChecking ? _stopPronCheck : _startPronCheck,
              ),
            ],
          ),
          if (_isPronChecking) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: c.coral,
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    _pronText.isEmpty ? 'Đang nghe...' : '"$_pronText"',
                    style: TextStyle(
                      fontSize: 12,
                      color: c.coral,
                      fontStyle: FontStyle.italic,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
          if (_pronScore != null) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _pronBg(c, _pronScore!),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: _pronColor(c, _pronScore!).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '$_pronScore%',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: _pronColor(c, _pronScore!),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              _pronIcon(_pronScore!),
                              size: 16,
                              color: _pronColor(c, _pronScore!),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _pronLabel(_pronScore!),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: _pronColor(c, _pronScore!),
                              ),
                            ),
                          ],
                        ),
                        if (_pronText.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            'Bạn đọc: "$_pronText"',
                            style: TextStyle(
                              fontSize: 11,
                              color: c.textSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: _startPronCheck,
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: c.surface,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.replay_rounded,
                        size: 16,
                        color: _pronColor(c, _pronScore!),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _pronButton(
    IconData icon,
    String label,
    Color bg,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRatingButtons() {
    final c = AppColors.of(context);
    return Column(
      children: [
        Text(
          'Bạn nhớ tốt đến đâu?',
          style: TextStyle(
            color: c.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            _ratingBtn(c, 'Quên', Icons.replay_rounded, c.error, 0),
            const SizedBox(width: 6),
            _ratingBtn(
              c,
              'Khó',
              Icons.sentiment_dissatisfied_rounded,
              c.coral,
              2,
            ),
            const SizedBox(width: 6),
            _ratingBtn(
              c,
              'Được',
              Icons.sentiment_satisfied_rounded,
              c.primary,
              3,
            ),
            const SizedBox(width: 6),
            _ratingBtn(
              c,
              'Dễ',
              Icons.sentiment_very_satisfied_rounded,
              c.teal,
              5,
            ),
          ],
        ),
      ],
    );
  }

  Widget _ratingBtn(
    AppColors c,
    String label,
    IconData icon,
    Color color,
    int quality,
  ) {
    final bg = color == c.error
        ? c.coralBg
        : color == c.coral
        ? c.amberBg
        : color == c.primary
        ? c.primaryBg
        : c.tealBg;
    return Expanded(
      child: GestureDetector(
        onTap: () => _rateFlashcard(quality),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withValues(alpha: 0.2), width: 0.5),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(height: 3),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHint(String text) {
    final c = AppColors.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.touch_app_rounded, size: 16, color: c.textTertiary),
        const SizedBox(width: 5),
        Text(text, style: TextStyle(color: c.textTertiary, fontSize: 12)),
      ],
    );
  }

  // ═════════════════════════════════════════════════════════════════════════════
  // ─── VÒNG 2: Quiz ─────────────────────────────────────────────────────────
  // ═════════════════════════════════════════════════════════════════════════════

  Widget _buildQuizPhase() {
    final c = AppColors.of(context);
    if (_quizChoices.isEmpty) {
      _buildQuizChoices();
      return Center(child: CircularProgressIndicator(color: c.primary));
    }
    final card = _currentCard;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: c.primary.withValues(alpha: 0.12)),
            ),
            child: Column(
              children: [
                Text(
                  'NGHĨA CỦA TỪ NÀY LÀ GÌ?',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: c.textTertiary,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        card.front,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                          color: c.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: _ttsReady ? () => _speak(card.front) : null,
                      child: Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: c.primaryBg,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.volume_up_rounded,
                          color: c.primary,
                          size: 17,
                        ),
                      ),
                    ),
                  ],
                ),
                if (card.pronunciation != null &&
                    card.pronunciation!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    card.pronunciation!,
                    style: TextStyle(
                      fontSize: 13,
                      color: c.primary,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Chọn nghĩa đúng:',
            style: TextStyle(
              color: c.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          ...List.generate(_quizChoices.length, (i) => _buildChoiceTile(c, i)),
        ],
      ),
    );
  }

  Widget _buildChoiceTile(AppColors c, int index) {
    final choice = _quizChoices[index];
    final isCorrect = choice == _currentCard.back;
    final isSelected = _selectedChoice == index;
    final labels = ['A', 'B', 'C', 'D'];

    Color bg = c.surface, border = Colors.black.withValues(alpha: 0.06);
    Color text = c.textPrimary, labelBg = c.bodyBg, labelC = c.textSecondary;
    double bw = 0.5;

    if (_quizAnswered) {
      if (isCorrect) {
        bg = c.tealBg;
        border = c.teal;
        text = c.teal;
        labelBg = c.teal;
        labelC = Colors.white;
        bw = 1.2;
      } else if (isSelected) {
        bg = c.coralBg;
        border = c.coral;
        text = c.coral;
        labelBg = c.coral;
        labelC = Colors.white;
        bw = 1.2;
      }
    } else if (isSelected) {
      bg = c.primaryBg;
      border = c.primary;
      labelBg = c.primary;
      labelC = Colors.white;
      bw = 1.2;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTap: () => _selectQuizAnswer(index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: border, width: bw),
          ),
          child: Row(
            children: [
              Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: labelBg,
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Text(
                  labels[index],
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: labelC,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  choice,
                  style: TextStyle(
                    fontSize: 14,
                    color: text,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (_quizAnswered && isCorrect)
                Icon(Icons.check_circle_rounded, color: c.teal, size: 20),
              if (_quizAnswered && isSelected && !isCorrect)
                Icon(Icons.cancel_rounded, color: c.coral, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════════════════════
  // ─── VÒNG 3: Tự nhập ──────────────────────────────────────────────────────
  // ═════════════════════════════════════════════════════════════════════════════

  Widget _buildTypingPhase() {
    final c = AppColors.of(context);
    final card = _currentCard;
    return SingleChildScrollView(
      child: Column(
        children: [
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: c.teal.withValues(alpha: 0.15)),
            ),
            child: Column(
              children: [
                Text(
                  'NHẬP TỪ TIẾNG ANH CHO NGHĨA SAU',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: c.textTertiary,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  card.back,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: c.teal,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _typingCtrl,
            enabled: !_typingChecked,
            autofocus: true,
            textCapitalization: TextCapitalization.none,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) {
              if (!_typingChecked && _typingCtrl.text.trim().isNotEmpty) {
                _checkTyping();
              }
            },
            decoration: InputDecoration(
              hintText: 'Nhập từ tiếng Anh...',
              hintStyle: TextStyle(fontSize: 14, color: c.textTertiary),
              prefixIcon: Icon(
                Icons.edit_rounded,
                size: 18,
                color: _typingChecked
                    ? (_typingCorrect ? c.teal : c.error)
                    : c.textSecondary,
              ),
              filled: true,
              fillColor: c.surface,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 14,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                  color: _typingChecked
                      ? (_typingCorrect ? c.teal : c.error)
                      : c.border,
                  width: _typingChecked ? 1.5 : 0.5,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                  color: _typingChecked
                      ? (_typingCorrect ? c.teal : c.error)
                      : c.border,
                  width: _typingChecked ? 1.5 : 0.5,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: c.primary, width: 1.2),
              ),
              disabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                  color: _typingCorrect ? c.teal : c.error,
                  width: 1.5,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (_typingChecked) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _typingCorrect ? c.tealBg : c.coralBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(
                    _typingCorrect
                        ? Icons.check_circle_rounded
                        : Icons.info_outline_rounded,
                    color: _typingCorrect ? c.teal : c.coral,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _typingCorrect ? 'Chính xác!' : 'Chưa đúng',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: _typingCorrect ? c.teal : c.coral,
                          ),
                        ),
                        if (!_typingCorrect) ...[
                          const SizedBox(height: 2),
                          Text(
                            'Đáp án: ${_currentCard.front}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: c.primary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _advanceOrNextPhase,
                style: FilledButton.styleFrom(
                  backgroundColor: c.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                ),
                child: Text(
                  _typingCorrect ? 'Từ tiếp theo' : 'Tiếp tục',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ] else
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _typingCtrl.text.trim().isNotEmpty
                    ? _checkTyping
                    : null,
                style: FilledButton.styleFrom(
                  backgroundColor: c.primary,
                  disabledBackgroundColor: c.primaryLight,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                ),
                child: const Text(
                  'Kiểm tra',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ─── Done / Empty ──────────────────────────────────────────────────────────

  Widget _buildDoneState() {
    final c = AppColors.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: c.tealBg,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(Icons.celebration_rounded, size: 42, color: c.teal),
            ),
            const SizedBox(height: 24),
            Text(
              'Hoàn thành xuất sắc!',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: c.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Bạn đã đạt $_maxScore điểm và hoàn thành\nbài học ${_sessionCards.length} từ.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: c.textSecondary),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: 200,
              child: FilledButton.icon(
                onPressed: () {
                  setState(() {
                    _score = 0;
                    _sessionDone = false;
                  });
                  _loadCards();
                },
                icon: const Icon(Icons.replay_rounded, size: 18),
                label: const Text('Học bộ mới'),
                style: FilledButton.styleFrom(
                  backgroundColor: c.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: 200,
              child: OutlinedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back_rounded, size: 18),
                label: const Text('Quay lại'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: c.primary,
                  side: BorderSide(color: c.primaryLight),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                ),
              ),
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
                color: c.tealBg,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(
                Icons.check_circle_outline_rounded,
                size: 38,
                color: c.teal,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Không có thẻ nào cần ôn!',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: c.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Bộ thẻ này chưa có thẻ hoặc\ntất cả thẻ chưa đến lịch ôn.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: c.textSecondary),
            ),
            const SizedBox(height: 28),
            OutlinedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back_rounded, size: 18),
              label: const Text('Quay lại'),
              style: OutlinedButton.styleFrom(
                foregroundColor: c.primary,
                side: BorderSide(color: c.primaryLight),
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
}
