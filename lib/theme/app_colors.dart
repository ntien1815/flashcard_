import 'package:flutter/material.dart';

/// AppColors ThemeExtension — đăng ký trong ThemeData của main.dart
/// Dùng: final c = AppColors.of(context);
class AppColors extends ThemeExtension<AppColors> {
  final Color primary;
  final Color primaryLight;
  final Color primaryLighter;
  final Color primaryBg;
  final Color primaryDark;
  final Color teal;
  final Color tealBg;
  final Color amber;
  final Color amberBg;
  final Color coral;
  final Color coralBg;
  final Color bodyBg;
  final Color surface;
  final Color border;
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color error;

  const AppColors({
    required this.primary,
    required this.primaryLight,
    required this.primaryLighter,
    required this.primaryBg,
    required this.primaryDark,
    required this.teal,
    required this.tealBg,
    required this.amber,
    required this.amberBg,
    required this.coral,
    required this.coralBg,
    required this.bodyBg,
    required this.surface,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.error,
  });

  static AppColors of(BuildContext context) =>
      Theme.of(context).extension<AppColors>()!;

  // ─── Light ──────────────────────────────────────────────────────────────────
  static const light = AppColors(
    primary: Color(0xFF534AB7),
    primaryLight: Color(0xFFAFA9EC),
    primaryLighter: Color(0xFFCECBF6),
    primaryBg: Color(0xFFEEEDFE),
    primaryDark: Color(0xFF3C3489),
    teal: Color(0xFF1D9E75),
    tealBg: Color(0xFFE1F5EE),
    amber: Color(0xFFBA7517),
    amberBg: Color(0xFFFAEEDA),
    coral: Color(0xFFD85A30),
    coralBg: Color(0xFFFAECE7),
    bodyBg: Color(0xFFF1EFE8),
    surface: Color(0xFFFFFFFF),
    border: Color(0xFFD3D1C7),
    textPrimary: Color(0xFF2C2C2A),
    textSecondary: Color(0xFF888780),
    textTertiary: Color(0xFFB4B2A9),
    error: Color(0xFFE24B4A),
  );

  // ─── Dark ───────────────────────────────────────────────────────────────────
  static const dark = AppColors(
    primary: Color(0xFF7B74D4),
    primaryLight: Color(0xFF9D98E8),
    primaryLighter: Color(0xFFBDB8F0),
    primaryBg: Color(0xFF2A2850),
    primaryDark: Color(0xFFADA8F0),
    teal: Color(0xFF2BC28F),
    tealBg: Color(0xFF1A3D30),
    amber: Color(0xFFD4913A),
    amberBg: Color(0xFF3D2E12),
    coral: Color(0xFFE87055),
    coralBg: Color(0xFF3D1E15),
    bodyBg: Color(0xFF1A1A2E),
    surface: Color(0xFF252540),
    border: Color(0xFF3A3A5C),
    textPrimary: Color(0xFFE8E6DF),
    textSecondary: Color(0xFF9E9B94),
    textTertiary: Color(0xFF6B6860),
    error: Color(0xFFE86060),
  );

  @override
  AppColors copyWith({
    Color? primary,
    Color? primaryLight,
    Color? primaryLighter,
    Color? primaryBg,
    Color? primaryDark,
    Color? teal,
    Color? tealBg,
    Color? amber,
    Color? amberBg,
    Color? coral,
    Color? coralBg,
    Color? bodyBg,
    Color? surface,
    Color? border,
    Color? textPrimary,
    Color? textSecondary,
    Color? textTertiary,
    Color? error,
  }) {
    return AppColors(
      primary: primary ?? this.primary,
      primaryLight: primaryLight ?? this.primaryLight,
      primaryLighter: primaryLighter ?? this.primaryLighter,
      primaryBg: primaryBg ?? this.primaryBg,
      primaryDark: primaryDark ?? this.primaryDark,
      teal: teal ?? this.teal,
      tealBg: tealBg ?? this.tealBg,
      amber: amber ?? this.amber,
      amberBg: amberBg ?? this.amberBg,
      coral: coral ?? this.coral,
      coralBg: coralBg ?? this.coralBg,
      bodyBg: bodyBg ?? this.bodyBg,
      surface: surface ?? this.surface,
      border: border ?? this.border,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textTertiary: textTertiary ?? this.textTertiary,
      error: error ?? this.error,
    );
  }

  @override
  AppColors lerp(AppColors? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      primary: Color.lerp(primary, other.primary, t)!,
      primaryLight: Color.lerp(primaryLight, other.primaryLight, t)!,
      primaryLighter: Color.lerp(primaryLighter, other.primaryLighter, t)!,
      primaryBg: Color.lerp(primaryBg, other.primaryBg, t)!,
      primaryDark: Color.lerp(primaryDark, other.primaryDark, t)!,
      teal: Color.lerp(teal, other.teal, t)!,
      tealBg: Color.lerp(tealBg, other.tealBg, t)!,
      amber: Color.lerp(amber, other.amber, t)!,
      amberBg: Color.lerp(amberBg, other.amberBg, t)!,
      coral: Color.lerp(coral, other.coral, t)!,
      coralBg: Color.lerp(coralBg, other.coralBg, t)!,
      bodyBg: Color.lerp(bodyBg, other.bodyBg, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      border: Color.lerp(border, other.border, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textTertiary: Color.lerp(textTertiary, other.textTertiary, t)!,
      error: Color.lerp(error, other.error, t)!,
    );
  }
}
