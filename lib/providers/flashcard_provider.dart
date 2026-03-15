import 'package:flutter/foundation.dart';
import '../models/flashcard.dart';
import '../services/firestore_service.dart'; // ← đổi import

class FlashcardProvider with ChangeNotifier {
  final FirestoreService _db = FirestoreService(); // ← đổi service

  List<Flashcard> _flashcards = [];
  List<Flashcard> _dueCards = [];
  bool _isLoading = false;

  List<Flashcard> get flashcards => _flashcards;
  List<Flashcard> get dueCards => _dueCards;
  bool get isLoading => _isLoading;
  int get dueCount => _dueCards.length;

  Future<void> loadFlashcards(String deckId) async {
    // ← String
    _isLoading = true;
    notifyListeners();

    try {
      _flashcards = await _db.getFlashcardsByDeck(deckId);
      _dueCards = await _db.getDueCardsByDeck(deckId);
    } catch (e) {
      debugPrint('❌ loadFlashcards error: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> addFlashcard({
    required String deckId, // ← String
    required String front,
    required String back,
    String? example,
    String? pronunciation,
  }) async {
    try {
      final card = Flashcard(
        deckId: deckId,
        front: front,
        back: back,
        example: example,
        pronunciation: pronunciation,
      );
      final id = await _db.insertFlashcard(card);
      _flashcards.add(card.copyWith(id: id));
      notifyListeners();
    } catch (e) {
      debugPrint('❌ addFlashcard error: $e');
      rethrow;
    }
  }

  Future<void> updateFlashcard(Flashcard card) async {
    try {
      await _db.updateFlashcard(card);
      final index = _flashcards.indexWhere((c) => c.id == card.id);
      if (index != -1) {
        _flashcards[index] = card;
        _dueCards = _flashcards.where((c) {
          final today = DateTime.now();
          return c.nextReview.isBefore(today) ||
              _isSameDay(c.nextReview, today);
        }).toList();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('❌ updateFlashcard error: $e');
      rethrow;
    }
  }

  Future<void> deleteFlashcard(String id, String deckId) async {
    // ← String
    try {
      await _db.deleteFlashcard(id, deckId);
      _flashcards.removeWhere((c) => c.id == id);
      _dueCards.removeWhere((c) => c.id == id);
      notifyListeners();
    } catch (e) {
      debugPrint('❌ deleteFlashcard error: $e');
      rethrow;
    }
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  void clear() {
    _flashcards = [];
    _dueCards = [];
    notifyListeners();
  }
}
