// flutter_app/lib/api/change_stage_length.dart
import 'api_template.dart';
import '../../core/widgets/types.dart';

final api = ApiTemplate();


Future<Json?> changeStageLength(String enquiryId, int newStageLength) async {
  return api.call<Json>('changeStageLength', {
    'enquiryId': enquiryId.trim(),
    'newStageLength' : newStageLength,
  });
}