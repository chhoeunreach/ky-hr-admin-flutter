import 'package:flutter/material.dart';

abstract final class RoyalDayColors {
  static const primary = Color(0xFF0D47A1);
  static const royalBlue = Color(0xFF1976D2);
  static const skyBlue = Color(0xFF42A5F5);
  static const background = Color(0xFFE3F2FD);
  static const gold = Color(0xFFFFC107);
  static const darkGold = Color(0xFFFFB300);
  static const success = Color(0xFF10B981);
  static const danger = Color(0xFFEF4444);
  static const text = Color(0xFF102A56);
  static const white = Color(0xFFFFFFFF);

  static const controls = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [royalBlue, primary],
  );

  static const frosted = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [white, background],
  );
}

abstract final class KhmerLuxuryColors {
  static const royalBlue = Color(0xFF0056C7);
  static const deepRoyalBlue = Color(0xFF003B91);
  static const navyBlue = Color(0xFF002A68);
  static const electricBlue = Color(0xFF078BFF);
  static const skyBlue = Color(0xFF70C2FF);
  static const iceBlue = Color(0xFFEAF6FF);
  static const paleBlue = Color(0xFFD8ECFF);
  static const metallicGold = Color(0xFFFFC83D);
  static const brightGold = Color(0xFFFFE17A);
  static const darkGold = Color(0xFFB87908);
  static const white = Colors.white;
  static const darkText = Color(0xFF09234F);
  static const success = Color(0xFF12C878);
  static const danger = Color(0xFFEF3D58);
  static const warning = Color(0xFFFFA726);

  static const controls = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [electricBlue, royalBlue, deepRoyalBlue],
  );

  static const frosted = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [white, iceBlue, paleBlue],
  );

  static const page = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFF80C8FF),
      Color(0xFFD6ECFF),
      Color(0xFFF5FAFF),
      Color(0xFFDDEEFF),
    ],
  );
}

const royalDayAssets = 'assets/themes/royal_blue_day';
