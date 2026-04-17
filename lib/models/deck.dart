import 'package:cloud_firestore/cloud_firestore.dart';

class Deck {
  final String? id;
  String name;
  String? description;
  String? color;
  int cardCount;
  int dueCount; // runtime only — không lưu Firestore
  bool isSystem; // true = bộ thẻ hệ thống, không cho xoá/thêm/xoá thẻ
  DateTime createdAt;

  Deck({
    this.id,
    required this.name,
    this.description,
    this.color = '#4CAF50',
    this.cardCount = 0,
    this.dueCount = 0,
    this.isSystem = false,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Deck copyWith({
    String? id,
    String? name,
    String? description,
    String? color,
    int? cardCount,
    int? dueCount,
    bool? isSystem,
    DateTime? createdAt,
  }) {
    return Deck(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      color: color ?? this.color,
      cardCount: cardCount ?? this.cardCount,
      dueCount: dueCount ?? this.dueCount,
      isSystem: isSystem ?? this.isSystem,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  // ── Firestore ──────────────────────────────────────────
  factory Deck.fromFirestore(DocumentSnapshot doc) {
    final map = doc.data() as Map<String, dynamic>;
    return Deck(
      id: doc.id,
      name: map['name'] ?? '',
      description: map['description'],
      color: map['color'] ?? '#4CAF50',
      cardCount: map['cardCount'] ?? 0,
      isSystem: map['isSystem'] ?? false,
      createdAt: (map['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'description': description,
      'color': color,
      'cardCount': cardCount,
      'isSystem': isSystem,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  // ── Legacy ─────────────────────────────────────────────
  Map<String, dynamic> toMap() => toFirestore();

  factory Deck.fromMap(Map<String, dynamic> map) {
    return Deck(
      id: map['id'],
      name: map['name'] ?? '',
      description: map['description'],
      color: map['color'] ?? '#4CAF50',
      cardCount: map['cardCount'] ?? 0,
      isSystem: map['isSystem'] ?? false,
      createdAt: DateTime.parse(map['createdAt']),
    );
  }
}
