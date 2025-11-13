
// lib/core/models/firebase_exception_mapper.dart
import 'package:cloud_functions/cloud_functions.dart';


// classifies errors from Firebase Functions into app-specific exceptions
//   can give varied options for handling different errors if required
//   e.g., show 'not found' vs 'permission denied' messages in UI
AppException mapFunctionsError(FirebaseFunctionsException e) {
  switch (e.code) {
    case 'not-found':        return NotFound(e.message);
    case 'permission-denied':return PermissionDenied(e.message);
    case 'invalid-argument': return InvalidArgument(e.message);
    case 'unavailable':      return NetworkIssue(e.message); // retryable
    default:                 return ServerIssue(e.message);
  }
}


// specific error classes
sealed class AppException implements Exception {
  final String? message;
  const AppException([this.message]);
}
class NotFound extends AppException { const NotFound([super.message]); }
class PermissionDenied extends AppException { const PermissionDenied([super.message]); }
class InvalidArgument extends AppException { const InvalidArgument([super.message]); }
class NetworkIssue extends AppException { const NetworkIssue([super.message]); }
class ServerIssue extends AppException { const ServerIssue([super.message]); }
class UnknownIssue extends AppException { const UnknownIssue([super.message]); }