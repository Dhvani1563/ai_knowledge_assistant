import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import '../core/constants/app_constants.dart';
import '../core/network/api_client.dart';
import '../models/user_model.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthProvider extends ChangeNotifier {
  final _api = ApiClient.instance;

  // serverClientId MUST be your backend's GOOGLE_CLIENT_ID (the Web client
  // ID from Google Cloud Console), not the Android/iOS client ID. That's
  // what makes the idToken this produces verifiable by the backend — see
  // backend/app/services/oauth_service.py.
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email'],
    serverClientId: AppConstants.googleWebClientId,
  );

  AuthStatus _status = AuthStatus.unknown;
  UserModel? _user;
  bool _isLoading = false;
  String? _errorMessage;

  AuthStatus get status => _status;
  UserModel? get user => _user;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _status == AuthStatus.authenticated;

  Future<void> tryAutoLogin() async {
    final token = await _api.token;
    if (token == null) {
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return;
    }
    try {
      final data = await _api.get('/auth/me');
      _user = UserModel.fromJson(data as Map<String, dynamic>);
      _status = AuthStatus.authenticated;
    } catch (_) {
      await _api.clearToken();
      _status = AuthStatus.unauthenticated;
    }
    notifyListeners();
  }

  Future<bool> login({required String email, required String password}) async {
    _setLoading(true);
    _errorMessage = null;
    try {
      final data = await _api.post(
        '/auth/login',
        body: {'email': email, 'password': password},
        auth: false,
      ) as Map<String, dynamic>;
      await _api.saveToken(data['access_token'] as String);
      _user = UserModel.fromJson(data['user'] as Map<String, dynamic>);
      _status = AuthStatus.authenticated;
      return true;
    } catch (e) {
      _errorMessage = e is ApiException ? e.message : 'Could not reach the server. Is the backend running?';
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> signup({required String name, required String email, required String password}) async {
    _setLoading(true);
    _errorMessage = null;
    try {
      final data = await _api.post(
        '/auth/signup',
        body: {'name': name, 'email': email, 'password': password},
        auth: false,
      ) as Map<String, dynamic>;
      await _api.saveToken(data['access_token'] as String);
      _user = UserModel.fromJson(data['user'] as Map<String, dynamic>);
      _status = AuthStatus.authenticated;
      return true;
    } catch (e) {
      _errorMessage = e is ApiException ? e.message : 'Could not reach the server. Is the backend running?';
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Opens the native Google account picker, then exchanges the resulting
  /// ID token with the backend (POST /auth/google), which verifies it
  /// against Google itself before creating/logging in the user. Returns
  /// false (no error shown) if the user simply cancels the picker.
  Future<bool> loginWithGoogle() async {
    _setLoading(true);
    _errorMessage = null;
    try {
      if (AppConstants.googleWebClientId.startsWith('YOUR_WEB')) {
        throw ApiException('Google sign-in is not configured yet. Follow AUTH_SETUP.md, then set googleWebClientId in app_constants.dart.');
      } 
      final account = await _googleSignIn.signIn();
      if (account == null) return false; // user cancelled

      final googleAuth = await account.authentication;
      final idToken = googleAuth.idToken;
      if (idToken == null) {
        throw ApiException('Google did not return an ID token. Check serverClientId is set correctly.');
      }

      final data = await _api.post('/auth/google', body: {'id_token': idToken}, auth: false) as Map<String, dynamic>;
      await _api.saveToken(data['access_token'] as String);
      _user = UserModel.fromJson(data['user'] as Map<String, dynamic>);
      _status = AuthStatus.authenticated;
      return true;
    } catch (e, stackTrace) {
  print('GOOGLE SIGN-IN ERROR: $e');
  print('GOOGLE SIGN-IN STACK TRACE: $stackTrace');

  _errorMessage = e is ApiException
      ? e.message
      : 'Google sign-in error: $e';

  return false;
}
  }

  /// Same pattern as Google: native Facebook login dialog, then the
  /// resulting access token is verified server-side (POST /auth/facebook)
  /// against Facebook's own debug_token endpoint before trusting it.
  Future<bool> loginWithFacebook() async {
    _setLoading(true);
    _errorMessage = null;
    try {
      final result = await FacebookAuth.instance.login(
  permissions: ['email', 'public_profile'],
  loginBehavior: LoginBehavior.webOnly,
);

      if (result.status == LoginStatus.cancelled) return false;
      if (result.status != LoginStatus.success || result.accessToken == null) {
        // was: throw ApiException(result.message ?? 'Facebook sign-in failed.');
throw ApiException('Facebook returned ${result.status.name}: ${result.message ?? 'no message'}');
      }

      final accessToken = result.accessToken!.tokenString;
      final data = await _api.post('/auth/facebook', body: {'access_token': accessToken}, auth: false) as Map<String, dynamic>;
      await _api.saveToken(data['access_token'] as String);
      _user = UserModel.fromJson(data['user'] as Map<String, dynamic>);
      _status = AuthStatus.authenticated;
      return true;
    } catch (e) {
      // was: _errorMessage = e is ApiException ? e.message : 'Facebook sign-in failed. Please try again.';
_errorMessage = e is ApiException ? e.message : 'Facebook sign-in error: $e';
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> logout() async {
    await _api.clearToken();
    try {
      await _googleSignIn.signOut();
    } catch (_) {}
    try {
      await FacebookAuth.instance.logOut();
    } catch (_) {}
    _user = null;
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}
