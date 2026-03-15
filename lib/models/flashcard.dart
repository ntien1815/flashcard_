import 'package:cloud_firestore/cloud_firestore.dart';

class Flashcard {
  final String? id; // ← Firestore document ID
  final String deckId; // ← reference đến Deck (String)
  final String front;
  final String back;
  final String? example;
  final String? pronunciation;
  int reviewCount;
  bool isLearned;
  DateTime createdAt;

  // SM-2 fields
  double easeFactor;
  int interval;
  int repetitions;
  DateTime nextReview;

  Flashcard({
    this.id,
    required this.deckId,
    required this.front,
    required this.back,
    this.example,
    this.pronunciation,
    this.reviewCount = 0,
    this.isLearned = false,
    DateTime? createdAt,
    this.easeFactor = 2.5,
    this.interval = 1,
    this.repetitions = 0,
    DateTime? nextReview,
  }) : createdAt = createdAt ?? DateTime.now(),
       nextReview = nextReview ?? DateTime.now();

  Flashcard copyWith({
    String? id,
    String? deckId,
    String? front,
    String? back,
    String? example,
    String? pronunciation,
    int? reviewCount,
    bool? isLearned,
    DateTime? createdAt,
    double? easeFactor,
    int? interval,
    int? repetitions,
    DateTime? nextReview,
  }) {
    return Flashcard(
      id: id ?? this.id,
      deckId: deckId ?? this.deckId,
      front: front ?? this.front,
      back: back ?? this.back,
      example: example ?? this.example,
      pronunciation: pronunciation ?? this.pronunciation,
      reviewCount: reviewCount ?? this.reviewCount,
      isLearned: isLearned ?? this.isLearned,
      createdAt: createdAt ?? this.createdAt,
      easeFactor: easeFactor ?? this.easeFactor,
      interval: interval ?? this.interval,
      repetitions: repetitions ?? this.repetitions,
      nextReview: nextReview ?? this.nextReview,
    );
  }

  // ── Firestore ──────────────────────────────────────────
  factory Flashcard.fromFirestore(DocumentSnapshot doc) {
    final map = doc.data() as Map<String, dynamic>;
    return Flashcard(
      id: doc.id,
      deckId: map['deckId'] ?? '',
      front: map['front'] ?? '',
      back: map['back'] ?? '',
      example: map['example'],
      pronunciation: map['pronunciation'],
      reviewCount: map['reviewCount'] ?? 0,
      isLearned: map['isLearned'] ?? false, // ← bool trực tiếp, không phải 0/1
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      easeFactor: (map['easeFactor'] ?? 2.5).toDouble(),
      interval: map['interval'] ?? 1,
      repetitions: map['repetitions'] ?? 0,
      nextReview: map['nextReview'] != null
          ? DateTime.parse(map['nextReview'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'deckId': deckId,
      'front': front,
      'back': back,
      'example': example,
      'pronunciation': pronunciation,
      'reviewCount': reviewCount,
      'isLearned': isLearned, // ← bool trực tiếp
      'createdAt': Timestamp.fromDate(createdAt),
      'easeFactor': easeFactor,
      'interval': interval,
      'repetitions': repetitions,
      'nextReview': nextReview.toIso8601String().substring(
        0,
        10,
      ), // "yyyy-MM-dd"
    };
  }

  // ── Legacy ─────────────────────────────────────────────
  Map<String, dynamic> toMap() => toFirestore();
}
