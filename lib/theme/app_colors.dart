import 'package:flutter/material.dart';

// ---------------------------------------------------------------------------
// AppColors — semantic colour slots that live outside Material's ColorScheme.
//
// Registered as a ThemeExtension on every ThemeData variant (light, dark,
// highContrastLight, highContrastDark), so widgets read a named slot and get
// the right value for the active theme automatically.
//
// Access via the BuildContext extension:  context.appColors.correct
// ---------------------------------------------------------------------------

class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.correct,
    required this.correctSurface,
    required this.onCorrectSurface,
    required this.markReview,
    required this.markSkip,
    required this.statusSuccess,
    required this.statusWarning,
  });

  // Correct / known answer — text, icon, and border colour.
  final Color correct;

  // Background fill for a correct-answer state (card or option bg).
  final Color correctSurface;

  // Text / icon colour when rendered on top of correctSurface.
  final Color onCorrectSurface;

  // Active colour for the Review mark button (flag set).
  final Color markReview;

  // Active colour for the Skip mark button (check set).
  final Color markSkip;

  // Success colour for data-screen import / export results.
  final Color statusSuccess;

  // Warning colour for data-screen import / export results.
  final Color statusWarning;

  // ── Static theme instances ───────────────────────────────────────────────

  static const light = AppColors(
    correct: Color(0xFF388E3C),        // green[700]
    correctSurface: Color(0x1F388E3C), // green[700] @ 12 %
    onCorrectSurface: Color(0xFF2E7D32), // green[800]
    markReview: Color(0xFF388E3C),     // green[700]
    markSkip: Color(0xFFF57F17),       // amber[700]
    statusSuccess: Color(0xFF388E3C),  // green[700]
    statusWarning: Color(0xFFF57C00),  // orange[700]
  );

  static const dark = AppColors(
    correct: Color(0xFF66BB6A),        // green[400]
    correctSurface: Color(0x3866BB6A), // green[400] @ 22 %
    onCorrectSurface: Color(0xFF81C784), // green[300]
    markReview: Color(0xFF81C784),     // green[300]
    markSkip: Color(0xFFFFD54F),       // amber[300]
    statusSuccess: Color(0xFF81C784),  // green[300]
    statusWarning: Color(0xFFFFB74D),  // orange[300]
  );

  // High-contrast variants push past WCAG AAA (≥ 7 : 1) for normal text.
  // markSkip switches from amber (poor contrast on white) to deep-orange.
  static const highContrastLight = AppColors(
    correct: Color(0xFF1B5E20),        // green[900]  ~12 : 1 on white
    correctSurface: Color(0xFFC8E6C9), // green[100]  — solid, clearly visible
    onCorrectSurface: Color(0xFF1B5E20), // green[900]
    markReview: Color(0xFF1B5E20),     // green[900]
    markSkip: Color(0xFFE65100),       // deepOrange[900] — high-contrast amber
    statusSuccess: Color(0xFF1B5E20),  // green[900]
    statusWarning: Color(0xFFBF360C),  // deepOrange[900]
  );

  static const highContrastDark = AppColors(
    correct: Color(0xFFA5D6A7),        // green[200]
    correctSurface: Color(0x661B5E20), // green[900] @ 40 % — more opaque
    onCorrectSurface: Color(0xFFC8E6C9), // green[100]
    markReview: Color(0xFFC8E6C9),     // green[100]
    markSkip: Color(0xFFFFE082),       // amber[200]
    statusSuccess: Color(0xFFC8E6C9),  // green[100]
    statusWarning: Color(0xFFFFCC80),  // orange[200]
  );

  // ── ThemeExtension protocol ──────────────────────────────────────────────

  @override
  AppColors copyWith({
    Color? correct,
    Color? correctSurface,
    Color? onCorrectSurface,
    Color? markReview,
    Color? markSkip,
    Color? statusSuccess,
    Color? statusWarning,
  }) =>
      AppColors(
        correct: correct ?? this.correct,
        correctSurface: correctSurface ?? this.correctSurface,
        onCorrectSurface: onCorrectSurface ?? this.onCorrectSurface,
        markReview: markReview ?? this.markReview,
        markSkip: markSkip ?? this.markSkip,
        statusSuccess: statusSuccess ?? this.statusSuccess,
        statusWarning: statusWarning ?? this.statusWarning,
      );

  @override
  AppColors lerp(AppColors? other, double t) {
    if (other == null) return this;
    return AppColors(
      correct: Color.lerp(correct, other.correct, t)!,
      correctSurface: Color.lerp(correctSurface, other.correctSurface, t)!,
      onCorrectSurface:
          Color.lerp(onCorrectSurface, other.onCorrectSurface, t)!,
      markReview: Color.lerp(markReview, other.markReview, t)!,
      markSkip: Color.lerp(markSkip, other.markSkip, t)!,
      statusSuccess: Color.lerp(statusSuccess, other.statusSuccess, t)!,
      statusWarning: Color.lerp(statusWarning, other.statusWarning, t)!,
    );
  }
}