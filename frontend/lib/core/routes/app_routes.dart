import 'package:flutter/material.dart';
import '../../screens/auth/splash_screen.dart';
import '../../screens/auth/login_screen.dart';
import '../../screens/auth/signup_screen.dart';
import '../../screens/home/home_shell.dart';
import '../../screens/chat/chat_screen.dart';
import '../../screens/documents/document_management_screen.dart';

class AppRoutes {
  AppRoutes._();

  static const String splash = '/';
  static const String login = '/login';
  static const String signup = '/signup';
  static const String home = '/home';
  static const String chat = '/chat';
  static const String documents = '/documents';

  static Route<dynamic> generate(RouteSettings settings) {
    switch (settings.name) {
      case splash:
        return _fade(const SplashScreen());
      case login:
        return _fade(const LoginScreen());
      case signup:
        return _fade(const SignupScreen());
      case home:
        return _fade(const HomeShell());
      case chat:
        final sessionId = settings.arguments as String?;
        return _fade(ChatScreen(sessionId: sessionId));
      case documents:
        return _fade(const DocumentManagementScreen());
      default:
        return _fade(const SplashScreen());
    }
  }

  static PageRouteBuilder _fade(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (_, __, ___) => page,
      transitionDuration: const Duration(milliseconds: 220),
      transitionsBuilder: (_, animation, __, child) {
        return FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: child,
        );
      },
    );
  }
}
