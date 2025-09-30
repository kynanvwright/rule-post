import 'package:flutter/material.dart';

extension ColorUtils on Color {
  /// Lightens the color by [amount] (0.0 → no change, 1.0 → fully white).
  Color lighten([double amount = 0.1]) {
    assert(amount >= 0 && amount <= 1);
    return withValues(
      red:   r + (1 - r) * amount,
      green: g + (1 - g) * amount,
      blue:  b + (1 - b) * amount,
    );
  }
}
