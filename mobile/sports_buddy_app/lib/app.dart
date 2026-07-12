import 'package:flutter/material.dart';

import 'screens/auth_screen.dart';
import 'screens/home_screen.dart';
import 'services/session_store.dart';
import 'services/sports_api.dart';

class SportsBuddyApp extends StatelessWidget {
  const SportsBuddyApp({super.key});

  @override
  Widget build(BuildContext context) {
    const base = Color(0xFF00BFA6);
    return MaterialApp(
      title: 'Sports Buddy',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: base,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF7F8F3),
        useMaterial3: true,
      ),
      home: const AppShell(),
    );
  }
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  final SessionStore _sessionStore = SessionStore();
  late final SportsApi _api = SportsApi(_sessionStore);

  bool _loading = true;
  bool _authenticated = false;
  Map<String, dynamic>? _currentUser;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await _sessionStore.load();
    if (!_sessionStore.hasTokens) {
      setState(() {
        _loading = false;
      });
      return;
    }

    try {
      final me = await _api.me();
      setState(() {
        _currentUser = me;
        _authenticated = true;
      });
    } catch (_) {
      await _sessionStore.clear();
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  void _onLoginSuccess(Map<String, dynamic> user) {
    setState(() {
      _authenticated = true;
      _currentUser = user;
    });
  }

  Future<void> _logout() async {
    try {
      await _api.logout();
    } catch (_) {}
    await _sessionStore.clear();
    setState(() {
      _authenticated = false;
      _currentUser = null;
    });
  }

  @override
  void dispose() {
    _api.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (!_authenticated) {
      return AuthScreen(api: _api, onSuccess: _onLoginSuccess);
    }

    return HomeScreen(
      api: _api,
      initialUser: _currentUser,
      onLogout: _logout,
    );
  }
}
