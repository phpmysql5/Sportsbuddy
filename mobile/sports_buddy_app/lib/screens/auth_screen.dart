import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../services/sports_api.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({
    super.key,
    required this.api,
    required this.onSuccess,
  });

  final SportsApi api;
  final void Function(Map<String, dynamic> user) onSuccess;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  static const String _defaultGoogleServerClientId =
      '1032938899677-kpmci4nbuko9gotfebhj4ddbkm2hgsqr.apps.googleusercontent.com';
  static const String _googleServerClientId =
      String.fromEnvironment(
        'GOOGLE_SERVER_CLIENT_ID',
        defaultValue: _defaultGoogleServerClientId,
      );

  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: const ['email', 'profile'],
    serverClientId:
        _googleServerClientId.isEmpty ? null : _googleServerClientId,
  );

  bool _loading = false;
  bool _registerMode = false;
  String? _error;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final data = _registerMode
          ? await widget.api.register(
              name: _name.text.trim(),
              email: _email.text.trim(),
              password: _password.text,
            )
          : await widget.api.login(
              email: _email.text.trim(),
              password: _password.text,
            );

      widget.onSuccess(Map<String, dynamic>.from(data['user']));
    } catch (e) {
      setState(() {
        _error = _toUserMessage(e);
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final account = await _googleSignIn.signIn();
      if (account == null) {
        setState(() {
          _error = 'Google sign-in was cancelled';
        });
        return;
      }

      final auth = await account.authentication;
      final idToken = auth.idToken;
      if (idToken == null || idToken.isEmpty) {
        throw Exception('Google sign-in did not return an ID token.');
      }

      final data = await widget.api.googleSignIn(idToken: idToken);
      widget.onSuccess(Map<String, dynamic>.from(data['user']));
    } catch (e) {
      setState(() {
        _error = _toUserMessage(e);
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          _registerMode ? 'Create account' : 'Welcome back',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Sports Buddy prototype login',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 20),
                        if (_registerMode)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: TextFormField(
                              controller: _name,
                              decoration:
                                  const InputDecoration(labelText: 'Name'),
                              validator: (v) =>
                                  (v == null || v.trim().length < 2)
                                      ? 'Enter a valid name'
                                      : null,
                            ),
                          ),
                        TextFormField(
                          controller: _email,
                          decoration: const InputDecoration(labelText: 'Email'),
                          validator: (v) => (v == null || !v.contains('@'))
                              ? 'Enter a valid email'
                              : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _password,
                          obscureText: true,
                          decoration: const InputDecoration(labelText: 'Password'),
                          validator: (v) => (v == null || v.length < 6)
                              ? 'Minimum 6 characters'
                              : null,
                        ),
                        if (_error != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Text(
                              _error!,
                              style: const TextStyle(color: Colors.red),
                            ),
                          ),
                        const SizedBox(height: 18),
                        FilledButton(
                          onPressed: _loading ? null : _submit,
                          child: Text(_loading
                              ? 'Please wait...'
                              : (_registerMode ? 'Register' : 'Login')),
                        ),
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          onPressed: _loading ? null : _signInWithGoogle,
                          icon: const Icon(Icons.login),
                          label: const Text('Continue with Google'),
                        ),
                        TextButton(
                          onPressed: _loading
                              ? null
                              : () {
                                  setState(() {
                                    _registerMode = !_registerMode;
                                    _error = null;
                                  });
                                },
                          child: Text(_registerMode
                              ? 'Already have an account? Login'
                              : 'New here? Register'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _toUserMessage(Object error) {
    if (error is PlatformException) {
      final message = (error.message ?? '').toLowerCase();
      if (error.code == 'sign_in_failed' || message.contains('api10')) {
        return 'Google sign-in is not configured correctly yet. Please try again in a minute.';
      }
      if (error.code == 'network_error' || message.contains('network')) {
        return 'Network issue while contacting Google. Check internet and retry.';
      }
      return 'Google sign-in failed. Please try again.';
    }

    final text = error.toString().replaceFirst('Exception: ', '');
    final lower = text.toLowerCase();
    if (lower.contains('connection refused') ||
      lower.contains('socketexception') ||
      lower.contains('failed host lookup') ||
      lower.contains('10.0.2.2:3000') ||
      (lower.contains('clientexception') &&
        lower.contains('10.0.2.2') &&
        (lower.contains('/auth/google') ||
          lower.contains('/auth/login') ||
          lower.contains('/auth/register')))) {
      return 'Backend server is not reachable. Start backend on port 3000 and try again.';
    }
    if (text.contains('Invalid email or password')) {
      return 'Invalid email or password.';
    }
    if (text.contains('Email is already registered')) {
      return 'Email is already registered. Please login.';
    }
    if (text.contains('Invalid Google ID token')) {
      return 'Google sign-in token was rejected. Please sign in again.';
    }
    if (text.contains('Missing auth session')) {
      return 'Your session expired. Please sign in again.';
    }
    return text;
  }
}
