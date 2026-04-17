# FlashLearn - Ứng dụng học Flashcard thông minh

Ứng dụng học từ vựng theo phương pháp **Spaced Repetition (SM-2)** được xây dựng bằng Flutter + Firebase. Hỗ trợ nhận diện giọng nói, đọc bài báo tiếng Anh, thống kê học tập và nhiều tính năng gamification.

---

## Tính năng chính

### Xác thực
- Đăng nhập bằng **Google Sign-In**
- Đăng nhập / Đăng ký bằng **Email & Mật khẩu**
- Đặt lại mật khẩu qua email

### Học Flashcard (Spaced Repetition)
- Thuật toán **SM-2** lên lịch ôn tập tối ưu theo khoảng cách
- Lật thẻ với hiệu ứng animation
- **Nhập giọng nói** (Speech-to-Text) để luyện phát âm
- **Đọc to** (Text-to-Speech) để luyện nghe
- Đánh giá độ khó (0-5) ảnh hưởng đến lịch ôn tập

### Quản lý Deck
- Tạo deck tùy chỉnh (tên, mô tả, màu sắc)
- Deck hệ thống (được seed sẵn, chỉ đọc)
- Thêm / sửa / xóa flashcard riêng lẻ
- Mỗi thẻ có: mặt trước, mặt sau, phát âm, ví dụ

### Thống kê học tập
- Biểu đồ đường & cột (thư viện `fl_chart`)
- Lọc theo khoảng thời gian: 7 / 30 / 90 ngày
- Số thẻ học mỗi ngày, tỉ lệ trả lời đúng

### Gamification
- **Streak** học liên tiếp (hiện tại & cao nhất)
- Lịch tuần (week dots) hiển thị ngày đã học
- Nhật ký học tập (study logs) có timestamp

### Đọc bài báo tiếng Anh
- Lấy bài báo từ **GNews API**
- Dịch sang tiếng Việt bằng **MyMemory API**
- Cache 6 giờ trên Firestore để tiết kiệm API call

### Thông báo & Cài đặt
- Nhắc nhở học mỗi ngày (giờ tùy chỉnh)
- Hỗ trợ múi giờ **Asia/Ho_Chi_Minh**
- Chuyển đổi **Light / Dark mode**

---

## Kiến trúc & Công nghệ

| Lớp | Chi tiết |
|-----|----------|
| **UI** | Flutter Material 3, custom `AppColors` ThemeExtension |
| **State** | Provider pattern (`ChangeNotifier`) |
| **Backend** | Firebase Auth + Cloud Firestore |
| **Algorithm** | SM-2 Spaced Repetition, Levenshtein Distance (fuzzy match) |
| **APIs** | GNews (tin tức), MyMemory (dịch thuật) |
| **Notifications** | `flutter_local_notifications` + `timezone` |
| **Voice** | `speech_to_text` + `flutter_tts` |

---

## Cấu trúc thư mục

```
lib/
├── main.dart                     # Entry point, theme & auth setup
├── firebase_options.dart         # Firebase config
├── data/
│   └── default_decks.dart        # Deck mặc định được seed khi đăng ký
├── models/
│   ├── deck.dart                 # Model Deck
│   ├── flashcard.dart            # Model Flashcard (có SM-2 fields)
│   ├── user_model.dart           # Model User (streak, week dots)
│   ├── study_log.dart            # Model nhật ký học tập
│   └── article_model.dart        # Model bài báo
├── providers/
│   ├── deck_provider.dart        # State quản lý danh sách deck
│   └── flashcard_provider.dart   # State quản lý flashcard
├── services/
│   ├── auth_service.dart         # Firebase Auth
│   ├── firestore_service.dart    # Firestore CRUD & streak logic
│   ├── notification_service.dart # Thông báo nhắc nhở
│   └── news_service.dart         # GNews + dịch thuật
├── screens/
│   ├── login_screen.dart         # Màn hình đăng nhập
│   ├── home_screen.dart          # Dashboard (4 tab)
│   ├── decks_tab_screen.dart     # Danh sách deck
│   ├── deck_detail_screen.dart   # Chi tiết deck
│   ├── add_deck_screen.dart      # Tạo deck mới
│   ├── add_card_screen.dart      # Thêm / sửa flashcard
│   ├── study_screen.dart         # Màn hình học (SM-2 + voice)
│   ├── stats_screen.dart         # Thống kê học tập
│   ├── reading_screen.dart       # Đọc bài báo tiếng Anh
│   └── profile_screen.dart       # Hồ sơ & cài đặt
└── theme/
    └── app_colors.dart           # Màu sắc light/dark theme
```

---

## Cài đặt & Chạy

### Yêu cầu
- Flutter SDK `^3.11.1`
- Firebase project (Auth + Firestore)
- GNews API key (tùy chọn, cho tính năng đọc báo)

### Bước 1 — Clone & cài dependencies
```bash
git clone <repo-url>
cd flashcard_app
flutter pub get
```

### Bước 2 — Cấu hình Firebase
Đặt file `google-services.json` (Android) và `GoogleService-Info.plist` (iOS) vào đúng thư mục theo hướng dẫn FlutterFire.

### Bước 3 — Tạo file `.env`
```
GNEWS_API_KEY=your_gnews_api_key_here
```

### Bước 4 — Chạy ứng dụng
```bash
flutter run
```

---

## Dependencies chính

| Package | Phiên bản | Mục đích |
|---------|-----------|----------|
| `provider` | ^6.1.1 | State management |
| `firebase_core` | ^4.5.0 | Firebase init |
| `firebase_auth` | ^6.2.0 | Xác thực |
| `cloud_firestore` | ^6.1.3 | Cloud database |
| `google_sign_in` | ^6.2.1 | Google OAuth |
| `speech_to_text` | ^7.3.0 | Nhận diện giọng nói |
| `flutter_tts` | ^4.2.5 | Text-to-speech |
| `fl_chart` | ^1.1.1 | Biểu đồ thống kê |
| `flutter_local_notifications` | ^21.0.0 | Thông báo |
| `timezone` | ^0.11.0 | Múi giờ |
| `http` | ^1.2.0 | Gọi REST API |
| `flutter_dotenv` | ^5.1.0 | Quản lý biến môi trường |
| `shared_preferences` | ^2.2.2 | Lưu cài đặt local |
| `intl` | ^0.19.0 | Định dạng ngày giờ |
| `uuid` | ^4.2.1 | Tạo ID duy nhất |
| `sqflite` | ^2.3.0 | SQLite local |
| `csv` | ^7.2.0 | Import/export CSV |
| `file_picker` | ^11.0.2 | Chọn file |

---

## Tác giả

Nhut Tien — trannhuttien9@gmail.com
