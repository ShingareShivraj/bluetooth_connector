import 'package:flutter/foundation.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';

class LoginViewModel extends ChangeNotifier {
  final AuthService auth;
  LoginViewModel(this.auth);
  bool busy = false;
  String? error;
  bool _disposed = false;

  Future<bool> signIn(String user, String password, bool remember) async {
    if (busy) return false;
    error = null;
    if (user.trim().isEmpty || password.isEmpty) {
      error = 'Enter your username and password.';
      notifyListeners();
      return false;
    }
    busy = true;
    notifyListeners();
    try {
      await auth.signIn(user, password, remember: remember);
      return true;
    } on ApiException catch (exception) {
      error = exception.message;
      return false;
    } catch (_) {
      error = 'Could not complete sign-in or save the session. Please try again.';
      return false;
    } finally {
      busy = false;
      if (!_disposed) notifyListeners();
    }
  }

  @override
  void dispose() { _disposed = true; super.dispose(); }
}
