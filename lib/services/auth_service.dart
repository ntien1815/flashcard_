import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  /// Stream lắng nghe trạng thái đăng nhập — dùng trong main.dart
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// User hiện tại (null nếu chưa đăng nhập)
  User? get currentUser => _auth.currentUser;

  /// Đăng nhập bằng Google
  Future<UserCredential?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        debugPrint('⚠️ User cancelled Google Sign-In');
        return null; // User tự bấm cancel
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);
      debugPrint('✅ Signed in: ${userCredential.user?.email}');
      return userCredential;
    } catch (e) {
      debugPrint('❌ signInWithGoogle error: $e');
      rethrow;
    }
  }

  /// Đăng xuất
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      await _auth.signOut();
      debugPrint('✅ Signed out');
    } catch (e) {
      debugPrint('❌ signOut error: $e');
      rethrow;
    }
  }
}