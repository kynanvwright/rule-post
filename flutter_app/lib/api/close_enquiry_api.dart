// flutter_app/lib/api/close_enquiry_api.dart
import 'api_template.dart';
import '../../core/widgets/types.dart';

final api = ApiTemplate();


Future<Json?> closeEnquiry(String enquiryId, EnquiryConclusion enquiryConclusion) async {
  final result = api.call<Json>('closeEnquiry', {
      'enquiryId': enquiryId.trim(),
      'enquiryConclusion': enquiryConclusion.name,
  });
  // print something to show it's done
  return result;
}