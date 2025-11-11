import 'package:flutter/material.dart';

typedef Json = Map<String, dynamic>;

enum EnquiryConclusion { amendment, interpretation, noResult }

typedef BuildArgs<T> = Future<(bool proceed, T? value)> Function(BuildContext);