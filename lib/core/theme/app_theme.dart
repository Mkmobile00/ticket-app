import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// BOLETO light theme — matches the web design (teal accent, light surfaces).
class AppColors {
  static const bg = Color(0xFFF5F7F9);       // page background  (--bg)
  static const surface = Color(0xFFFFFFFF);  // cards / app bar  (--surface)
  static const surface2 = Color(0xFFEEF1F4); // input fill / chips (--line-2)
  static const line = Color(0xFFE7EAEE);     // borders          (--line)
  static const text = Color(0xFF16202E);     // primary ink      (--ink)
  static const muted = Color(0xFF8A95A3);    // secondary ink    (--ink-3)
  static const accent = Color(0xFF0FB39A);   // brand teal       (--accent)
  static const accent2 = Color(0xFF0A8F7C);  // brand teal dark  (--accent-d)
  static const accentSoft = Color(0xFFE6F7F3); // teal tint      (--accent-l)
  static const onAccent = Color(0xFF04201B); // text on teal buttons

  // Seat statuses (match web es-legend)
  static const seatAvailable = Color(0xFFEEF1F4);
  static const seatMine = Color(0xFF0FB39A);
  static const seatLocked = Color(0xFFF5C023);
  static const seatBooked = Color(0xFFE5484D);

  static const accentGradient = LinearGradient(
    colors: [accent, accent2],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

/// Format a number as Indian Rupees, e.g. rs(1200) -> "Rs 1,200.00".
String rs(num value) => 'Rs ${NumberFormat('#,##0.00', 'en_IN').format(value)}';

ThemeData buildTheme() {
  final base = ThemeData.light(useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: AppColors.bg,
    colorScheme: base.colorScheme.copyWith(
      brightness: Brightness.light,
      primary: AppColors.accent,
      secondary: AppColors.accent2,
      surface: AppColors.surface,
      onSurface: AppColors.text,
      onPrimary: AppColors.onAccent,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0.5,
      centerTitle: false,
      foregroundColor: AppColors.text,
      iconTheme: IconThemeData(color: AppColors.text),
    ),
    cardTheme: CardThemeData(
      color: AppColors.surface,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.line),
      ),
    ),
    dividerColor: AppColors.line,
    dividerTheme: const DividerThemeData(color: AppColors.line, thickness: 1),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      hintStyle: const TextStyle(color: AppColors.muted),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(11),
        borderSide: const BorderSide(color: AppColors.line, width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(11),
        borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(11),
        borderSide: const BorderSide(color: AppColors.line, width: 1.5),
      ),
    ),
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: AppColors.surface2,
      selectedColor: AppColors.accent,
      side: const BorderSide(color: AppColors.line),
      labelStyle: const TextStyle(color: AppColors.text),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      indicatorColor: AppColors.accentSoft,
      iconTheme: WidgetStateProperty.resolveWith((s) => IconThemeData(
            color: s.contains(WidgetState.selected) ? AppColors.accent2 : AppColors.muted)),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: AppColors.surface,
      selectedItemColor: AppColors.accent2,
      unselectedItemColor: AppColors.muted,
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppColors.accent,
      foregroundColor: AppColors.onAccent,
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: AppColors.accent),
    textTheme: base.textTheme.apply(bodyColor: AppColors.text, displayColor: AppColors.text),
  );
}

/// Reusable gradient button (teal gradient, dark label — matches web .btn-cta).
class AccentButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  const AccentButton({super.key, required this.label, this.onPressed, this.loading = false});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: loading ? null : onPressed,
      child: Container(
        height: 52,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: AppColors.accentGradient,
          borderRadius: BorderRadius.circular(26),
          boxShadow: [
            BoxShadow(color: AppColors.accent.withValues(alpha: .38), blurRadius: 18, offset: const Offset(0, 8)),
          ],
        ),
        child: loading
            ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.onAccent))
            : Text(label, style: const TextStyle(color: AppColors.onAccent, fontWeight: FontWeight.w800, fontSize: 16, letterSpacing: .3)),
      ),
    );
  }
}
