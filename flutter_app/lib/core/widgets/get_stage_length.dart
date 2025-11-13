// flutter_app/lib/core/widgets/get_stage_length.dart
import 'package:cloud_firestore/cloud_firestore.dart';


// helper to return current stageLength for admin changeStageLength function
Future<int> getStageLength(String enquiryId) async {
  final doc = await FirebaseFirestore.instance.collection('enquiries').doc(enquiryId).get();
  if (doc.exists) {
    return doc.data()?['stageLength'];  // returns null if field missing
  } else {
    throw Exception('Document not found');
  }
}