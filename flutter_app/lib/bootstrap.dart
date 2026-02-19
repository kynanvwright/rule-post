// bootstrap.dart
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'package:rule_post/firebase_options.dart';
import 'package:rule_post/debug/debug.dart';

// ── Toggle this to use local Firebase emulators ──
const bool _useEmulators = false;

// Application bootstrap: initialize Firebase, App Check, Firestore persistence
// For use in main.dart
Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  if (_useEmulators) {
    d('🔧 Connecting to Firebase emulators…');
    await FirebaseAuth.instance.useAuthEmulator('localhost', 9099);
    FirebaseFunctions.instanceFor(
      region: 'europe-west6',
    ).useFunctionsEmulator('localhost', 5001);
    FirebaseFirestore.instance.useFirestoreEmulator('localhost', 8080);
    // App Check uses debug provider in emulator mode
    await FirebaseAppCheck.instance.activate(
      webProvider: ReCaptchaEnterpriseProvider(
        '6LebMm4sAAAAAHMA_PhzwAOTmeTR0iAAOsjYxjzQ',
      ),
    );
  } else {
    await FirebaseAppCheck.instance.activate(
      webProvider: ReCaptchaEnterpriseProvider(
        '6LebMm4sAAAAAHMA_PhzwAOTmeTR0iAAOsjYxjzQ',
      ),
    );
    await FirebaseAppCheck.instance.setTokenAutoRefreshEnabled(true);
  }

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
