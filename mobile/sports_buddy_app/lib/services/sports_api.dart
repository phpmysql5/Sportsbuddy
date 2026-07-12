import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'session_store.dart';

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

  Future<Map<String, dynamic>> googleSignIn({required String idToken}) async {
    final data = await _post('/auth/google', {
      'idToken': idToken,
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

  Future<Map<String, dynamic>> sendConnectionRequest({
    required String receiverId,
  }) async {
    final raw = await _authorizedRequest(
      method: 'POST',
      path: '/connections/requests',
      body: {'receiverId': receiverId},
    );
    return Map<String, dynamic>.from(raw as Map);
  }

  Future<List<Map<String, dynamic>>> incomingRequests() async {
    final raw = await _authorizedRequest(
      method: 'GET',
      path: '/connections/requests/incoming',
    );

    return (raw as List)
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }

  Future<List<Map<String, dynamic>>> outgoingRequests() async {
    final raw = await _authorizedRequest(
      method: 'GET',
      path: '/connections/requests/outgoing',
    );

    return (raw as List)
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }

  Future<Map<String, dynamic>> respondToRequest({
    required String requestId,
    required String action,
  }) async {
    final raw = await _authorizedRequest(
      method: 'POST',
      path: '/connections/requests/$requestId/respond',
      body: {'action': action},
    );

    return Map<String, dynamic>.from(raw as Map);
  }

  Future<List<Map<String, dynamic>>> buddies() async {
    final raw = await _authorizedRequest(
      method: 'GET',
      path: '/connections/buddies',
    );

    return (raw as List)
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
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
      final message = decoded['message'];
      if (message is List) {
        throw Exception(message.join(', '));
      }
      throw Exception(message.toString());
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

  void dispose() {
    _client.close();
  }
}
