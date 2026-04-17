import 'package:cloud_firestore/cloud_firestore.dart';

class StudyLog {
  final String? id;
  final String userId;
  final String deckId;
  final String cardId;
  final int rating; // 0=Quên, 2=Khó, 3=Được, 5=Dễ
  final bool isCorrect;
  final String studyMode; // "flashcard" hoặc "quiz"
  final DateTime studiedAt;

  StudyLog({
    this.id,
    required this.userId,
    required this.deckId,
    required this.cardId,
    required this.rating,
    required this.isCorrect,
    required this.studyMode,
    DateTime? studiedAt,
  }) : studiedAt = studiedAt ?? DateTime.now();

  factory StudyLog.fromFirestore(DocumentSnapshot doc) {
    final map = doc.data() as Map<String, dynamic>;
    return StudyLog(
      id: doc.id,
      userId: map['maNguoiDung'] ?? '',
      deckId: map['maBoThe'] ?? '',
      cardId: map['maThe'] ?? '',
      rating: map['mucDanhGia'] ?? 0,
      isCorrect: map['ketQuaDungSai'] ?? false,
      studyMode: map['cheDoHoc'] ?? 'flashcard',
      studiedAt: (map['thoiGianHoc'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'maNguoiDung': userId,
      'maBoThe': deckId,
      'maThe': cardId,
      'mucDanhGia': rating,
      'ketQuaDungSai': isCorrect,
      'cheDoHoc': studyMode,
      'thoiGianHoc': Timestamp.fromDate(studiedAt),
    };
  }
}
