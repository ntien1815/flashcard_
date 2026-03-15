import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/deck.dart';
import '../models/flashcard.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ── Helpers ────────────────────────────────────────────

  /// Collection decks của user hiện tại
  CollectionReference<Map<String, dynamic>> get _decksRef {
    final uid = _auth.currentUser!.uid;
    return _db.collection('users').doc(uid).collection('decks');
  }

  /// Collection flashcards trong 1 deck
  CollectionReference<Map<String, dynamic>> _cardsRef(String deckId) {
    final uid = _auth.currentUser!.uid;
    return _db
        .collection('users')
        .doc(uid)
        .collection('decks')
        .doc(deckId)
        .collection('flashcards');
  }

  // ── DECK ───────────────────────────────────────────────

  Future<List<Deck>> getAllDecks() async {
    try {
      final snapshot = await _decksRef
          .orderBy('createdAt', descending: true)
          .get();

      final decks = snapshot.docs
          .map((doc) => Deck.fromFirestore(doc))
          .toList();

      // Tính dueCount cho mỗi deck
      for (int i = 0; i < decks.length; i++) {
        final due = await getDueCardsByDeck(decks[i].id!);
        decks[i] = decks[i].copyWith(dueCount: due.length);
      }

      return decks;
    } catch (e) {
      debugPrint('❌ getAllDecks error: $e');
      rethrow;
    }
  }

  /// Trả về String id của document vừa tạo
  Future<String> insertDeck(Deck deck) async {
    try {
      final docRef = await _decksRef.add(deck.toFirestore());
      debugPrint('✅ insertDeck: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      debugPrint('❌ insertDeck error: $e');
      rethrow;
    }
  }

  Future<void> updateDeck(Deck deck) async {
    try {
      await _decksRef.doc(deck.id).update(deck.toFirestore());
    } catch (e) {
      debugPrint('❌ updateDeck error: $e');
      rethrow;
    }
  }

  /// Xoá deck + toàn bộ flashcards bên trong (batch write)
  Future<void> deleteDeck(String id) async {
    try {
      final cardsSnapshot = await _cardsRef(id).get();
      final batch = _db.batch();

      for (final doc in cardsSnapshot.docs) {
        batch.delete(doc.reference);
      }
      batch.delete(_decksRef.doc(id));

      await batch.commit();
      debugPrint('✅ deleteDeck: $id (${cardsSnapshot.size} cards removed)');
    } catch (e) {
      debugPrint('❌ deleteDeck error: $e');
      rethrow;
    }
  }

  // ── FLASHCARD ──────────────────────────────────────────

  Future<List<Flashcard>> getFlashcardsByDeck(String deckId) async {
    try {
      final snapshot = await _cardsRef(
        deckId,
      ).orderBy('createdAt', descending: false).get();
      return snapshot.docs.map((doc) => Flashcard.fromFirestore(doc)).toList();
    } catch (e) {
      debugPrint('❌ getFlashcardsByDeck error: $e');
      rethrow;
    }
  }

  /// Lấy thẻ đến hạn ôn hôm nay (nextReview <= today)
  Future<List<Flashcard>> getDueCardsByDeck(String deckId) async {
    try {
      final today = DateTime.now().toIso8601String().substring(0, 10);
      final snapshot = await _cardsRef(
        deckId,
      ).where('nextReview', isLessThanOrEqualTo: today).get();
      return snapshot.docs.map((doc) => Flashcard.fromFirestore(doc)).toList();
    } catch (e) {
      debugPrint('❌ getDueCardsByDeck error: $e');
      rethrow;
    }
  }

  Future<String> insertFlashcard(Flashcard card) async {
    try {
      final docRef = await _cardsRef(card.deckId).add(card.toFirestore());
      // Tăng cardCount của deck
      await _decksRef.doc(card.deckId).update({
        'cardCount': FieldValue.increment(1),
      });
      debugPrint('✅ insertFlashcard: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      debugPrint('❌ insertFlashcard error: $e');
      rethrow;
    }
  }

  Future<void> updateFlashcard(Flashcard card) async {
    try {
      await _cardsRef(card.deckId).doc(card.id).update(card.toFirestore());
    } catch (e) {
      debugPrint('❌ updateFlashcard error: $e');
      rethrow;
    }
  }

  Future<void> deleteFlashcard(String id, String deckId) async {
    try {
      await _cardsRef(deckId).doc(id).delete();
      // Giảm cardCount của deck
      await _decksRef.doc(deckId).update({
        'cardCount': FieldValue.increment(-1),
      });
    } catch (e) {
      debugPrint('❌ deleteFlashcard error: $e');
      rethrow;
    }
  }
}
