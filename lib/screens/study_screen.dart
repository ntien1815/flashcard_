import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:provider/provider.dart';
import '../models/flashcard.dart';
import '../providers/flashcard_provider.dart';
import '../services/firestore_service.dart';

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

class StudyScreen extends StatefulWidget {
  final String deckId;
  final String deckName;

  const StudyScreen({super.key, required this.deckId, required this.deckName});

  @override
  State<StudyScreen> createState() => _StudyScreenState();
}

enum StudyMode { flashcard, quiz }

class _StudyScreenState extends State<StudyScreen>
    with SingleTickerProviderStateMixin {
  List<Flashcard> _cards = [];
  List<Flashcard> _allCards = [];
  int _currentIndex = 0;
  bool _isLoading = true;
  bool _isFlipped = false;
  bool _sessionDone = false;

  StudyMode _mode = StudyMode.flashcard;

  List<String> _quizChoices = [];
  int? _selectedChoice;
  bool _quizAnswered = false;

  late AnimationController _flipController;
  late Animation<double> _flipAnimation;

  final FlutterTts _tts = FlutterTts();

  final stt.SpeechToText _stt = stt.SpeechToText();
  bool _sttAvailable = false;
  bool _isListening = false;
  String _recognizedText = '';

  final FirestoreService _firestoreService = FirestoreService();

  @override
  void initState() {
    super.initState();
    _setupFlipAnimation();
    _setupTts();
    _setupStt();
    _loadCards();
  }

  @override
  void dispose() {
    _flipController.dispose();
    _tts.stop();
    _stt.stop();
    super.dispose();
  }

  void _setupFlipAnimation() {
    _flipController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _flipAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _flipController, curve: Curves.easeInOut),
    );
  }

  Future<void> _setupTts() async {
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.5);
    await _tts.setVolume(1.0);
  }

  Future<void> _setupStt() async {
    _sttAvailable = await _stt.initialize(
      onError: (e) => debugPrint('STT error: $e'),
      onStatus: (s) => debugPrint('STT status: $s'),
    );
    debugPrint('STT available: $_sttAvailable');
  }

  Future<void> _loadCards() async {
    try {
      setState(() => _isLoading = true);
      final provider = context.read<FlashcardProvider>();
      await provider.loadFlashcards(widget.deckId);

      final allCards = provider.flashcards;
      final dueCards = await _firestoreService.getDueCardsByDeck(widget.deckId);

      setState(() {
        _allCards = allCards;
        _cards = dueCards.isNotEmpty ? dueCards : List.from(allCards);
        _cards.shuffle(Random());
        _isLoading = false;
      });

      debugPrint('Study: ${_cards.length} cards to review');
    } catch (e) {
      debugPrint('_loadCards error: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _speak(String text) async {
    await _tts.stop();
    await _tts.speak(text);
  }

  Future<void> _startListening() async {
    if (!_sttAvailable || _isListening) return;
    setState(() {
      _isListening = true;
      _recognizedText = '';
    });
    await _stt.listen(
      localeId: 'vi_VN',
      onResult: (result) {
        setState(() => _recognizedText = result.recognizedWords);
        if (result.finalResult) {
          _stopListening();
          _checkSttAnswer();
        }
      },
      listenFor: const Duration(seconds: 10),
      pauseFor: const Duration(seconds: 2),
    );
  }

  Future<void> _stopListening() async {
    await _stt.stop();
    setState(() => _isListening = false);
  }

  void _checkSttAnswer() {
    if (_recognizedText.isEmpty) return;
    final answer = _recognizedText.toLowerCase().trim();
    final correct = _cards[_currentIndex].back.toLowerCase().trim();
    final isCorrect = answer.contains(correct) || correct.contains(answer);
    debugPrint('STT: "$answer" vs "$correct" => $isCorrect');
    _showSttResult(isCorrect);
  }

  void _showSttResult(bool isCorrect) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              isCorrect ? Icons.check_circle_rounded : Icons.cancel_rounded,
              color: isCorrect ? Colors.green : Colors.red,
            ),
            const SizedBox(width: 8),
            Text(isCorrect ? 'Đúng rồi!' : 'Chưa đúng'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Bạn nói: "$_recognizedText"'),
            const SizedBox(height: 4),
            if (!isCorrect)
              Text(
                'Đáp án: "${_cards[_currentIndex].back}"',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _rateCard(isCorrect ? 3 : 0);
            },
            child: const Text('Tiếp tục'),
          ),
        ],
      ),
    );
  }

  void _flipCard() {
    if (_isFlipped) {
      _flipController.reverse();
    } else {
      _flipController.forward();
      _speak(_cards[_currentIndex].front);
    }
    setState(() => _isFlipped = !_isFlipped);
  }

  void _resetFlip() {
    _flipController.reset();
    setState(() => _isFlipped = false);
  }

  Future<void> _rateCard(int quality) async {
    final card = _cards[_currentIndex];
    final updated = applySmTwo(card, quality);
    try {
      await _firestoreService.updateFlashcard(updated);
    } catch (e) {
      debugPrint('updateFlashcard error: $e');
    }
    _nextCard();
  }

  void _nextCard() {
    if (_currentIndex >= _cards.length - 1) {
      setState(() => _sessionDone = true);
      return;
    }
    _resetFlip();
    setState(() {
      _currentIndex++;
      _quizChoices = [];
      _selectedChoice = null;
      _quizAnswered = false;
    });
    if (_mode == StudyMode.quiz) _buildQuizChoices();
  }

  void _buildQuizChoices() {
    final current = _cards[_currentIndex];
    final wrongs = _allCards
        .where((c) => c.id != current.id)
        .map((c) => c.back)
        .toList();
    wrongs.shuffle(Random());
    final choices = [current.back, ...wrongs.take(3)];
    choices.shuffle(Random());
    setState(() => _quizChoices = choices);
  }

  Future<void> _selectQuizAnswer(int index) async {
    if (_quizAnswered) return;
    final correct = _quizChoices[index] == _cards[_currentIndex].back;
    setState(() {
      _selectedChoice = index;
      _quizAnswered = true;
    });
    await Future.delayed(const Duration(milliseconds: 900));
    await _rateCard(correct ? 3 : 0);
  }

  void _switchMode(StudyMode mode) {
    _resetFlip();
    setState(() {
      _mode = mode;
      _currentIndex = 0;
      _sessionDone = false;
      _quizChoices = [];
      _selectedChoice = null;
      _quizAnswered = false;
      _cards.shuffle(Random());
    });
    if (mode == StudyMode.quiz) _buildQuizChoices();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.deckName)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_cards.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.deckName)),
        body: _buildEmptyState(),
      );
    }
    if (_sessionDone) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.deckName)),
        body: _buildDoneState(),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.deckName),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: SegmentedButton<StudyMode>(
              segments: const [
                ButtonSegment(
                  value: StudyMode.flashcard,
                  icon: Icon(Icons.style_outlined, size: 16),
                  label: Text('Thẻ'),
                ),
                ButtonSegment(
                  value: StudyMode.quiz,
                  icon: Icon(Icons.quiz_outlined, size: 16),
                  label: Text('Quiz'),
                ),
              ],
              selected: {_mode},
              onSelectionChanged: (s) => _switchMode(s.first),
              style: const ButtonStyle(visualDensity: VisualDensity.compact),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildProgressBar(),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _mode == StudyMode.flashcard
                  ? _buildFlashcardMode()
                  : _buildQuizMode(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar() {
    final progress = _cards.isEmpty ? 0.0 : _currentIndex / _cards.length;
    return Column(
      children: [
        LinearProgressIndicator(
          value: progress,
          minHeight: 6,
          backgroundColor: Colors.grey.shade200,
          valueColor: AlwaysStoppedAnimation<Color>(
            Theme.of(context).colorScheme.primary,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${_currentIndex + 1} / ${_cards.length}',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
              ),
              Text(
                '${_cards.length - _currentIndex - 1} thẻ còn lại',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFlashcardMode() {
    final card = _cards[_currentIndex];
    return Column(
      children: [
        Expanded(child: _buildFlipCard(card)),
        const SizedBox(height: 16),
        if (!_isFlipped)
          _buildHintText('Chạm vào thẻ để lật')
        else
          _buildRatingButtons(),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildFlipCard(Flashcard card) {
    return GestureDetector(
      onTap: _flipCard,
      child: AnimatedBuilder(
        animation: _flipAnimation,
        builder: (context, child) {
          final angle = _flipAnimation.value * pi;
          final isFrontVisible = angle < pi / 2;
          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001)
              ..rotateY(angle),
            child: isFrontVisible
                ? _buildCardFace(
                    content: card.front,
                    subContent: card.pronunciation,
                    label: 'FRONT',
                    isFront: true,
                    card: card,
                  )
                : Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()..rotateY(pi),
                    child: _buildCardFace(
                      content: card.back,
                      subContent: card.example,
                      label: 'BACK',
                      isFront: false,
                      card: card,
                    ),
                  ),
          );
        },
      ),
    );
  }

  Widget _buildCardFace({
    required String content,
    required String? subContent,
    required String label,
    required bool isFront,
    required Flashcard card,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isFront
                ? [Colors.indigo.shade50, Colors.indigo.shade100]
                : [Colors.teal.shade50, Colors.teal.shade100],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: 16,
              left: 20,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: isFront ? Colors.indigo : Colors.teal,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ),
            if (isFront)
              Positioned(
                top: 8,
                right: 12,
                child: IconButton(
                  icon: const Icon(Icons.volume_up_rounded),
                  color: Colors.indigo,
                  onPressed: () => _speak(content),
                ),
              ),
            Center(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 64, 24, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      content,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: content.length > 30 ? 22 : 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    if (subContent != null && subContent.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        subContent,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey.shade600,
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
      ),
    );
  }

  Widget _buildRatingButtons() {
    return Column(
      children: [
        Text(
          'Bạn nhớ tốt đến đâu?',
          style: TextStyle(
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _ratingBtn('Quên', Icons.replay_rounded, Colors.red, 0),
            const SizedBox(width: 8),
            _ratingBtn(
              'Khó',
              Icons.sentiment_dissatisfied_rounded,
              Colors.orange,
              2,
            ),
            const SizedBox(width: 8),
            _ratingBtn(
              'Được',
              Icons.sentiment_satisfied_rounded,
              Colors.blue,
              3,
            ),
            const SizedBox(width: 8),
            _ratingBtn(
              'Dễ',
              Icons.sentiment_very_satisfied_rounded,
              Colors.green,
              5,
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_sttAvailable)
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _isListening ? _stopListening : _startListening,
              icon: Icon(
                _isListening ? Icons.mic_off_rounded : Icons.mic_rounded,
                color: _isListening ? Colors.red : Colors.indigo,
              ),
              label: Text(
                _isListening
                    ? (_recognizedText.isEmpty
                          ? 'Đang nghe...'
                          : _recognizedText)
                    : 'Nói đáp án',
                style: TextStyle(
                  color: _isListening ? Colors.red : Colors.indigo,
                ),
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                side: BorderSide(
                  color: _isListening ? Colors.red : Colors.indigo,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _ratingBtn(String label, IconData icon, Color color, int quality) {
    return Expanded(
      child: ElevatedButton(
        onPressed: () => _rateCard(quality),
        style: ElevatedButton.styleFrom(
          backgroundColor: color.withValues(alpha: 0.1),
          foregroundColor: color,
          elevation: 0,
          side: BorderSide(color: color.withValues(alpha: 0.4)),
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 22),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHintText(String text) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.touch_app_rounded, size: 18, color: Colors.grey.shade400),
        const SizedBox(width: 6),
        Text(text, style: TextStyle(color: Colors.grey.shade400, fontSize: 14)),
      ],
    );
  }

  Widget _buildQuizMode() {
    if (_quizChoices.isEmpty) {
      _buildQuizChoices();
      return const Center(child: CircularProgressIndicator());
    }
    final card = _cards[_currentIndex];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          color: Colors.indigo.shade50,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    card.front,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.volume_up_rounded,
                    color: Colors.indigo,
                  ),
                  onPressed: () => _speak(card.front),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Chọn nghĩa đúng:',
          style: TextStyle(
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 12),
        ...List.generate(_quizChoices.length, (i) => _buildChoiceTile(i)),
      ],
    );
  }

  Widget _buildChoiceTile(int index) {
    final choice = _quizChoices[index];
    final isCorrect = choice == _cards[_currentIndex].back;
    final isSelected = _selectedChoice == index;

    Color bgColor = Colors.white;
    Color borderColor = Colors.grey.shade300;
    Color textColor = Colors.grey.shade800;
    IconData? trailingIcon;

    if (_quizAnswered) {
      if (isCorrect) {
        bgColor = Colors.green.shade50;
        borderColor = Colors.green;
        textColor = Colors.green.shade800;
        trailingIcon = Icons.check_circle_rounded;
      } else if (isSelected) {
        bgColor = Colors.red.shade50;
        borderColor = Colors.red;
        textColor = Colors.red.shade800;
        trailingIcon = Icons.cancel_rounded;
      }
    } else if (isSelected) {
      bgColor = Colors.indigo.shade50;
      borderColor = Colors.indigo;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: () => _selectQuizAnswer(index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor, width: 1.5),
          ),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: borderColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  ['A', 'B', 'C', 'D'][index],
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: borderColor,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  choice,
                  style: TextStyle(
                    fontSize: 16,
                    color: textColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (trailingIcon != null)
                Icon(trailingIcon, color: borderColor, size: 22),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDoneState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.celebration_rounded,
              size: 80,
              color: Colors.amber,
            ),
            const SizedBox(height: 24),
            const Text(
              'Hoàn thành!',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Bạn đã ôn xong ${_cards.length} thẻ trong bộ này.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 40),
            FilledButton.icon(
              onPressed: () => _switchMode(_mode),
              icon: const Icon(Icons.replay_rounded),
              label: const Text('Học lại'),
              style: FilledButton.styleFrom(minimumSize: const Size(200, 52)),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back_rounded),
              label: const Text('Về trang chủ'),
              style: OutlinedButton.styleFrom(minimumSize: const Size(200, 52)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.check_circle_rounded,
              size: 80,
              color: Colors.green.shade400,
            ),
            const SizedBox(height: 24),
            const Text(
              'Không có thẻ nào cần ôn!',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Bộ thẻ này chưa có thẻ hoặc\ntất cả thẻ chưa đến lịch ôn.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 32),
            OutlinedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back_rounded),
              label: const Text('Quay lại'),
            ),
          ],
        ),
      ),
    );
  }
}
