// flutter_app/lib/debug/debug.dart
import 'package:flutter/foundation.dart';

void d(Object? message) {
  if (kDebugMode) {
    debugPrint(message.toString());
  }
}