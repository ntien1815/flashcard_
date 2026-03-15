import 'package:cloud_firestore/cloud_firestore.dart';

class Deck {
  final String? id; // ← Firestore document ID (String)
  String name;
  String? description;
  String? color;
  int cardCount;
  int dueCount; // runtime only — không lưu Firestore
  DateTime createdAt;

  Deck({
    this.id,
    required this.name,
    this.description,
    this.color = '#4CAF50',
    this.cardCount = 0,
    this.dueCount = 0,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Deck copyWith({
    String? id,
    String? name,
    String? description,
    String? color,
    int? cardCount,
    int? dueCount,
    DateTime? createdAt,
  }) {
    return Deck(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      color: color ?? this.color,
      cardCount: cardCount ?? this.cardCount,
      dueCount: dueCount ?? this.dueCount,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  // ── Firestore ──────────────────────────────────────────
  /// Đọc từ Firestore DocumentSnapshot
  factory Deck.fromFirestore(DocumentSnapshot doc) {
    final map = doc.data() as Map<String, dynamic>;
    return Deck(
      id: doc.id, // lấy từ document ID
      name: map['name'] ?? '',
      description: map['description'],
      color: map['color'] ?? '#4CAF50',
      cardCount: map['cardCount'] ?? 0,
      createdAt: (map['createdAt'] as Timestamp).toDate(),
    );
  }

  /// Ghi lên Firestore (không có id — Firestore tự quản lý)
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'description': description,
      'color': color,
      'cardCount': cardCount,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  // ── Legacy (giữ lại phòng cần) ─────────────────────────
  Map<String, dynamic> toMap() => toFirestore();

  factory Deck.fromMap(Map<String, dynamic> map) {
    return Deck(
      id: map['id'],
      name: map['name'] ?? '',
      description: map['description'],
      color: map['color'] ?? '#4CAF50',
      cardCount: map['cardCount'] ?? 0,
      createdAt: DateTime.parse(map['createdAt']),
    );
  }
}
