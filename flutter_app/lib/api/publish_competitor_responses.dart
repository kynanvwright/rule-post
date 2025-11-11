// flutter_app/lib/api/publish_competitor_responses.dart

import 'api_template.dart';
import '../../core/widgets/types.dart';

final api = ApiTemplate();

Future<Json?> publishCompetitorResponses(String enquiryId) async {
  final result = api.call<Json>('responseInstantPublisher', {
    'enquiryId': enquiryId.trim(),
    'rcResponse': false,
  });
  // print something to show it's done
  // result['message'] = result['ok'] ? 'Yay, this function worked' : "Oh no, this function didn't work";
  return result;
}