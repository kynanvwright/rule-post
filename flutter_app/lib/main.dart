// main.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:rule_post/app.dart';
import 'package:rule_post/bootstrap.dart';


Future<void> main() async {
  await bootstrap();           // does binding + Firebase + AppCheck + Firestore
  runApp(const ProviderScope(child: MyApp()));
}