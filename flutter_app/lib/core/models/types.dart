//flutter_app/lib/core/models/widgets/types.dart
import 'package:flutter/material.dart';

import 'package:rule_post/core/models/attachments.dart' show TempAttachment;


enum EnquiryConclusion { amendment, interpretation, noResult }

typedef Json = Map<String, dynamic>;

typedef BuildArgs<T> = Future<(bool proceed, T? value)> Function(BuildContext);


class TeamUser {
  final String email;
  final String displayName;
  TeamUser({required this.email, required this.displayName});
}


class CreateMemberInput {
  final BuildContext context;
  final String email;
  final bool isAdmin;
  CreateMemberInput({required this.email, required this.context, this.isAdmin = false});
}


class NewPostPayload {
  NewPostPayload({
    required this.title,
    required this.text,
    required this.attachments,
  });

  final String title;
  final String text;
  final List<TempAttachment> attachments;
}


class ClaimSpec {
  final String key;
  final String label;
  final IconData icon;
  const ClaimSpec({required this.key, required this.label, required this.icon});
}