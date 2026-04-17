import 'package:flutter/foundation.dart';
import '../models/deck.dart';
import '../services/firestore_service.dart';

class DeckProvider with ChangeNotifier {
  final FirestoreService _db = FirestoreService(); // ← đổi service

  List<Deck> _decks = [];
  bool _isLoading = false;

  List<Deck> get decks => _decks;
  bool get isLoading => _isLoading;
  int get totalDueCards => _decks.fold(0, (sum, d) => sum + d.dueCount);

  Future<void> loadDecks() async {
    _isLoading = true;
    notifyListeners();

    try {
      _decks = await _db.getAllDecks();
    } catch (e) {
      debugPrint('❌ loadDecks error: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> addDeck(String name, String description) async {
    try {
      final deck = Deck(
        name: name,
        description: description,
        createdAt: DateTime.now(),
      );
      final id = await _db.insertDeck(deck);
      _decks.insert(0, deck.copyWith(id: id));
      notifyListeners();
    } catch (e) {
      debugPrint('❌ addDeck error: $e');
      rethrow;
    }
  }

  Future<void> updateDeck(Deck deck) async {
    try {
      await _db.updateDeck(deck);
      final index = _decks.indexWhere((d) => d.id == deck.id);
      if (index != -1) {
        _decks[index] = deck;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('❌ updateDeck error: $e');
      rethrow;
    }
  }

  Future<void> deleteDeck(String id) async {
    // ← String
    try {
      await _db.deleteDeck(id);
      _decks.removeWhere((d) => d.id == id);
      notifyListeners();
    } catch (e) {
      debugPrint('❌ deleteDeck error: $e');
      rethrow;
    }
  }

  /// Gọi sau khi thêm/xoá thẻ để cập nhật badge
  void refreshDueCount(String deckId, int newDueCount) {
    final index = _decks.indexWhere((d) => d.id == deckId);
    if (index != -1) {
      _decks[index] = _decks[index].copyWith(dueCount: newDueCount);
      notifyListeners();
    }
  }
}
