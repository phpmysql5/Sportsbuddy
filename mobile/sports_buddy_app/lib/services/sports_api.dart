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

  Future<List<String>> supportedCities() async {
    final response = await _request(method: 'GET', path: '/meta/supported-cities');
    final decoded = _decode(response);
    final cities = (decoded as Map)['cities'];
    if (cities is! List) {
      throw Exception('Invalid supported cities response');
    }

    return cities
        .map((city) => city.toString().trim())
        .where((city) => city.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
  }

  Future<List<String>> supportedSports() async {
    final response = await _request(method: 'GET', path: '/meta/supported-sports');
    final decoded = _decode(response);
    final sports = (decoded as Map)['sports'];
    if (sports is! List) {
      throw Exception('Invalid supported sports response');
    }

    return sports
        .map((sport) => sport.toString().trim())
        .where((sport) => sport.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
  }

  Future<void> logout() async {
    try {
      await _authorizedRequest(method: 'POST', path: '/auth/logout');
    } catch (_) {}
  }

  Future<Map<String, dynamic>> updateProfile({
    required String city,
    required List<String> sports,
    required String skillLevel,
    required List<String> availabilityDays,
  }) async {
    final normalizedSports = sports
        .map((sport) => sport.trim())
        .where((sport) => sport.isNotEmpty)
        .toList();

    final raw = await _authorizedRequest(
      method: 'PUT',
      path: '/profile',
      body: {
        'city': city,
        'sport': normalizedSports.isNotEmpty ? normalizedSports.first : '',
        'sports': normalizedSports,
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

  Future<Map<String, dynamic>> cancelOutgoingRequest({
    required String requestId,
  }) async {
    final raw = await _authorizedRequest(
      method: 'DELETE',
      path: '/connections/requests/$requestId',
    );

    return Map<String, dynamic>.from(raw as Map);
  }

  Future<Map<String, dynamic>> removeBuddy({
    required String buddyId,
  }) async {
    final raw = await _authorizedRequest(
      method: 'DELETE',
      path: '/connections/buddies/$buddyId',
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

  Future<Map<String, dynamic>> sendBuddyMessage({
    required String buddyId,
    required String content,
  }) async {
    final raw = await _authorizedRequest(
      method: 'POST',
      path: '/chat/buddies/$buddyId/messages',
      body: {'content': content},
    );

    return Map<String, dynamic>.from(raw as Map);
  }

  Future<List<Map<String, dynamic>>> buddyMessages({
    required String buddyId,
    int limit = 20,
  }) async {
    final raw = await _authorizedRequest(
      method: 'GET',
      path: '/chat/buddies/$buddyId/messages?limit=$limit',
    );

    return (raw as List)
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }

  Future<Map<String, dynamic>> blockUser({
    required String userId,
  }) async {
    final raw = await _authorizedRequest(
      method: 'POST',
      path: '/safety/blocks',
      body: {'userId': userId},
    );

    return Map<String, dynamic>.from(raw as Map);
  }

  Future<Map<String, dynamic>> unblockUser({
    required String userId,
  }) async {
    final raw = await _authorizedRequest(
      method: 'DELETE',
      path: '/safety/blocks/$userId',
    );

    return Map<String, dynamic>.from(raw as Map);
  }

  Future<Map<String, dynamic>> reportUser({
    required String userId,
    required String reason,
    String? details,
  }) async {
    final payload = <String, dynamic>{
      'userId': userId,
      'reason': reason,
    };
    if (details != null && details.trim().isNotEmpty) {
      payload['details'] = details.trim();
    }

    final raw = await _authorizedRequest(
      method: 'POST',
      path: '/safety/reports',
      body: payload,
    );

    return Map<String, dynamic>.from(raw as Map);
  }

  Future<Map<String, dynamic>> createSessionPlan({
    required DateTime scheduledAt,
    required String area,
    required String sport,
    required String skillLevel,
    required int maxPlayers,
  }) async {
    final raw = await _authorizedRequest(
      method: 'POST',
      path: '/sessions/plans',
      body: {
        'scheduledAt': scheduledAt.toIso8601String(),
        'area': area,
        'sport': sport,
        'skillLevel': skillLevel,
        'maxPlayers': maxPlayers,
      },
    );

    return Map<String, dynamic>.from(raw as Map);
  }

  Future<List<Map<String, dynamic>>> mySessionPlans() async {
    final raw = await _authorizedRequest(
      method: 'GET',
      path: '/sessions/plans/mine',
    );

    return (raw as List)
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }

  Future<List<Map<String, dynamic>>> discoverSessionPlans() async {
    final raw = await _authorizedRequest(
      method: 'GET',
      path: '/sessions/plans/discover',
    );

    return (raw as List)
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }

  Future<Map<String, dynamic>> joinSessionPlan({
    required String planId,
  }) async {
    final raw = await _authorizedRequest(
      method: 'POST',
      path: '/sessions/plans/$planId/join',
    );

    return Map<String, dynamic>.from(raw as Map);
  }

  Future<Map<String, dynamic>> leaveSessionPlan({
    required String planId,
  }) async {
    final raw = await _authorizedRequest(
      method: 'DELETE',
      path: '/sessions/plans/$planId/join',
    );

    return Map<String, dynamic>.from(raw as Map);
  }

  Future<Map<String, dynamic>> updateSessionPlanStatus({
    required String planId,
    required String status,
  }) async {
    final raw = await _authorizedRequest(
      method: 'PATCH',
      path: '/sessions/plans/$planId/status',
      body: {'status': status},
    );

    return Map<String, dynamic>.from(raw as Map);
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
      case 'PATCH':
        return _client.patch(uri, headers: headers, body: jsonEncode(body ?? {}));
      case 'DELETE':
        return _client.delete(uri, headers: headers);
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
