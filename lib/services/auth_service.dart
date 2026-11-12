import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/login_model.dart';
import 'api_endpoints.dart';
import 'api_service.dart';
import '../screens/login_viewmodel.dart';
import '../screens/login_screen.dart';
import '../models/login_model.dart';

class AuthService extends ChangeNotifier {
  static const _sessionKey = 'garam_mug_frappe_session_v2';
  final _storage = const FlutterSecureStorage();
  final _api = ApiService();
  LoginModel? _session;
  LoginModel? get session => _session;

  Future<LoginModel> signIn(
      String user,
      String password, {
        required bool remember,
      }) async {
    final response = await _api.login(user.trim(), password);
    final sid = response['sid'] as String;

    final actualUser = await _api.currentUser(
      LoginModel(site: ApiEndpoints.baseUrl, user: '', sid: sid),
    );

    final session = LoginModel(
      site: ApiEndpoints.baseUrl,
      user: actualUser,
      sid: sid,
    );

    if (!session.isValid) {
      throw const ApiException('Could not verify your ERP login.');
    }

    if (remember) {
      await _storage.write(
        key: _sessionKey,
        value: jsonEncode(session.toJson()),
      );
    } else {
      await _storage.delete(key: _sessionKey);
    }

    _session = session;
    notifyListeners();
    return session;
  }

  Future<bool> restoreSession() async {
    if (_session != null) return true;
    final stored = await _storage.read(key: _sessionKey);
    if (stored == null) return false;
    LoginModel candidate;
    try {
      candidate = LoginModel.fromJson(Map<String, dynamic>.from(jsonDecode(stored)));
    } catch (_) {
      await _storage.delete(key: _sessionKey);
      return false;
    }
    if (!candidate.isValid || candidate.site != ApiEndpoints.baseUrl) {
      await _storage.delete(key: _sessionKey);
      return false;
    }
    try {
      final user = await _api.currentUser(candidate);
      if (user != candidate.user || user == 'Guest') {
        await signOut();
        return false;
      }
    } on ApiException catch (error) {
      if (error.statusCode == 401 || error.statusCode == 403) {
        await signOut();
        return false;
      }
      rethrow; // A network outage must not erase a saved login.
    }
    _session = candidate;
    notifyListeners();
    return true;
  }

  Future<void> signOut() async {
    await _storage.delete(key: _sessionKey);
    _session = null;
    notifyListeners();
  }
}
