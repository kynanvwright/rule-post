
// lib/core/models/firebase_exception_mapper.dart
import 'package:cloud_functions/cloud_functions.dart';

import 'package:rule_post/core/widgets/app_exception.dart';


// claissifies errors from Firebase Functions into app-specific exceptions
//   can give varied options for handling different errors if required
AppException mapFunctionsError(FirebaseFunctionsException e) {
  switch (e.code) {
    case 'not-found':        return NotFound(e.message);
    case 'permission-denied':return PermissionDenied(e.message);
    case 'invalid-argument': return InvalidArgument(e.message);
    case 'unavailable':      return NetworkIssue(e.message); // retryable
    default:                 return ServerIssue(e.message);
  }
}