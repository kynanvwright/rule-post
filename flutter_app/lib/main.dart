// lib/main.dart
import 'dart:async';
import 'dart:developer' as dev;
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'firebase_options.dart';

const String kRecaptchaV3SiteKey = '6LeP8ssrAAAAAHuCNAA-tIXVzahLuskzGP7K-Si0';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: AppCheckProbePage(),
  ));
}

class AppCheckProbePage extends StatefulWidget {
  const AppCheckProbePage({super.key});
  @override
  State<AppCheckProbePage> createState() => _AppCheckProbePageState();
}

class _AppCheckProbePageState extends State<AppCheckProbePage> {
  String _status = 'Idle';
  String? _lastError;
  int _tokenLen = 0;
  StreamSubscription<String?>? _sub;

  @override
  void initState() {
    super.initState();
    _runProbe();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _runProbe() async {
    setState(() {
      _status = 'Initialising Firebase…';
      _lastError = null;
      _tokenLen = 0;
    });

    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );

      setState(() => _status = 'Activating App Check (reCAPTCHA v3)…');
      await FirebaseAppCheck.instance.activate(
        webProvider: ReCaptchaV3Provider(kRecaptchaV3SiteKey),
      );

      // Listen for token updates (correct API name: onTokenChange)
      _sub?.cancel();
      _sub = FirebaseAppCheck.instance.onTokenChange.listen(
        (t) {
          _tokenLen = t?.length ?? 0;
          dev.log('onTokenChange len=$_tokenLen');
          setState(() {
            _status = _tokenLen > 0
                ? 'onTokenChange received (len=$_tokenLen)'
                : 'onTokenChange: null token';
          });
        },
        onError: (e, st) {
          dev.log('onTokenChange error', error: e, stackTrace: st);
          setState(() {
            _lastError = '$e';
            _status = 'onTokenChange error';
          });
        },
      );

      setState(() => _status = 'Forcing token fetch…');
      final token = await FirebaseAppCheck.instance
          .getToken(true)
          .timeout(const Duration(seconds: 15));

      _tokenLen = token?.length ?? 0;
      dev.log('getToken(true) OK len=$_tokenLen');
      setState(() => _status = 'SUCCESS: token len=$_tokenLen');

      await FirebaseAppCheck.instance.setTokenAutoRefreshEnabled(true);
    } catch (e, st) {
      dev.log('App Check probe failed', error: e, stackTrace: st);
      setState(() {
        _lastError = e.toString();
        _status = 'FAILED: See console for details';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('App Check / reCAPTCHA Probe')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: DefaultTextStyle(
          style: theme.textTheme.bodyMedium!,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Status: $_status', style: theme.textTheme.titleMedium),
              const SizedBox(height: 12),
              Text('Token length: $_tokenLen'),
              if (_lastError != null) ...[
                const SizedBox(height: 12),
                Text('Last error:', style: theme.textTheme.titleSmall),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.06),
                    border: Border.all(color: Colors.red.withOpacity(0.3)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(_lastError!, style: const TextStyle(fontFamily: 'monospace')),
                ),
              ],
              const Spacer(),
              Row(
                children: [
                  ElevatedButton(onPressed: _runProbe, child: const Text('Retry probe')),
                  const SizedBox(width: 12),
                  OutlinedButton(
                    onPressed: () => showDialog(
                      context: context,
                      builder: (_) => const AlertDialog(
                        title: Text('Common causes'),
                        content: Text(
                          '- Wrong key type (needs App Check reCAPTCHA v3 site key)\n'
                          '- Domain not in App Check allowed domains\n'
                          '- Third-party cookies / privacy blocking reCAPTCHA\n'
                          '- CSP blocking google/recaptcha\n',
                        ),
                      ),
                    ),
                    child: const Text('Help'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
