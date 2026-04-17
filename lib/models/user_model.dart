import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String? email;
  final String? displayName;
  final String? photoUrl;
  final int streakDays; // chuỗi ngày học hiện tại
  final int longestStreak; // chuỗi dài nhất từ trước đến nay
  final DateTime? lastStudyDate; // ngày học gần nhất
  final DateTime createdAt;

  const UserModel({
    required this.uid,
    this.email,
    this.displayName,
    this.photoUrl,
    this.streakDays = 0,
    this.longestStreak = 0,
    this.lastStudyDate,
    required this.createdAt,
  });

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final map = doc.data() as Map<String, dynamic>? ?? {};
    return UserModel(
      uid: doc.id,
      email: map['email'],
      displayName: map['tenHienThi'],
      photoUrl: map['anhDaiDien'],
      streakDays: map['chuoiNgayHoc'] ?? 0,
      longestStreak: map['chuoiDaiNhat'] ?? 0,
      lastStudyDate: map['ngayHocGanNhat'] != null
          ? (map['ngayHocGanNhat'] as Timestamp).toDate()
          : null,
      createdAt: map['ngayTao'] != null
          ? (map['ngayTao'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'email': email,
      'tenHienThi': displayName,
      'anhDaiDien': photoUrl,
      'chuoiNgayHoc': streakDays,
      'chuoiDaiNhat': longestStreak,
      'ngayHocGanNhat': lastStudyDate != null
          ? Timestamp.fromDate(lastStudyDate!)
          : null,
      'ngayTao': Timestamp.fromDate(createdAt),
    };
  }

  /// 7 ô ngày trong tuần (T2→CN), mỗi ô = true nếu nằm trong chuỗi streak hiện tại
  List<bool> get weekDots {
    if (lastStudyDate == null || streakDays == 0) return List.filled(7, false);

    final today = DateTime.now();
    final todayIdx = today.weekday - 1; // Mon=0..Sun=6

    // Tập hợp các ngày thuộc streak (tính lùi từ lastStudyDate)
    final studiedDates = <String>{};
    for (int i = 0; i < streakDays && i <= 6; i++) {
      final d = lastStudyDate!.subtract(Duration(days: i));
      studiedDates.add(_dateKey(d));
    }

    return List.generate(7, (i) {
      // i=0 → T2 của tuần hiện tại
      final monday = today.subtract(Duration(days: todayIdx));
      final day = monday.add(Duration(days: i));
      return studiedDates.contains(_dateKey(day));
    });
  }

  static String _dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
