// flutter_app/lib/auth/widgets/login_dialog.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:rule_post/auth/widgets/auth_service.dart';
import 'package:rule_post/riverpod/user_detail.dart';


// Call this to open the dialog:
Future<bool?> showLoginDialog(BuildContext context, {bool barrierDismissible = true}) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: barrierDismissible,
    builder: (_) => const LoginDialog(),
  );
}


class LoginDialog extends ConsumerStatefulWidget {
  const LoginDialog({super.key});
  @override
  ConsumerState<LoginDialog> createState() => _LoginDialogState();
}


class _LoginDialogState extends ConsumerState<LoginDialog> {
  bool _isPasswordVisible = false;
  bool _rememberMe = false;
  final _formKeyA = GlobalKey<FormState>();

  final _authService = AuthService();
  final _email = TextEditingController(text: 'kynan.wright@emiratesteamnz.com');
  final _password = TextEditingController(text: 'test1234');

  bool _closed = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<String?>(
      teamProvider,
      (prev, next) {
        if (!_closed && prev == null && next != null && mounted) {
          _closed = true;
          Navigator.of(context, rootNavigator: true).pop(true);
        }
      },
    );
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKeyA,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Image.asset('assets/images/cup_logo2.jpg', width: 100),
                  const SizedBox(height: 16),
                  Text("Welcome to Rule Post!", style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text(
                    "Enter your email and password to continue.",
                    style: Theme.of(context).textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),

                  // Email
                  TextFormField(
                    controller: _email,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      hintText: 'Enter your email',
                      prefixIcon: Icon(Icons.email_outlined),
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Please enter some text';
                      final ok = RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(value);
                      return ok ? null : 'Please enter a valid email';
                    },
                  ),
                  const SizedBox(height: 16),

                  // Password
                  TextFormField(
                    controller: _password,
                    obscureText: !_isPasswordVisible,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      hintText: 'Enter your password',
                      prefixIcon: const Icon(Icons.lock_outline_rounded),
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(_isPasswordVisible ? Icons.visibility_off : Icons.visibility),
                        onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Please enter some text';
                      if (value.length < 6) return 'Password must be at least 6 characters';
                      return null;
                    },
                  ),
                  const SizedBox(height: 8),

                  // Remember me
                  CheckboxListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    value: _rememberMe,
                    onChanged: (v) => setState(() => _rememberMe = v ?? false),
                    title: const Text('Remember me'),
                  ),
                  const SizedBox(height: 8),

                  // Actions
                  Row(
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context, rootNavigator: true).maybePop(false),
                        child: const Text('Cancel'),
                      ),
                      const Spacer(),
                      ElevatedButton(
                        onPressed: _onSignInPressed,
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          child: Text('Sign in', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _onSignInPressed() async {
    if (!(_formKeyA.currentState?.validate() ?? false)) return;

    if (kIsWeb) {
      await FirebaseAuth.instance.setPersistence(
        _rememberMe ? Persistence.LOCAL : Persistence.SESSION,
      );
    }

    final error = await _authService.signIn(_email.text.trim(), _password.text);
    if (!mounted) return;

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
      return;
    }

    return;
  }
}