import 'package:material_ui/material_ui.dart';

import 'edition.dart';

const ink = Color(0xFF1C2430);
const paper = Color(0xFFF4F1EA);
const leaf = Color(0xFF0E7C66);
const leafDark = Color(0xFF0A5C4C);
const passGreen = Color(0xFF1F8A4C);
const failRed = Color(0xFFC5363A);
const card = Colors.white;
const line = Color(0xFFE4DFD4);

const footerText = 'Developed by 9 Multimedia and IT Solutions · SHAMM TESFALEM · 07162947';

const navy = Color(0xFF1E4A7A);
const cream = Color(0xFFF3EEE4);
const navyInk = Color(0xFF16324F);

ThemeData schoolTheme() => demoEdition ? _wander() : _classic();

ThemeData _classic() {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: leaf, primary: leaf, surface: paper),
    scaffoldBackgroundColor: paper,
    fontFamily: 'Roboto',
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(bodyColor: ink, displayColor: ink),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: card,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: line)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: leaf,
        foregroundColor: Colors.white,
        minimumSize: const Size(64, 56),
        textStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
  );
}

ThemeData _wander() {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: navy, primary: navy, surface: cream),
    scaffoldBackgroundColor: cream,
    fontFamily: 'Roboto',
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(bodyColor: navyInk, displayColor: navyInk),
    cardTheme: CardThemeData(
      color: const Color(0xFFFCFAF6),
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26), side: const BorderSide(color: Color(0xFFFFFFFF))),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFFF7F4EE),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(28), borderSide: const BorderSide(color: Color(0xFFE7E0D4))),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: navy,
        foregroundColor: Colors.white,
        minimumSize: const Size(64, 52),
        textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      ),
    ),
  );
}
