// riverpod/doc_view.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class DocView {
  final String id;
  final DocumentReference<Map<String, dynamic>> reference;
  final Map<String, dynamic> _data;
  DocView(this.id, this.reference, this._data);
  Map<String, dynamic> data() => _data;
}