import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/routes/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/common/app_logo.dart';
import '../../widgets/common/auth_scaffold.dart';
import '../../widgets/common/custom_button.dart';
import '../../widgets/common/custom_textfield.dart';
import '../../widgets/common/social_button.dart';

enum _AuthAction { none, email, google, facebook }

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  _AuthAction _action = _AuthAction.none;

  bool get _busy => _action != _AuthAction.none;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// One place for "run an auth call, then navigate or show the error".
  Future<void> _run(_AuthAction action, Future<bool> Function() call) async {
    if (_busy) return;
    setState(() => _action = action);
    final auth = context.read<AuthProvider>();
    final success = await call();
    if (!mounted) return;
    setState(() => _action = _AuthAction.none);
    if (success) {
      Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.home, (route) => false);
    } else if (auth.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(auth.errorMessage!)));
    }
  }

  void _submitEmail() {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    _run(_AuthAction.email, () => auth.login(email: _emailController.text.trim(), password: _passwordController.text));
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthProvider>();
    return AuthScaffold(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AppLogo(size: 52),
              const SizedBox(height: 32),
              Text('Welcome back', style: AppTextStyles.displayMd),
              const SizedBox(height: 8),
              Text('Sign in to chat with your documents.', style: AppTextStyles.bodyLg.copyWith(color: AppColors.textSecondary)),
              const SizedBox(height: 32),
              if (_action == _AuthAction.google)
                const _SocialProgress(label: 'Connecting to Google…')
              else
                SocialButton(provider: SocialProvider.google, disabled: _busy, onPressed: () => _run(_AuthAction.google, auth.loginWithGoogle)),
              const SizedBox(height: 12),
              if (_action == _AuthAction.facebook)
                const _SocialProgress(label: 'Connecting to Facebook…')
              else
                SocialButton(provider: SocialProvider.facebook, disabled: _busy, onPressed: () => _run(_AuthAction.facebook, auth.loginWithFacebook)),
              const SizedBox(height: 24),
              Row(
                children: [
                  const Expanded(child: Divider()),
                  Padding(padding: const EdgeInsets.symmetric(horizontal: 14), child: Text('or use email', style: AppTextStyles.caption)),
                  const Expanded(child: Divider()),
                ],
              ),
              const SizedBox(height: 24),
              CustomTextField(
                label: 'Email',
                hint: 'you@example.com',
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                prefixIcon: Icons.mail_outline_rounded,
                validator: (v) => (v == null || !v.contains('@')) ? 'Enter a valid email' : null,
              ),
              const SizedBox(height: 18),
              CustomTextField(
                label: 'Password',
                hint: 'Your password',
                controller: _passwordController,
                isPassword: true,
                prefixIcon: Icons.lock_outline_rounded,
                validator: (v) => (v == null || v.length < 6) ? 'At least 6 characters' : null,
              ),
              const SizedBox(height: 26),
              CustomButton(label: 'Sign in', isLoading: _action == _AuthAction.email, onPressed: _busy ? null : _submitEmail),
              const SizedBox(height: 28),
              Center(
                child: GestureDetector(
                  onTap: _busy ? null : () => Navigator.of(context).pushReplacementNamed(AppRoutes.signup),
                  child: Text.rich(TextSpan(
                    text: "New here?  ",
                    style: AppTextStyles.bodyMd.copyWith(color: AppColors.textSecondary),
                    children: [TextSpan(text: 'Create an account', style: AppTextStyles.bodyMd.copyWith(color: AppColors.brand, fontWeight: FontWeight.w700))],
                  )),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Replaces a social button while its sign-in is in progress, so the user
/// sees *which* provider is working instead of a generic spinner.
class _SocialProgress extends StatelessWidget {
  final String label;
  const _SocialProgress({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 54,
      width: double.infinity,
      decoration: BoxDecoration(color: AppColors.lavender50, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.lavender200)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.2, color: AppColors.brand)),
          const SizedBox(width: 12),
          Text(label, style: AppTextStyles.bodyMd.copyWith(color: AppColors.brandDeep, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
