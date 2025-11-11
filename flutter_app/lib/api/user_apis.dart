// flutter_app/lib/api/user_apis.dart
import 'api_template.dart';
import '../../core/widgets/types.dart';

final api = ApiTemplate();


Future<Json?> createUserFromFrontend(String email) async {
  return api.call<Json>('createUserWithProfile', {
    'email': email,
  });
}


Future<Json?> deleteUserByEmail(String email) async {
  return api.call<Json>('deleteUser', {
    'email': email,
  });
}