import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/deck.dart';
import '../models/flashcard.dart';
import '../models/user_model.dart';
import '../models/study_log.dart';
import '../data/default_decks.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ── Helpers ────────────────────────────────────────────

  String get _uid => _auth.currentUser!.uid;
  String get uid => _uid;

  DocumentReference<Map<String, dynamic>> get _userDoc =>
      _db.collection('users').doc(_uid);

  CollectionReference<Map<String, dynamic>> get _decksRef =>
      _userDoc.collection('decks');

  CollectionReference<Map<String, dynamic>> _cardsRef(String deckId) =>
      _decksRef.doc(deckId).collection('flashcards');

  CollectionReference<Map<String, dynamic>> get _studyLogsRef =>
      _db.collection('study_logs');

  // ── USER / STREAK ──────────────────────────────────────

  /// Lấy thông tin user — tạo document nếu chưa có.
  /// Seed bộ thẻ hệ thống SAU khi tạo xong (tránh race condition).
  Future<UserModel> getOrCreateUser() async {
    try {
      final doc = await _userDoc.get();

      if (doc.exists) {
        // Seed nếu flag chưa true — set flag SAU khi seed thành công
        if (doc.data()?['defaultDecksSeeded'] != true) {
          await seedDefaultDecks();
          await _userDoc.update({'defaultDecksSeeded': true});
        }
        return UserModel.fromFirestore(doc);
      }

      // User mới → tạo document với seeded = false trước
      final fbUser = _auth.currentUser!;
      final newUser = UserModel(
        uid: _uid,
        email: fbUser.email,
        displayName: fbUser.displayName,
        photoUrl: fbUser.photoURL,
        streakDays: 0,
        longestStreak: 0,
        lastStudyDate: null,
        createdAt: DateTime.now(),
      );
      await _userDoc.set({
        ...newUser.toFirestore(),
        'defaultDecksSeeded': false, // false trước — set true sau khi seed xong
      });
      await seedDefaultDecks();
      await _userDoc.update({'defaultDecksSeeded': true});
      debugPrint('✅ New user created + seeded: $_uid');
      return newUser;
    } catch (e) {
      debugPrint('❌ getOrCreateUser error: $e');
      rethrow;
    }
  }

  // ── SEED DEFAULT DECKS ─────────────────────────────────

  /// Tạo các bộ thẻ hệ thống (isSystem = true).
  /// Chỉ được gọi khi defaultDecksSeeded != true.
  Future<void> seedDefaultDecks() async {
    try {
      for (final deckData in kDefaultDecks) {
        final deck = Deck(
          name: deckData.name,
          description: deckData.description,
          color: deckData.color,
          cardCount: deckData.cards.length,
          isSystem: true,
        );
        final deckRef = await _decksRef.add(deck.toFirestore());

        final batch = _db.batch();
        final todayStr = DateTime.now().toIso8601String().substring(0, 10);

        for (final cardData in deckData.cards) {
          final cardRef = _cardsRef(deckRef.id).doc();
          batch.set(cardRef, {
            'front': cardData.front,
            'back': cardData.back,
            'pronunciation': cardData.pronunciation,
            'example': cardData.example,
            'deckId': deckRef.id,
            'easeFactor': 2.5,
            'interval': 0,
            'repetitions': 0,
            'nextReview': todayStr,
            'reviewCount': 0,
            'isLearned': false,
            'createdAt': Timestamp.fromDate(DateTime.now()),
          });
        }
        await batch.commit();
        debugPrint(
          '✅ Seeded deck "${deckData.name}" (${deckData.cards.length} cards)',
        );
      }
      debugPrint('✅ All default decks seeded successfully');
    } catch (e) {
      debugPrint('❌ seedDefaultDecks error: $e');
      // Không rethrow — seed thất bại không block user
    }
  }

  // ── STREAK ─────────────────────────────────────────────

  Future<UserModel> updateStreak() async {
    try {
      final doc = await _userDoc.get();
      final user = doc.exists
          ? UserModel.fromFirestore(doc)
          : await getOrCreateUser();

      final today = _dateOnly(DateTime.now());
      final lastDate = user.lastStudyDate != null
          ? _dateOnly(user.lastStudyDate!)
          : null;

      if (lastDate != null && lastDate == today) {
        debugPrint('✅ Streak: đã học hôm nay, giữ nguyên ${user.streakDays}');
        return user;
      }

      final yesterday = today.subtract(const Duration(days: 1));
      int newStreak;

      if (lastDate == null) {
        newStreak = 1;
      } else if (lastDate == yesterday) {
        newStreak = user.streakDays + 1;
      } else {
        newStreak = 1;
      }

      final newLongest = newStreak > user.longestStreak
          ? newStreak
          : user.longestStreak;

      await _userDoc.update({
        'chuoiNgayHoc': newStreak,
        'chuoiDaiNhat': newLongest,
        'ngayHocGanNhat': Timestamp.fromDate(today),
      });

      debugPrint('✅ Streak updated: $newStreak ngày (best: $newLongest)');

      return UserModel(
        uid: user.uid,
        email: user.email,
        displayName: user.displayName,
        photoUrl: user.photoUrl,
        streakDays: newStreak,
        longestStreak: newLongest,
        lastStudyDate: today,
        createdAt: user.createdAt,
      );
    } catch (e) {
      debugPrint('❌ updateStreak error: $e');
      rethrow;
    }
  }

  DateTime _dateOnly(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

  // ── DECK ───────────────────────────────────────────────

  Future<List<Deck>> getAllDecks() async {
    try {
      final snapshot = await _decksRef
          .orderBy('createdAt', descending: true)
          .get();

      final decks = snapshot.docs
          .map((doc) => Deck.fromFirestore(doc))
          .toList();

      final dueLists = await Future.wait(
        decks.map((d) => getDueCardsByDeck(d.id!)),
      );
      for (int i = 0; i < decks.length; i++) {
        decks[i] = decks[i].copyWith(dueCount: dueLists[i].length);
      }

      return decks;
    } catch (e) {
      debugPrint('❌ getAllDecks error: $e');
      rethrow;
    }
  }

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
      await _decksRef.doc(deckId).update({
        'cardCount': FieldValue.increment(-1),
      });
    } catch (e) {
      debugPrint('❌ deleteFlashcard error: $e');
      rethrow;
    }
  }

  // ── STUDY LOG ──────────────────────────────────────────

  Future<void> insertStudyLog(StudyLog log) async {
    try {
      await _studyLogsRef.add(log.toFirestore());
      debugPrint('✅ insertStudyLog: ${log.cardId} rated ${log.rating}');
    } catch (e) {
      debugPrint('❌ insertStudyLog error: $e');
    }
  }

  Future<List<StudyLog>> getStudyLogs({int? lastNDays}) async {
    try {
      Query<Map<String, dynamic>> query = _studyLogsRef
          .where('maNguoiDung', isEqualTo: _uid)
          .orderBy('thoiGianHoc', descending: true);

      if (lastNDays != null) {
        final since = DateTime.now().subtract(Duration(days: lastNDays));
        query = query.where(
          'thoiGianHoc',
          isGreaterThanOrEqualTo: Timestamp.fromDate(since),
        );
      }

      final snapshot = await query.get();
      return snapshot.docs.map((d) => StudyLog.fromFirestore(d)).toList();
    } catch (e) {
      debugPrint('❌ getStudyLogs error: $e');
      return [];
    }
  }
}
