// lib/api/functions_client.dart
import 'package:cloud_functions/cloud_functions.dart';
import '../core/widgets/app_exception.dart';
import '../core/widgets/firebase_exception_mapper.dart';

// generic wrapper for apis:
//    makes a call to a backend function, passing any relevant data from the frontend to it
//    expects the backend function to return a Map<String, dynamic>, where 'ok' is a boolean for if it succeeded
//    throws errors if backend function fails
class ApiTemplate {
  final FirebaseFunctions _fx = FirebaseFunctions.instanceFor(region: 'europe-west8');

  /// A. Domain-mapped errors (recommended for app code)
  Future<T> call<T>(String name, Map<String, dynamic> data) async {
    try {
      final res = await _fx.httpsCallable(name).call<Map<String, dynamic>>(data);
      return res.data as T;
    } on FirebaseFunctionsException catch (e, st) {
      Error.throwWithStackTrace(mapFunctionsError(e), st); // keeps original stack
    } catch (e, st) {
      Error.throwWithStackTrace(UnknownIssue(e.toString()), st);
    }
  }

  /// B. Raw pass-through (for diagnostics/tools/tests)
  Future<T> callRaw<T>(String name, Map<String, dynamic> data) async {
    try {
      final res = await _fx.httpsCallable(name).call<Map<String, dynamic>>(data);
      return res.data as T;
    } on FirebaseFunctionsException {
      rethrow; // preserve original type & stack
    } catch (e, st) {
      Error.throwWithStackTrace(e, st);
    }
  }
}