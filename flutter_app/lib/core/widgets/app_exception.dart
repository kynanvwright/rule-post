// lib/core/widgets/app_exception.dart
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