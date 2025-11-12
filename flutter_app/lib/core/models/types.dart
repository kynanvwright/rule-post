//flutter_app/lib/models/widgets/types.dart
import 'package:flutter/material.dart';


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