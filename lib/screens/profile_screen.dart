import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../theme/app_colors.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../services/notification_service.dart';
import '../models/user_model.dart';
import '../main.dart';

class ProfileBody extends StatefulWidget {
  const ProfileBody({super.key});
  @override
  State<ProfileBody> createState() => _ProfileBodyState();
}

class _ProfileBodyState extends State<ProfileBody> {
  final FirestoreService _fs = FirestoreService();
  UserModel? _user;
  bool _isLoading = true;
  int _totalReviews = 0;
  int _totalCorrect = 0;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);
    try {
      final user = await _fs.getOrCreateUser();
      final logs = await _fs.getStudyLogs();
      if (mounted) {
        setState(() {
          _user = user;
          _totalReviews = logs.length;
          _totalCorrect = logs.where((l) => l.isCorrect).length;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('ProfileBody load error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    if (_isLoading) {
      return Center(child: CircularProgressIndicator(color: c.primary));
    }

    final fbUser = FirebaseAuth.instance.currentUser;
    final displayName = fbUser?.displayName ?? fbUser?.email ?? 'Người dùng';
    final email = fbUser?.email ?? '';
    final accuracy = _totalReviews > 0
        ? (_totalCorrect / _totalReviews * 100).round()
        : 0;

    return RefreshIndicator(
      color: c.primary,
      onRefresh: _loadProfile,
      child: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          // ── Avatar + Info ──
          _buildProfileCard(c, displayName, email),
          const SizedBox(height: 18),

          // ── Thành tích ──
          _buildSectionLabel(c, 'THÀNH TÍCH'),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _statCard(
                  c,
                  Icons.local_fire_department_rounded,
                  '${_user?.streakDays ?? 0}',
                  'Chuỗi ngày',
                  c.coral,
                  c.coralBg,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _statCard(
                  c,
                  Icons.emoji_events_rounded,
                  '${_user?.longestStreak ?? 0}',
                  'Kỷ lục',
                  c.amber,
                  c.amberBg,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _statCard(
                  c,
                  Icons.style_rounded,
                  '$_totalReviews',
                  'Tổng lượt ôn',
                  c.primary,
                  c.primaryBg,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _statCard(
                  c,
                  Icons.check_circle_outline_rounded,
                  '$accuracy%',
                  'Chính xác',
                  c.teal,
                  c.tealBg,
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),

          // ── Cài đặt ──
          _buildSectionLabel(c, 'CÀI ĐẶT'),
          const SizedBox(height: 10),
          _buildSettingsCard(c),
          const SizedBox(height: 22),

          // ── Đăng xuất ──
          _buildLogoutButton(c),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildProfileCard(AppColors c, String name, String email) {
    final initials = _getInitials(name);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [c.primary, c.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                initials,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (email.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    email,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('🔥', style: TextStyle(fontSize: 10)),
                      const SizedBox(width: 4),
                      Text(
                        '${_user?.streakDays ?? 0} ngày liên tiếp',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statCard(
    AppColors c,
    IconData icon,
    String value,
    String label,
    Color color,
    Color bg,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.border.withValues(alpha: 0.3), width: 0.5),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
              Text(
                label,
                style: TextStyle(fontSize: 10, color: c.textSecondary),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsCard(AppColors c) {
    final themeProvider = context.watch<ThemeProvider>();

    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.border.withValues(alpha: 0.3), width: 0.5),
      ),
      child: Column(
        children: [
          // Dark mode
          _settingsTile(
            c: c,
            icon: themeProvider.isDark
                ? Icons.dark_mode_rounded
                : Icons.light_mode_rounded,
            title: 'Chế độ tối',
            trailing: Switch(
              value: themeProvider.isDark,
              activeThumbColor: c.primary,
              onChanged: (_) => themeProvider.toggle(),
            ),
            onTap: () => themeProvider.toggle(),
          ),
          Divider(height: 1, color: c.border.withValues(alpha: 0.2)),
          // Notification
          _settingsTile(
            c: c,
            icon: Icons.notifications_outlined,
            title: 'Nhắc nhở học tập',
            trailing: Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: c.textTertiary,
            ),
            onTap: () => _showNotificationSettings(c),
          ),
          Divider(height: 1, color: c.border.withValues(alpha: 0.2)),
          // App info
          _settingsTile(
            c: c,
            icon: Icons.info_outline_rounded,
            title: 'Phiên bản',
            trailing: Text(
              '1.0.0',
              style: TextStyle(fontSize: 12, color: c.textTertiary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _settingsTile({
    required AppColors c,
    required IconData icon,
    required String title,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 20, color: c.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: c.textPrimary,
                ),
              ),
            ),
            ?trailing,
          ],
        ),
      ),
    );
  }

  Widget _buildLogoutButton(AppColors c) {
    return GestureDetector(
      onTap: () async {
        final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Text(
              'Đăng xuất?',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: c.textPrimary,
              ),
            ),
            content: Text(
              'Bạn có chắc muốn đăng xuất khỏi tài khoản?',
              style: TextStyle(fontSize: 13, color: c.textSecondary),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text('Hủy', style: TextStyle(color: c.textSecondary)),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: FilledButton.styleFrom(
                  backgroundColor: c.error,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('Đăng xuất'),
              ),
            ],
          ),
        );
        if (confirm == true) {
          await AuthService().signOut();
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: c.error.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: c.error.withValues(alpha: 0.2), width: 0.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.logout_rounded, size: 18, color: c.error),
            const SizedBox(width: 8),
            Text(
              'Đăng xuất',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: c.error,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showNotificationSettings(AppColors c) {
    showModalBottomSheet(
      context: context,
      backgroundColor: c.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _NotifSheet(c: c),
    );
  }

  Widget _buildSectionLabel(AppColors c, String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w500,
        color: c.textSecondary,
        letterSpacing: 0.5,
      ),
    );
  }

  String _getInitials(String name) {
    if (name.isEmpty) return '?';
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return name[0].toUpperCase();
  }
}

// ─── Notification Sheet (tái sử dụng logic) ─────────────────────────────────
class _NotifSheet extends StatefulWidget {
  final AppColors c;
  const _NotifSheet({required this.c});
  @override
  State<_NotifSheet> createState() => _NotifSheetState();
}

class _NotifSheetState extends State<_NotifSheet> {
  final _ns = NotificationService();
  bool _enabled = false;
  TimeOfDay _time = const TimeOfDay(hour: 20, minute: 0);
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final e = await _ns.isEnabled();
    final t = await _ns.getReminderTime();
    if (mounted) {
      setState(() {
        _enabled = e;
        _time = t;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    if (_loading) {
      return SizedBox(
        height: 150,
        child: Center(child: CircularProgressIndicator(color: c.primary)),
      );
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: c.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Nhắc nhở học tập',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: c.textPrimary,
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                color: c.bodyBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.notifications_active_rounded,
                    size: 20,
                    color: c.primary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Bật nhắc nhở',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: c.textPrimary,
                      ),
                    ),
                  ),
                  Switch(
                    value: _enabled,
                    activeThumbColor: c.primary,
                    onChanged: (v) async {
                      setState(() => _enabled = v);
                      v
                          ? await _ns.scheduleDailyReminder(
                              _time.hour,
                              _time.minute,
                            )
                          : await _ns.cancelAll();
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: _enabled
                  ? () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: _time,
                      );
                      if (picked != null && mounted) {
                        setState(() => _time = picked);
                        if (_enabled) {
                          await _ns.scheduleDailyReminder(
                            picked.hour,
                            picked.minute,
                          );
                        }
                      }
                    }
                  : null,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: c.bodyBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.access_time_rounded, size: 20, color: c.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Giờ nhắc',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: c.textPrimary,
                        ),
                      ),
                    ),
                    Text(
                      _time.format(context),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _enabled ? c.primary : c.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (_enabled)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_rounded, size: 14, color: c.teal),
                  const SizedBox(width: 4),
                  Text(
                    'Sẽ nhắc lúc ${_time.format(context)} mỗi ngày',
                    style: TextStyle(fontSize: 11, color: c.teal),
                  ),
                ],
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
