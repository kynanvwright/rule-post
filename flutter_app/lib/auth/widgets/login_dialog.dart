// flutter_app/lib/auth/widgets/login_dialog.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:rule_post/auth/widgets/auth_service.dart';
import 'package:rule_post/riverpod/user_detail.dart';

// Call this to open the dialog:
Future<bool?> showLoginDialog(BuildContext context,
    {bool barrierDismissible = true}) {
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
  final _email = TextEditingController();
  final _password = TextEditingController();

  bool _closed = false;

  // ✅ NEW: disable "Forgot password" while sending
  bool _sendingReset = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  // ✅ NEW: reuse the same email regex you use in the validator
  static bool _isValidEmail(String s) {
    return RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(s);
  }

  // ✅ NEW: password reset from dialog (only sends if email input is valid)
  Future<void> _onForgotPasswordPressed() async {
    final email = _email.text.trim();

    if (email.isEmpty || !_isValidEmail(email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid email address first.')),
      );
      return;
    }

    // ✅ Capture before await
    final messenger = ScaffoldMessenger.of(context);

    setState(() => _sendingReset = true);
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);

      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('Password reset email sent to $email (if account exists)')));
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      final msg = (e.code == 'too-many-requests')
          ? 'Too many attempts. Try again later.'
          : 'If an account exists for that email, a reset link has been sent.';
      messenger.showSnackBar(SnackBar(content: Text(msg)));
    } finally {
      if (mounted) setState(() => _sendingReset = false);
    }
  }


  @override
  Widget build(BuildContext context) {
    ref.listen<String?>(
      teamProvider,
      (prev, next) {
        if (_closed || prev != null || next == null) return;
        if (!mounted) return; // ✅ right before context use

        _closed = true;
        Navigator.of(context, rootNavigator: true).pop(true);
      },
    );

    final dpr = MediaQuery.devicePixelRatioOf(context);
    const logoLogical = 100.0; // image size in logical pixels
    final logoPhysical = (logoLogical * dpr).round();

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
                  // Logo with a coloured background and rounded corners
                  SizedBox.square(
                    dimension: logoLogical,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(5),
                        child: Image.asset(
                          'assets/images/cup_logo.png',
                          fit: BoxFit.contain,
                          filterQuality: FilterQuality.high,
                          cacheWidth: logoPhysical,
                          cacheHeight: logoPhysical,
                          isAntiAlias: true,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text("Welcome to Rule Post!",
                      style: Theme.of(context).textTheme.titleMedium),
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
                      if (value == null || value.isEmpty) {
                        return 'Please enter some text';
                      }
                      final ok = _isValidEmail(value);
                      return ok ? null : 'Please enter a valid email';
                    },
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.username, AutofillHints.email],
                  ),
                  const SizedBox(height: 16),

                  // Password
                  TextFormField(
                    controller: _password,
                    obscureText: !_isPasswordVisible,
                    textInputAction: TextInputAction.done,
                    onEditingComplete: () => _onSignInPressed(),
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
                    autofillHints: const [AutofillHints.password],
                  ),


                  // Remember me
                  const SizedBox(height: 8),
                  CheckboxListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    value: _rememberMe,
                    onChanged: (v) => setState(() => _rememberMe = v ?? false),
                    title: const Text('Remember me'),
                  ),

                  // ✅ NEW: Forgot password (left aligned)
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: _sendingReset ? null : _onForgotPasswordPressed,
                      icon: const Icon(Icons.lock_reset),
                      label: Text(_sendingReset
                          ? 'Sending reset email…'
                          : 'Forgot password?'),
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Actions
                  Row(
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context,
                                rootNavigator: true)
                            .maybePop(false),
                        child: const Text('Cancel'),
                      ),
                      const Spacer(),
                      ElevatedButton(
                        onPressed: _sendingReset ? null : _onSignInPressed,
                        child: const Padding(
                          padding: EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          child: Text('Sign in',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold)),
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

    // ✅ Capture before any await
    final messenger = ScaffoldMessenger.of(context);

    if (kIsWeb) {
      await FirebaseAuth.instance.setPersistence(
        _rememberMe ? Persistence.LOCAL : Persistence.SESSION,
      );
    }

    final error = await _authService.signIn(_email.text.trim(), _password.text);

    if (!mounted) return;

    if (error != null) {
      messenger.showSnackBar(SnackBar(content: Text(error)));
    }
  }

}
