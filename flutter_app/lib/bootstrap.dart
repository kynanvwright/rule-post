// bootstrap.dart
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'package:rule_post/firebase_options.dart';
import 'package:rule_post/debug/debug.dart';


// Application bootstrap: initialize Firebase, App Check, Firestore persistence
// For use in main.dart
Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  await FirebaseAppCheck.instance.activate(
    webProvider: ReCaptchaV3Provider('6LeP8ssrAAAAAHuCNAA-tIXVzahLuskzGP7K-Si0'),
    // webProvider: ReCaptchaV3Provider(
    //   const String.fromEnvironment('APP_CHECK_SITE_KEY', defaultValue: 'DEV_KEY_HERE'),
    // ),
  );
  await FirebaseAppCheck.instance.setTokenAutoRefreshEnabled(true);

  // Firestore persistence
  try {
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,             
      cacheSizeBytes: 100 * 1024 * 1024,
    );
  } catch (e) {
    d('⚠️ Firestore persistence not enabled: $e');
  }
}
