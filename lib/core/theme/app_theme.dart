import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Buleto dark cinema theme + helpers.
class AppColors {
  static const bg = Color(0xFF0D0F12);
  static const surface = Color(0xFF141A2B);
  static const surface2 = Color(0xFF1E2742);
  static const text = Color(0xFFCFD4DB);
  static const muted = Color(0xFF8B95B5);
  static const accent = Color(0xFFFF5046);
  static const accent2 = Color(0xFFFF8A3D);

  // Seat statuses
  static const seatAvailable = Color(0xFF3A4658);
  static const seatMine = Color(0xFF2F9E6F);
  static const seatLocked = Color(0xFFE7B400);
  static const seatBooked = Color(0xFFC0392B);

  static const accentGradient = LinearGradient(
    colors: [accent, accent2],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

/// Format a number as Indian Rupees, e.g. rs(1200) -> "Rs 1,200.00".
String rs(num value) => 'Rs ${NumberFormat('#,##0.00', 'en_IN').format(value)}';

ThemeData buildTheme() {
  final base = ThemeData.dark(useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: AppColors.bg,
    colorScheme: base.colorScheme.copyWith(
      primary: AppColors.accent,
      secondary: AppColors.accent2,
      surface: AppColors.surface,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.bg,
      elevation: 0,
      centerTitle: false,
      foregroundColor: Colors.white,
    ),
    cardTheme: CardThemeData(
      color: AppColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface2,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
      hintStyle: const TextStyle(color: AppColors.muted),
    ),
    textTheme: base.textTheme.apply(bodyColor: AppColors.text, displayColor: Colors.white),
  );
}

/// Reusable gradient button.
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
        height: 50,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: AppColors.accentGradient,
          borderRadius: BorderRadius.circular(10),
        ),
        child: loading
            ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
      ),
    );
  }
}
