import 'package:flutter/material.dart';

Color parseHexColour(String hex) {
  final s = hex.replaceFirst('#', '');
  final argb = (s.length == 6) ? 'FF$s' : s; // add alpha if needed
  return Color(int.parse(argb, radix: 16));
}