// flutter_app/lib/debug/debug.dart
import 'package:flutter/foundation.dart';

void d(Object? message) {
  if (kDebugMode) {
    debugPrint(message.toString());
  }
}

/// Validates schema: logs warnings if expected keys are missing from doc.
/// Useful for catching breaking changes in Firestore documents.
/// Returns true if all keys present; false if any missing.
bool validateDocSchema(
  Map<String, dynamic>? doc,
  List<String> requiredKeys, {
  required String docType,
  required String docId,
}) {
  if (doc == null || doc.isEmpty) {
    d('[Schema] ⚠️ $docType doc is empty or null (id: $docId)');
    return false;
  }

  final missing = requiredKeys.where((k) => !doc.containsKey(k)).toList();
  if (missing.isNotEmpty) {
    d('[Schema] ⚠️ $docType "$docId" missing keys: ${missing.join(", ")}');
    return false;
  }

  return true;
}