// lib/api/functions_client.dart
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

import 'package:rule_post/auth/widgets/auth_check.dart' show ensureFreshAuth;
import 'package:rule_post/content/widgets/progress_dialog.dart';
import 'package:rule_post/core/models/firebase_exception_mapper.dart';
import 'package:rule_post/core/models/types.dart' show Json;

// generic wrapper for apis:
//    makes a call to a backend function, passing any relevant data from the frontend to it
//    throws errors if backend function fails
//    can create a progress dialog while the function runs, and give infoabout success/failure
class ApiTemplate {
  final FirebaseFunctions _fx = FirebaseFunctions.instanceFor(
    region: 'europe-west6',
  );

  /// A. Domain-mapped errors (recommended for app code)
  Future<T> call<T>(String name, Json data) async {
    try {
      final res = await _fx.httpsCallable(name).call<Json>(data);
      return res.data as T;
    } on FirebaseFunctionsException catch (e, st) {
      Error.throwWithStackTrace(
        mapFunctionsError(e),
        st,
      ); // keeps original stack
    } catch (e, st) {
      Error.throwWithStackTrace(UnknownIssue(e.toString()), st);
    }
  }

  /// B. Raw pass-through (for diagnostics/tools/tests)
  Future<T> callRaw<T>(String name, Json data) async {
    try {
      final res = await _fx.httpsCallable(name).call<Json>(data);
      return res.data as T;
    } on FirebaseFunctionsException {
      rethrow; // preserve original type & stack
    } catch (e, st) {
      Error.throwWithStackTrace(e, st);
    }
  }

  /// C. UI-aware: shows progress popup (optional texts)
  Future<T> callWithProgress<T>({
    required BuildContext context,
    required String name,
    required Json data,
    List<String>? steps,
    Duration stepInterval = const Duration(seconds: 2),
    String? successTitle,
    String? successMessage,
    String Function(T result)? successBuilder,
    String? failureTitle,
    String? failureMessage,
    String Function(T result)? failureBuilder,
    bool barrierDismissibleWhileRunning = false,
    bool autoCloseOnSuccess = true,
    Duration autoCloseAfter = const Duration(seconds: 2, milliseconds: 500),
    void Function(T result)? onSuccess,
    void Function(Object error, StackTrace st)? onError,
  }) async {
    try {
      final result = await showProgressFlow<T>(
        context: context,
        action: () async {
          await ensureFreshAuth();
          return call<T>(name, data);
        },
        steps:
            steps ??
            const [
              'Checking user authentication…',
              'Running function…',
              'Verifying results…',
            ],
        stepInterval: stepInterval,
        successTitle: successTitle ?? 'Function ran successfully',
        successMessage: successMessage ?? 'Your action completed successfully.',
        failureTitle: failureTitle ?? 'Something went wrong',
        failureMessage: failureMessage ?? 'Please try again.',
        barrierDismissibleWhileRunning: barrierDismissibleWhileRunning,
        autoCloseOnSuccess: autoCloseOnSuccess,
        autoCloseAfter: autoCloseAfter,
        successBuilder: successBuilder,
        failureBuilder: failureBuilder,
      );
      onSuccess?.call(result);
      return result;
    } catch (e, st) {
      onError?.call(e, st);
      rethrow;
    }
  }
}
