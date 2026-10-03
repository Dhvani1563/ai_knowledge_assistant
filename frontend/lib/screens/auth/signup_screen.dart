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

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _agreed = true;
  _AuthAction _action = _AuthAction.none;

  bool get _busy => _action != _AuthAction.none;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

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
    if (!_agreed) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please accept the terms to continue.')));
      return;
    }
    final auth = context.read<AuthProvider>();
    _run(_AuthAction.email, () => auth.signup(name: _nameController.text.trim(), email: _emailController.text.trim(), password: _passwordController.text));
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
              Text('Create your account', style: AppTextStyles.displayMd),
              const SizedBox(height: 8),
              Text('Turn your documents into answers, with sources.', style: AppTextStyles.bodyLg.copyWith(color: AppColors.textSecondary)),
              const SizedBox(height: 32),
              SocialButton(provider: SocialProvider.google, disabled: _busy, onPressed: () => _run(_AuthAction.google, auth.loginWithGoogle)),
              const SizedBox(height: 12),
              SocialButton(provider: SocialProvider.facebook, disabled: _busy, onPressed: () => _run(_AuthAction.facebook, auth.loginWithFacebook)),
              const SizedBox(height: 24),
              Row(
                children: [
                  const Expanded(child: Divider()),
                  Padding(padding: const EdgeInsets.symmetric(horizontal: 14), child: Text('or sign up with email', style: AppTextStyles.caption)),
                  const Expanded(child: Divider()),
                ],
              ),
              const SizedBox(height: 24),
              CustomTextField(
                label: 'Full name',
                hint: 'Jane Cooper',
                controller: _nameController,
                prefixIcon: Icons.person_outline_rounded,
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter your name' : null,
              ),
              const SizedBox(height: 18),
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
                hint: 'At least 6 characters',
                controller: _passwordController,
                isPassword: true,
                prefixIcon: Icons.lock_outline_rounded,
                validator: (v) => (v == null || v.length < 6) ? 'At least 6 characters' : null,
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: 24,
                    width: 24,
                    child: Checkbox(
                      value: _agreed,
                      onChanged: (v) => setState(() => _agreed = v ?? false),
                      activeColor: AppColors.brand,
                      side: const BorderSide(color: AppColors.lavender300, width: 1.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text('I agree to the Terms of Service and Privacy Policy', style: AppTextStyles.bodySm)),
                ],
              ),
              const SizedBox(height: 22),
              CustomButton(label: 'Create account', isLoading: _action == _AuthAction.email, onPressed: _busy ? null : _submitEmail),
              const SizedBox(height: 26),
              Center(
                child: GestureDetector(
                  onTap: _busy ? null : () => Navigator.of(context).pushReplacementNamed(AppRoutes.login),
                  child: Text.rich(TextSpan(
                    text: 'Already have an account?  ',
                    style: AppTextStyles.bodyMd.copyWith(color: AppColors.textSecondary),
                    children: [TextSpan(text: 'Sign in', style: AppTextStyles.bodyMd.copyWith(color: AppColors.brand, fontWeight: FontWeight.w700))],
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
