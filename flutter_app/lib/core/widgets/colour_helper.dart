import 'package:flutter/material.dart';

extension ColorUtils on Color {
  /// Lightens the color by [amount] (0.0 → no change, 1.0 → fully white).
  Color lighten([double amount = 0.1]) {
    assert(amount >= 0 && amount <= 1);
    return withValues(
      red:   red / 255 + (1 - red / 255) * amount,
      green: green / 255 + (1 - green / 255) * amount,
      blue:  blue / 255 + (1 - blue / 255) * amount,
    );
  }
}
