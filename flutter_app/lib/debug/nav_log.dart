import 'dart:developer' as dev;
import 'package:flutter/foundation.dart';

class NavLog {
  static int _seq = 0;
  static int nextSeq() => ++_seq;

  static void p(String msg) {
    if (!kDebugMode) return;
    final t = DateTime.now().toIso8601String();
    final line = '[$t] $msg';

    // Browser DevTools (best for web)
    dev.log(line, name: 'nav');

    // PowerShell / flutter run terminal mirror
    debugPrint('[nav] $line');
  }

  static Stopwatch sw([String? label]) {
    final s = Stopwatch()..start();
    if (label != null) p('⏱  start $label');
    return s;
  }

  static void end(Stopwatch s, String label) {
    s.stop();
    p('⏱  end   $label — ${s.elapsedMilliseconds}ms');
  }
}
