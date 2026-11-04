import 'package:flutter/material.dart';

import '../../core/locale/auth_messages.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/auth_hero_image.dart';
import '../../core/widgets/field_input.dart';
import '../../core/widgets/primary_button.dart';
import '../../data/services/auth_service.dart';
import '../../l10n/generated/app_localizations.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    required this.authService,
    required this.onAuthSuccess,
    required this.onSignUp,
    required this.onGuest,
  });

  final AuthService authService;
  final Future<void> Function() onAuthSuccess;
  final VoidCallback onSignUp;
  final VoidCallback onGuest;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();

  bool _obscure = true;
  bool _rememberMe = true;
  bool _loading = false;
  AuthErrorCode? _errorCode;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_loading) return;
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _errorCode = null;
    });
    try {
      await widget.authService.signInWithEmail(
        email: _email.text.trim(),
        password: _password.text,
      );
      if (!mounted) return;
      await widget.onAuthSuccess();
    } on AuthFailure catch (e) {
      if (!mounted) return;
      setState(() => _errorCode = e.code);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String? _validateEmail(String? v) {
    final l10n = AppLocalizations.of(context)!;
    final value = v?.trim() ?? '';
    if (value.isEmpty) return l10n.errorEmailRequired;
    final regex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!regex.hasMatch(value)) return l10n.errorEmailInvalid;
    return null;
  }

  String? _validatePassword(String? v) {
    final l10n = AppLocalizations.of(context)!;
    if (v == null || v.isEmpty) return l10n.errorPasswordRequired;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final media = MediaQuery.of(context);
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 8,
            bottom: media.viewInsets.bottom + 24,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 8),
                  const AuthHeroImage(
                    maxWidthFactor: 0.86,
                    heightFactor: 0.27,
                    minHeight: 150,
                    maxHeight: 240,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    l10n.loginWelcome,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.loginSubtitle,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                  ),
                  const SizedBox(height: 24),
                  Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        FieldInput(
                          controller: _email,
                          hint: l10n.loginEmailHint,
                          icon: Icons.mail_outline_rounded,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [AutofillHints.email],
                          validator: _validateEmail,
                        ),
                        const SizedBox(height: 14),
                        FieldInput(
                          controller: _password,
                          hint: l10n.loginPasswordHint,
                          icon: Icons.lock_outline_rounded,
                          obscure: _obscure,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _submit(),
                          autofillHints: const [AutofillHints.password],
                          validator: _validatePassword,
                          suffixIcon: PasswordToggleSuffix(
                            visible: _obscure,
                            onTap: () => setState(() => _obscure = !_obscure),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_errorCode != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      AuthMessages.forCode(l10n, _errorCode!),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.danger,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      SizedBox(
                        height: 28,
                        width: 28,
                        child: Checkbox(
                          value: _rememberMe,
                          onChanged: (v) =>
                              setState(() => _rememberMe = v ?? false),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          l10n.loginKeepMe,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: _loading ? null : () {},
                        child: Text(
                          l10n.loginForgot,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  PrimaryButton(
                    label: l10n.loginButton,
                    loading: _loading,
                    onPressed: _submit,
                  ),
                  const SizedBox(height: 22),
                  _DividerOr(label: l10n.loginContinueAs),
                  const SizedBox(height: 16),
                  _GuestButton(
                    label: l10n.loginGuest,
                    onTap: widget.onGuest,
                  ),
                  const SizedBox(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        l10n.loginNoAccount,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                      GestureDetector(
                        onTap: widget.onSignUp,
                        child: Text(
                          l10n.loginSignUp,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DividerOr extends StatelessWidget {
  const _DividerOr({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider(color: AppColors.border)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            label,
            style: const TextStyle(
              color: AppColors.textTertiary,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const Expanded(child: Divider(color: AppColors.border)),
      ],
    );
  }
}

class _GuestButton extends StatelessWidget {
  const _GuestButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(28),
      onTap: onTap,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.person_outline_rounded,
              color: AppColors.textPrimary,
              size: 22,
            ),
            const SizedBox(width: 10),
            Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
