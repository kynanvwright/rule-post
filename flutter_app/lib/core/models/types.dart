//flutter_app/lib/core/models/widgets/types.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'package:rule_post/core/models/attachments.dart' show TempAttachment;

enum EnquiryConclusion { amendment, interpretation, noResult }

typedef Json = Map<String, dynamic>;

typedef BuildArgs<T> = Future<(bool proceed, T? value)> Function(BuildContext);

class TeamUser {
  final String uid;
  final String email;
  final String displayName;
  final bool disabled;
  TeamUser({
    required this.uid,
    required this.email,
    required this.displayName,
    this.disabled = false,
  });
}

class CreateMemberInput {
  final BuildContext context;
  final String email;
  final bool isAdmin;
  CreateMemberInput({
    required this.email,
    required this.context,
    this.isAdmin = false,
  });
}

class NewPostPayload {
  NewPostPayload({
    required this.title,
    required this.text,
    required this.attachments,
    this.closeEnquiryOnPublish = false,
    this.enquiryConclusion,
  });

  final String title;
  final String text;
  final List<TempAttachment> attachments;
  final bool closeEnquiryOnPublish;
  final String? enquiryConclusion; // "amendment", "interpretation", "noResult"
}

class ClaimSpec {
  final String key;
  final String label;
  final IconData icon;
  const ClaimSpec({required this.key, required this.label, required this.icon});
}

class DocView {
  final String id;
  final DocumentReference<Map<String, dynamic>> reference;
  final Map<String, dynamic> _data;
  DocView(this.id, this.reference, this._data);
  Map<String, dynamic> data() => _data;
}
