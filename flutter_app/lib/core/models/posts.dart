import 'package:cloud_firestore/cloud_firestore.dart';


class Enquiry {
  final String id;
  final String title;
  final String text;
  final bool isOpen;
  final DateTime? createdAt;
  final List<dynamic> attachments; // keep dynamic for now, or make a typed model later

  Enquiry({
    required this.id,
    required this.title,
    required this.text,
    required this.isOpen,
    required this.createdAt,
    required this.attachments,
  });

  factory Enquiry.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};
    return Enquiry(
      id: doc.id,
      title: (d['titleText'] ?? '').toString(),
      text: (d['enquiryText'] ?? '').toString(),
      isOpen: d['isOpen'] ?? true,
      createdAt: (d['createdAt'] is Timestamp)
          ? (d['createdAt'] as Timestamp).toDate()
          : null,
      attachments: (d['attachments'] is List) ? (d['attachments'] as List) : const [],
    );
  }
}
