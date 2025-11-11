// flutter_app/lib/api/publish_rc_response.dart
import 'api_template.dart';
import '../../core/widgets/types.dart';

final api = ApiTemplate();

Future<Json?> publishRcResponse(String enquiryId) async {
  final result = api.call<Json>('responseInstantPublisher', {
    'enquiryId': enquiryId.trim(),
    'rcResponse': true,
  });
  return result;
}