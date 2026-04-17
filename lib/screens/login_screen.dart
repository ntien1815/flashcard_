import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../theme/app_colors.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  bool _isLoading = false;
  bool _isGoogleLoading = false;
  bool _obscurePassword = true;
  bool _isLoginMode = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  void _setLoading(bool value) {
    if (mounted) setState(() => _isLoading = value);
  }

  void _setGoogleLoading(bool value) {
    if (mounted) setState(() => _isGoogleLoading = value);
  }

  void _showError(String msg) {
    if (!mounted) return;
    final c = AppColors.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(color: Colors.white)),
        backgroundColor: c.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }

  void _showSuccess(String msg) {
    if (!mounted) return;
    final c = AppColors.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(color: Colors.white)),
        backgroundColor: c.teal,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }

  Future<void> _handleGoogleSignIn() async {
    _setGoogleLoading(true);
    try {
      final user = await AuthService().signInWithGoogle();
      if (user == null && mounted) {
        _showError('Đăng nhập Google bị huỷ.');
      }
    } on FirebaseAuthException catch (e) {
      debugPrint(
        '[LoginScreen] Google sign-in FirebaseAuthException: ${e.code} - ${e.message}',
      );
      _showError(_friendlyFirebaseError(e.code));
    } catch (e) {
      debugPrint('[LoginScreen] Google sign-in error: $e');
      _showError('Đăng nhập Google thất bại. Vui lòng thử lại.');
    } finally {
      _setGoogleLoading(false);
    }
  }

  Future<void> _handleEmailAuth() async {
    if (!_formKey.currentState!.validate()) return;

    _setLoading(true);
    try {
      if (_isLoginMode) {
        await AuthService().signInWithEmail(
          _emailCtrl.text.trim(),
          _passwordCtrl.text,
        );
      } else {
        await AuthService().registerWithEmail(
          _emailCtrl.text.trim(),
          _passwordCtrl.text,
        );
        _showSuccess('Đăng ký thành công! Vui lòng xác nhận email.');
        if (mounted) setState(() => _isLoginMode = true);
      }
    } on FirebaseAuthException catch (e) {
      debugPrint(
        '[LoginScreen] Email auth FirebaseAuthException: ${e.code} - ${e.message}',
      );
      _showError(_friendlyFirebaseError(e.code));
    } catch (e) {
      debugPrint('[LoginScreen] Email auth error: $e');
      _showError('Có lỗi xảy ra. Vui lòng thử lại.');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> _handleForgotPassword() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) {
      _showError('Nhập email trước để đặt lại mật khẩu.');
      return;
    }

    try {
      await AuthService().sendPasswordReset(email);
      _showSuccess('Đã gửi email đặt lại mật khẩu.');
    } on FirebaseAuthException catch (e) {
      debugPrint('[LoginScreen] Reset password error: ${e.code}');
      _showError(_friendlyFirebaseError(e.code));
    } catch (e) {
      debugPrint('[LoginScreen] Reset password unexpected: $e');
      _showError('Không thể gửi email. Vui lòng thử lại.');
    }
  }

  String _friendlyFirebaseError(String code) {
    switch (code) {
      case 'user-not-found':
        return 'Không tìm thấy tài khoản với email này.';
      case 'wrong-password':
        return 'Mật khẩu không đúng.';
      case 'invalid-email':
        return 'Email không hợp lệ.';
      case 'email-already-in-use':
        return 'Email này đã được sử dụng.';
      case 'weak-password':
        return 'Mật khẩu quá yếu (tối thiểu 6 ký tự).';
      case 'network-request-failed':
        return 'Không có kết nối mạng.';
      case 'too-many-requests':
        return 'Quá nhiều lần thử. Hãy thử lại sau.';
      case 'invalid-credential':
        return 'Thông tin đăng nhập không hợp lệ.';
      default:
        return 'Lỗi: $code';
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Scaffold(
      backgroundColor: c.bodyBg,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              _buildHeroSection(c),
              _buildFormSection(c),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeroSection(AppColors c) {
    return Container(
      width: double.infinity,
      color: c.primary,
      padding: const EdgeInsets.fromLTRB(24, 36, 24, 28),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: c.primaryLight,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(Icons.menu_book_rounded, color: c.primaryDark, size: 34),
          ),
          const SizedBox(height: 14),
          const Text(
            'FlashLearn',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w500,
              color: Colors.white,
              letterSpacing: .2,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'Học từ vựng thông minh mỗi ngày',
            style: TextStyle(fontSize: 12, color: c.primaryLighter),
          ),
        ],
      ),
    );
  }

  Widget _buildFormSection(AppColors c) {
    return Container(
      color: c.bodyBg,
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildGoogleButton(c),
            const SizedBox(height: 16),
            _buildDivider(c),
            const SizedBox(height: 16),
            _buildEmailField(c),
            const SizedBox(height: 10),
            _buildPasswordField(c),
            const SizedBox(height: 18),
            _buildPrimaryButton(c),
            const SizedBox(height: 14),
            _buildSwitchModeRow(c),
            const SizedBox(height: 8),
            if (_isLoginMode) _buildForgotPasswordButton(c),
          ],
        ),
      ),
    );
  }

  Widget _buildGoogleButton(AppColors c) {
    return OutlinedButton(
      onPressed: _isGoogleLoading || _isLoading ? null : _handleGoogleSignIn,
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: c.border, width: 0.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        padding: const EdgeInsets.symmetric(vertical: 12),
        backgroundColor: c.surface,
      ),
      child: _isGoogleLoading
          ? SizedBox(
              height: 18,
              width: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: c.primary),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildGoogleIcon(),
                const SizedBox(width: 10),
                Text(
                  'Tiếp tục với Google',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: c.textPrimary,
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildGoogleIcon() {
    return SizedBox(
      width: 20,
      height: 20,
      child: CustomPaint(painter: _GoogleLogoPainter()),
    );
  }

  Widget _buildDivider(AppColors c) {
    return Row(
      children: [
        Expanded(child: Divider(thickness: 0.5, color: c.border)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text('hoặc', style: TextStyle(fontSize: 12, color: c.textSecondary)),
        ),
        Expanded(child: Divider(thickness: 0.5, color: c.border)),
      ],
    );
  }

  Widget _buildEmailField(AppColors c) {
    return TextFormField(
      controller: _emailCtrl,
      keyboardType: TextInputType.emailAddress,
      textInputAction: TextInputAction.next,
      decoration: _inputDecoration(
        c: c,
        hint: 'Email',
        prefixIcon: Icons.alternate_email_rounded,
      ),
      validator: (v) {
        if (v == null || v.trim().isEmpty) return 'Vui lòng nhập email.';
        if (!RegExp(r'^[\w-.]+@([\w-]+\.)+[\w]{2,}$').hasMatch(v.trim())) {
          return 'Email không hợp lệ.';
        }
        return null;
      },
    );
  }

  Widget _buildPasswordField(AppColors c) {
    return TextFormField(
      controller: _passwordCtrl,
      obscureText: _obscurePassword,
      textInputAction: TextInputAction.done,
      onFieldSubmitted: (_) => _handleEmailAuth(),
      decoration: _inputDecoration(
        c: c,
        hint: 'Mật khẩu',
        prefixIcon: Icons.lock_outline_rounded,
        suffix: IconButton(
          icon: Icon(
            _obscurePassword
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
            size: 18,
            color: c.textSecondary,
          ),
          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
        ),
      ),
      validator: (v) {
        if (v == null || v.isEmpty) return 'Vui lòng nhập mật khẩu.';
        if (!_isLoginMode && v.length < 6) return 'Mật khẩu tối thiểu 6 ký tự.';
        return null;
      },
    );
  }

  Widget _buildPrimaryButton(AppColors c) {
    return FilledButton(
      onPressed: _isLoading || _isGoogleLoading ? null : _handleEmailAuth,
      style: FilledButton.styleFrom(
        backgroundColor: c.primary,
        disabledBackgroundColor: c.primaryLight,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        padding: const EdgeInsets.symmetric(vertical: 13),
      ),
      child: _isLoading
          ? const SizedBox(
              height: 18,
              width: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            )
          : Text(
              _isLoginMode ? 'Đăng nhập' : 'Đăng ký',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
            ),
    );
  }

  Widget _buildSwitchModeRow(AppColors c) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          _isLoginMode ? 'Chưa có tài khoản? ' : 'Đã có tài khoản? ',
          style: TextStyle(fontSize: 12, color: c.textSecondary),
        ),
        GestureDetector(
          onTap: () => setState(() {
            _isLoginMode = !_isLoginMode;
            _formKey.currentState?.reset();
          }),
          child: Text(
            _isLoginMode ? 'Đăng ký ngay' : 'Đăng nhập',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: c.primary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildForgotPasswordButton(AppColors c) {
    return Center(
      child: TextButton(
        onPressed: _handleForgotPassword,
        style: TextButton.styleFrom(
          foregroundColor: c.textSecondary,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        ),
        child: const Text('Quên mật khẩu?', style: TextStyle(fontSize: 12)),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required AppColors c,
    required String hint,
    required IconData prefixIcon,
    Widget? suffix,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(fontSize: 13, color: c.textSecondary),
      prefixIcon: Icon(prefixIcon, size: 18, color: c.textSecondary),
      suffixIcon: suffix,
      filled: true,
      fillColor: c.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: c.border, width: 0.5),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: c.border, width: 0.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: c.primary, width: 1.2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: c.error, width: 0.8),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: c.error, width: 1.2),
      ),
      errorStyle: TextStyle(fontSize: 11, color: c.error),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final blue = Paint()..color = const Color(0xFF4285F4);
    final red = Paint()..color = const Color(0xFFEA4335);
    final yellow = Paint()..color = const Color(0xFFFBBC05);
    final green = Paint()..color = const Color(0xFF34A853);

    final path = Path();

    canvas.save();
    canvas.clipPath(Path()..addOval(Rect.fromLTWH(0, 0, w, h)));

    path
      ..reset()
      ..moveTo(w * 0.5, h * 0.5)
      ..arcTo(Rect.fromLTWH(0, 0, w, h), -2.36, 1.57, false)
      ..close();
    canvas.drawPath(path, red);

    path
      ..reset()
      ..moveTo(w * 0.5, h * 0.5)
      ..arcTo(Rect.fromLTWH(0, 0, w, h), -0.79, 1.57, false)
      ..close();
    canvas.drawPath(path, blue);
    canvas.drawRect(Rect.fromLTWH(w * 0.5, h * 0.35, w * 0.5, h * 0.3), blue);

    path
      ..reset()
      ..moveTo(w * 0.5, h * 0.5)
      ..arcTo(Rect.fromLTWH(0, 0, w, h), 0.79, 1.57, false)
      ..close();
    canvas.drawPath(path, green);

    path
      ..reset()
      ..moveTo(w * 0.5, h * 0.5)
      ..arcTo(Rect.fromLTWH(0, 0, w, h), 2.36, 1.57, false)
      ..close();
    canvas.drawPath(path, yellow);

    canvas.drawCircle(
      Offset(w * 0.5, h * 0.5),
      w * 0.32,
      Paint()..color = Colors.white,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
