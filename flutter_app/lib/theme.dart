// theme.dart
import 'package:flutter/material.dart';
final kSeed = const Color(0xFF209ED6);

ThemeData lightTheme() => ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.fromSeed(seedColor: kSeed, brightness: Brightness.light),
);

ThemeData darkTheme() => ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.fromSeed(seedColor: kSeed, brightness: Brightness.dark),
);
