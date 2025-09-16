import 'package:cloud_functions/cloud_functions.dart';

class PostApi {
  PostApi({this.region = 'europe-west8'})
      : _functions = FirebaseFunctions.instanceFor(region: region);

  final String region;
  final FirebaseFunctions _functions;

  /// Calls the CF to create an enquiry. Returns the new doc id.
  Future<String> createEnquiry({
    required String titleText,
    required String enquiryText,
  }) async {
    final callable = _functions.httpsCallable('createEnquiry');
    final result = await callable.call({
      'titleText': titleText,
      'enquiryText': enquiryText,
    });
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
