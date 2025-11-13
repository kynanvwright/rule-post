// flutter_app/lib/content/widgets/parse_hex_colour.dart
import 'package:flutter/material.dart';


// Parses a hex colour string (e.g. "#RRGGBB" or "#AARRGGBB") into a Color
Color parseHexColour(String hex) {
  final s = hex.replaceFirst('#', '');
  final argb = (s.length == 6) ? 'FF$s' : s; // add alpha if needed
  return Color(int.parse(argb, radix: 16));
}