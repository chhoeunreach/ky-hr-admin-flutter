import 'package:flutter/material.dart';

abstract final class RoyalColors {
  static const navy = Color(0xFF061A40);
  static const deepBlue = Color(0xFF082D68);
  static const panel = Color(0xFF0B3975);
  static const royalBlue = Color(0xFF0756C8);
  static const electricBlue = Color(0xFF008CFF);
  static const skyBlue = Color(0xFF36B9FF);
  static const gold = Color(0xFFFFC857);
  static const lightGold = Color(0xFFFFF1B6);
  static const darkGold = Color(0xFFB8860B);
  static const textSecondary = Color(0xFFD8E7FF);
  static const success = Color(0xFF70F2B8);
  static const danger = Color(0xFFFF9DAE);

  static const background = [navy, royalBlue, deepBlue, navy];
  static const goldGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [lightGold, gold, darkGold, lightGold],
  );
}
