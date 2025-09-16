import 'package:cloud_functions/cloud_functions.dart';
import '../core/models/attachments.dart';

class PostApi {
  PostApi({this.region = 'europe-west8'})
      : _functions = FirebaseFunctions.instanceFor(region: region);

  final String region;
  final FirebaseFunctions _functions;

  /// Calls the CF to create an enquiry. Returns the new doc id.
  Future<String> createEnquiry({
    required String titleText,
    required String enquiryText,
    List<TempAttachment>? attachments,
  }) async {
    final payload = {
      'titleText': titleText,
      'enquiryText': enquiryText,
      if (attachments != null && attachments.isNotEmpty)
        'attachments': attachments.map((a) => a.toMap()).toList(),
    };
    final result = await _functions.httpsCallable('createEnquiry').call(payload);
    final data = (result.data as Map).cast<String, dynamic>();
    return data['id'] as String;
  }


  // Future<void> testPing() async {
  //   final functions = FirebaseFunctions.instanceFor(region: 'europe-west8');
  //   final pingCallable = functions.httpsCallable('ping');

  //   try {
  //     final result = await pingCallable.call();
  //     print('Ping result: ${result.data}');
  //   } catch (e) {
  //     print('Ping failed: $e');
  //   }
  // }
}
