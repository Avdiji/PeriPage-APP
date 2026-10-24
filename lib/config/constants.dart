import 'package:flutter/material.dart';

// Colors used to create the App-Theme (see docs/mockups).
abstract final class AppColors {
  static const accent = Color(0xFFE8553B);
  static const accentDark = Color(0xFFFF6A4D);
  static const onAccent = Colors.white;
  static const onAccentDark = Color(0xFF16181B);
  static const online = Color(0xFF2FB37A);

  // Light neutrals
  static const lightBg = Color(0xFFF7F6F3);
  static const lightInk = Color(0xFF15171A);
  static const lightMuted = Color(0xFF7D8189);
  static const lightLine = Color(0x1214161A);
  static const lightGlass = Color(0xA8FFFFFF);
  static const lightGlassStrong = Color(0xD9FFFFFF);
  static const lightGlassEdge = Color(0x99FFFFFF);
  static const lightBlobs = [Color(0xFFFFC9B8), Color(0xFFC9DCFF), Color(0xFFE6D9FF)];

  // Dark neutrals
  static const darkBg = Color(0xFF121316);
  static const darkInk = Color(0xFFEEF0F3);
  static const darkMuted = Color(0xFF8B9099);
  static const darkLine = Color(0x12FFFFFF);
  static const darkGlass = Color(0x9E24262B);
  static const darkGlassStrong = Color(0xCC34363C);
  static const darkGlassEdge = Color(0x0FFFFFFF);
  static const darkBlobs = [Color(0xFF5A2A20), Color(0xFF1F3358), Color(0xFF3A2A55)];
}

abstract final class Styling {
  static const radius = 18.0;
  static const radiusSmall = 11.0;
  static const glassBlur = 14.0;
  static const pagePadding = 20.0;
  static const gap = 14.0;
  static const cardPadding = EdgeInsets.symmetric(horizontal: 18, vertical: 16);
}

abstract final class Motion {
  static const fast = Duration(milliseconds: 450);
  static const medium = Duration(milliseconds: 600);
  static const slow = Duration(milliseconds: 1000);
  static const curve = Cubic(.22, .7, .2, 1);
  static const springy = Cubic(.3, 1.12, .5, 1);
}

abstract final class Timings {
  static const chunkSize = 1024;
  static const chunkPause = Duration(milliseconds: 2);
  static const replySettle = Duration(milliseconds: 150);
  static const replyTimeout = Duration(seconds: 2);
  static const statusPoll = Duration(seconds: 5);
}
