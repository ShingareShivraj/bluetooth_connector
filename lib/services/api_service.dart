import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/login_model.dart';
import 'api_endpoints.dart';
import 'auth_service.dart';
import '../models/login_model.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  const ApiException(this.message, [this.statusCode]);
  @override
  String toString() => message;
}

class ApiService {
  Future<Map<String, dynamic>> login(String user, String password) => _request(
    ApiEndpoints.loginMethod, body: {'usr': user, 'pwd': password},
  );

  Future<String> currentUser(LoginModel session) async {
    final response = await _request(ApiEndpoints.currentUserMethod, session: session);
    return response['message']?.toString() ?? '';
  }

  Future<Map<String, dynamic>> _request(String method,
      {Map<String, String>? body, LoginModel? session}) async {
    final client = http.Client();
    try {
      final request = http.Request(body == null ? 'GET' : 'POST', ApiEndpoints.method(method));
      // Credentials must never follow redirects to another host.
      request.followRedirects = false;
      request.headers['Accept'] = 'application/json';
      if (session != null) {
        if (session.site != ApiEndpoints.baseUrl) {
          throw const ApiException('The server changed. Please sign in again.');
        }
        request.headers['Cookie'] = 'sid=${session.sid}';
      }
      if (body != null) request.bodyFields = body;
      final response = await (() async {
        final streamed = await client.send(request);
        return http.Response.fromStream(streamed);
      })().timeout(const Duration(seconds: 25));
      Map<String, dynamic> data;
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is! Map<String, dynamic>) throw const FormatException();
        data = decoded;
      } catch (_) {
        throw ApiException('The server returned an invalid response.', response.statusCode);
      }
      final messageMap = data['message'] is Map ? Map<String, dynamic>.from(data['message']) : null;
      final result = messageMap ?? data;
      final code = int.tryParse('${result['status_code'] ?? result['status'] ?? ''}');
      final failed = response.statusCode < 200 || response.statusCode >= 300 ||
          data['exc'] != null || data['exception'] != null ||
          result['success'] == false || result['status'] == 'error' ||
          (code != null && code >= 400);
      if (failed) {
        throw ApiException(_errorMessage(result, response.statusCode),
          code ?? response.statusCode);
      }
      if (method == ApiEndpoints.loginMethod) {
        final cookies = response.headers['set-cookie'] ?? '';
        final sid = RegExp(r'(?:^|,\s*)sid=([^;,\s]+)')
            .firstMatch(cookies)
            ?.group(1);

        if (sid == null || sid.isEmpty || sid == 'Guest') {
          throw const ApiException('ERP did not return a signed-in session.');
        }

        data['sid'] = sid;
      }

      return data;
    } on ApiException {
      rethrow;
    } on TimeoutException {
      throw const ApiException('Connection timed out. Please try again.');
    } on SocketException {
      throw const ApiException('Cannot reach the server. Check your internet connection.');
    } on http.ClientException {
      throw const ApiException('Cannot connect to the server. Please try again.');
    } finally {
      client.close();
    }
  }

  String _errorMessage(Map<String, dynamic> data, int status) {
    final value = data['message'];
    if (value is String && value.trim().isNotEmpty) {
      return value.replaceAll(RegExp(r'<[^>]*>'), '').trim();
    }
    if (status == 401) return 'Invalid username or password.';
    if (status == 403) return 'Your account is not allowed to sign in.';
    return 'The server could not complete sign-in. Please try again.';
  }
}
