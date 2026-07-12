import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const SportsBuddyApp());
}

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
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (!_authenticated) {
      return AuthScreen(api: _api, onSuccess: _onLoginSuccess);
    }

    return HomeScreen(
      api: _api,
      sessionStore: _sessionStore,
      initialUser: _currentUser,
      onLogout: _logout,
    );
  }
}

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, required this.api, required this.onSuccess});

  final SportsApi api;
  final void Function(Map<String, dynamic> user) onSuccess;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();

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
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
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
                              validator: (v) => (v == null || v.trim().length < 2)
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
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.api,
    required this.sessionStore,
    required this.initialUser,
    required this.onLogout,
  });

  final SportsApi api;
  final SessionStore sessionStore;
  final Map<String, dynamic>? initialUser;
  final Future<void> Function() onLogout;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _city = TextEditingController();
  final _sport = TextEditingController();
  final _availability = TextEditingController();

  String _skill = 'beginner';
  bool _profileLoading = false;
  bool _suggestionsLoading = false;
  String? _status;
  List<Map<String, dynamic>> _suggestions = [];

  @override
  void initState() {
    super.initState();
    _hydrateProfile();
    _loadSuggestions();
  }

  void _hydrateProfile() {
    final user = widget.initialUser;
    if (user == null) {
      return;
    }
    _city.text = (user['city'] ?? '').toString();
    _sport.text = (user['sport'] ?? '').toString();
    _skill = (user['skillLevel'] ?? 'beginner').toString();
    final days = ((user['availabilityDays'] ?? []) as List)
        .map((d) => d.toString())
        .join(',');
    _availability.text = days;
  }

  Future<void> _saveProfile() async {
    setState(() {
      _profileLoading = true;
      _status = null;
    });

    try {
      await widget.api.updateProfile(
        city: _city.text.trim(),
        sport: _sport.text.trim(),
        skillLevel: _skill,
        availabilityDays: _availability.text
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList(),
      );

      setState(() {
        _status = 'Profile updated';
      });
      await _loadSuggestions();
    } catch (e) {
      setState(() {
        _status = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      setState(() {
        _profileLoading = false;
      });
    }
  }

  Future<void> _loadSuggestions() async {
    setState(() {
      _suggestionsLoading = true;
    });

    try {
      final data = await widget.api.suggestions();
      final list = data
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
      setState(() {
        _suggestions = list;
      });
    } catch (_) {
      setState(() {
        _suggestions = [];
      });
    } finally {
      setState(() {
        _suggestionsLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sports Buddy'),
        actions: [
          IconButton(
            onPressed: widget.onLogout,
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadSuggestions,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Your Profile',
                        style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _city,
                      decoration: const InputDecoration(labelText: 'City'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _sport,
                      decoration: const InputDecoration(labelText: 'Sport'),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: _skill,
                      items: const [
                        DropdownMenuItem(
                          value: 'beginner',
                          child: Text('Beginner'),
                        ),
                        DropdownMenuItem(
                          value: 'intermediate',
                          child: Text('Intermediate'),
                        ),
                        DropdownMenuItem(
                          value: 'advanced',
                          child: Text('Advanced'),
                        ),
                      ],
                      onChanged: (v) {
                        if (v != null) {
                          setState(() {
                            _skill = v;
                          });
                        }
                      },
                      decoration: const InputDecoration(labelText: 'Skill'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _availability,
                      decoration: const InputDecoration(
                        labelText: 'Availability days',
                        hintText: 'Mon, Wed, Fri',
                      ),
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: _profileLoading ? null : _saveProfile,
                      child: Text(
                        _profileLoading ? 'Saving...' : 'Save profile',
                      ),
                    ),
                    if (_status != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(_status!),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Suggested Buddies',
                    style: Theme.of(context).textTheme.titleLarge),
                TextButton(
                  onPressed: _suggestionsLoading ? null : _loadSuggestions,
                  child: const Text('Refresh'),
                ),
              ],
            ),
            if (_suggestionsLoading)
              const Padding(
                padding: EdgeInsets.all(12),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_suggestions.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'No suggestions yet. Complete profile details to see matches.',
                  ),
                ),
              )
            else
              ..._suggestions.map(
                (s) => Card(
                  child: ListTile(
                    title: Text((s['user']?['name'] ?? 'Unknown').toString()),
                    subtitle: Text(
                      '${s['user']?['sport'] ?? '-'} in ${s['user']?['city'] ?? '-'}\n'
                      'Reasons: ${(s['reasons'] as List).join(', ')}',
                    ),
                    isThreeLine: true,
                    trailing: CircleAvatar(
                      child: Text('${s['score']}'),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class SessionStore {
  String? accessToken;
  String? refreshToken;

  bool get hasTokens =>
      accessToken != null && accessToken!.isNotEmpty &&
      refreshToken != null && refreshToken!.isNotEmpty;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    accessToken = prefs.getString('accessToken');
    refreshToken = prefs.getString('refreshToken');
  }

  Future<void> save({required String access, required String refresh}) async {
    accessToken = access;
    refreshToken = refresh;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('accessToken', access);
    await prefs.setString('refreshToken', refresh);
  }

  Future<void> clear() async {
    accessToken = null;
    refreshToken = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('accessToken');
    await prefs.remove('refreshToken');
  }
}

class SportsApi {
  SportsApi(this._session);

  final SessionStore _session;
  final http.Client _client = http.Client();

  String get _baseUrl {
    if (Platform.isAndroid) {
      return 'http://10.0.2.2:3000';
    }
    return 'http://localhost:3000';
  }

  Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final data = await _post('/auth/register', {
      'name': name,
      'email': email,
      'password': password,
    });
    await _persistTokens(data);
    return data;
  }

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final data = await _post('/auth/login', {
      'email': email,
      'password': password,
    });
    await _persistTokens(data);
    return data;
  }

  Future<Map<String, dynamic>> me() async {
    final raw = await _authorizedRequest(
      method: 'GET',
      path: '/auth/me',
    );
    return Map<String, dynamic>.from(raw as Map);
  }

  Future<void> logout() async {
    try {
      await _authorizedRequest(method: 'POST', path: '/auth/logout');
    } catch (_) {}
  }

  Future<Map<String, dynamic>> updateProfile({
    required String city,
    required String sport,
    required String skillLevel,
    required List<String> availabilityDays,
  }) async {
    final raw = await _authorizedRequest(
      method: 'PUT',
      path: '/profile',
      body: {
        'city': city,
        'sport': sport,
        'skillLevel': skillLevel,
        'availabilityDays': availabilityDays,
      },
    );
    return Map<String, dynamic>.from(raw as Map);
  }

  Future<List<dynamic>> suggestions() async {
    final raw = await _authorizedRequest(
      method: 'GET',
      path: '/matching/suggestions',
    );
    return List<dynamic>.from(raw as List);
  }

  Future<dynamic> _authorizedRequest({
    required String method,
    required String path,
    Map<String, dynamic>? body,
  }) async {
    if (!_session.hasTokens) {
      throw Exception('Missing auth session');
    }

    final first = await _request(
      method: method,
      path: path,
      body: body,
      accessToken: _session.accessToken,
    );

    if (first.statusCode != 401) {
      return _decode(first);
    }

    await _refreshToken();
    final second = await _request(
      method: method,
      path: path,
      body: body,
      accessToken: _session.accessToken,
    );
    return _decode(second);
  }

  Future<void> _refreshToken() async {
    if (_session.refreshToken == null) {
      throw Exception('Missing refresh token');
    }

    final data = await _post('/auth/refresh', {
      'refreshToken': _session.refreshToken,
    });

    final access = data['accessToken']?.toString();
    final refresh = data['refreshToken']?.toString();
    if (access == null || refresh == null) {
      throw Exception('Invalid refresh response');
    }

    await _session.save(access: access, refresh: refresh);
  }

  Future<http.Response> _request({
    required String method,
    required String path,
    Map<String, dynamic>? body,
    String? accessToken,
  }) {
    final uri = Uri.parse('$_baseUrl$path');
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };
    if (accessToken != null && accessToken.isNotEmpty) {
      headers['Authorization'] = 'Bearer $accessToken';
    }

    switch (method) {
      case 'GET':
        return _client.get(uri, headers: headers);
      case 'POST':
        return _client.post(uri, headers: headers, body: jsonEncode(body ?? {}));
      case 'PUT':
        return _client.put(uri, headers: headers, body: jsonEncode(body ?? {}));
      default:
        throw Exception('Unsupported method $method');
    }
  }

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> body,
  ) async {
    final response = await _request(method: 'POST', path: path, body: body);
    final decoded = _decode(response);
    return Map<String, dynamic>.from(decoded as Map);
  }

  dynamic _decode(http.Response response) {
    if (response.body.isEmpty) {
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return {};
      }
      throw Exception('Request failed with status ${response.statusCode}');
    }

    final decoded = jsonDecode(response.body);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decoded;
    }

    if (decoded is Map && decoded['message'] != null) {
      throw Exception(decoded['message'].toString());
    }
    throw Exception('Request failed with status ${response.statusCode}');
  }

  Future<void> _persistTokens(Map<String, dynamic> data) async {
    final access = data['accessToken']?.toString();
    final refresh = data['refreshToken']?.toString();
    if (access == null || refresh == null) {
      throw Exception('Auth response is missing tokens');
    }
    await _session.save(access: access, refresh: refresh);
  }
}
