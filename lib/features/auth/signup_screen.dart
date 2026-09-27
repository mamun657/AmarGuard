import 'package:flutter/material.dart';

import '../../core/locale/auth_messages.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/auth_hero_image.dart';
import '../../core/widgets/field_input.dart';
import '../../core/widgets/primary_button.dart';
import '../../data/services/auth_service.dart';
import '../../data/services/user_service.dart';
import '../../l10n/generated/app_localizations.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({
    super.key,
    required this.authService,
    required this.userService,
    required this.onAuthSuccess,
    required this.onLogin,
  });

  final AuthService authService;
  final UserService userService;
  final Future<void> Function() onAuthSuccess;
  final VoidCallback onLogin;

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  bool _obscurePwd = true;
  bool _obscureConfirm = true;
  bool _agreed = false;
  bool _loading = false;
  AuthErrorCode? _errorCode;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_loading) return;
    if (!_formKey.currentState!.validate()) return;
    if (!_agreed) {
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.danger,
          content: Text(l10n.errorAgreeTerms),
        ),
      );
      return;
    }
    setState(() {
      _loading = true;
      _errorCode = null;
    });
    try {
      await widget.authService.registerWithEmail(
        email: _email.text.trim(),
        password: _password.text,
      );
      final credential = widget.authService.currentUser;
      if (credential != null) {
        await widget.userService.createProfile(
          displayName: _name.text.trim(),
          email: _email.text.trim(),
          phoneNumber: _phone.text.trim(),
        );
      }
      if (!mounted) return;
      await widget.onAuthSuccess();
    } on AuthFailure catch (e) {
      if (!mounted) return;
      setState(() => _errorCode = e.code);
    } catch (_) {
      if (!mounted) return;
      setState(() => _errorCode = AuthErrorCode.generic);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String? _required(String? v, String fieldKey) {
    final l10n = AppLocalizations.of(context)!;
    if (v == null || v.trim().isEmpty) {
      switch (fieldKey) {
        case 'name':
          return l10n.errorNameRequired;
        case 'phone':
          return l10n.errorPhoneRequired;
      }
      return l10n.errorGeneric;
    }
    return null;
  }

  String? _emailCheck(String? v) {
    final l10n = AppLocalizations.of(context)!;
    final value = v?.trim() ?? '';
    if (value.isEmpty) return l10n.errorEmailRequired;
    final regex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!regex.hasMatch(value)) return l10n.errorEmailInvalid;
    return null;
  }

  String? _phoneCheck(String? v) {
    final l10n = AppLocalizations.of(context)!;
    final value = v?.trim() ?? '';
    if (value.isEmpty) return l10n.errorPhoneRequired;
    final regex = RegExp(r'^[0-9+\-\s()]{7,}$');
    if (!regex.hasMatch(value)) return l10n.errorPhoneInvalid;
    return null;
  }

  String? _passwordCheck(String? v) {
    final l10n = AppLocalizations.of(context)!;
    if (v == null || v.isEmpty) return l10n.errorPasswordRequired;
    if (v.length < 6) return l10n.errorPasswordShort;
    return null;
  }

  String? _confirmCheck(String? v) {
    final l10n = AppLocalizations.of(context)!;
    if (v == null || v.isEmpty) return l10n.errorConfirmRequired;
    if (v != _password.text) return l10n.errorConfirmMismatch;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final media = MediaQuery.of(context);
    final keyboardOpen = media.viewInsets.bottom > 0;
    final compact = media.size.height < 720;
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.textPrimary,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, size: 22),
          onPressed: widget.onLogin,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
        ),
      ),
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final horizontalPadding = constraints.maxWidth > 480 ? 24.0 : 20.0;
            final maxContentWidth =
                constraints.maxWidth > 480 ? 480.0 : constraints.maxWidth;
            return Center(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight,
                  ),
                  child: IntrinsicHeight(
                    child: Padding(
                      padding: EdgeInsets.only(
                        left: horizontalPadding,
                        right: horizontalPadding,
                        bottom: keyboardOpen ? 16 : 24,
                      ),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: maxContentWidth),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                height: keyboardOpen
                                    ? 0
                                    : (compact ? 84.0 : 104.0),
                                child: keyboardOpen
                                    ? const SizedBox.shrink()
                                    : AuthHeroImage(
                                        maxWidthFactor: 0.42,
                                        heightFactor: 0.12,
                                        minHeight: 84,
                                        maxHeight: compact ? 96 : 112,
                                      ),
                              ),
                              SizedBox(height: keyboardOpen ? 6 : 8),
                              Text(
                                l10n.signupTitle,
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                softWrap: true,
                                style: const TextStyle(
                                  fontSize: 26,
                                  height: 1.18,
                                  letterSpacing: -0.3,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                l10n.signupSubtitle,
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                softWrap: true,
                                style: const TextStyle(
                                  fontSize: 14,
                                  height: 1.4,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Form(
                                key: _formKey,
                                child: Column(
                                  children: [
                                    FieldInput(
                                      controller: _name,
                                      hint: l10n.signupNameHint,
                                      icon: Icons.person_outline_rounded,
                                      keyboardType: TextInputType.name,
                                      textInputAction: TextInputAction.next,
                                      autofillHints: const [AutofillHints.name],
                                      validator: (v) => _required(v, 'name'),
                                    ),
                                    const SizedBox(height: 10),
                                    FieldInput(
                                      controller: _email,
                                      hint: l10n.signupEmailHint,
                                      icon: Icons.mail_outline_rounded,
                                      keyboardType: TextInputType.emailAddress,
                                      textInputAction: TextInputAction.next,
                                      autofillHints: const [
                                        AutofillHints.newUsername,
                                        AutofillHints.email,
                                      ],
                                      validator: _emailCheck,
                                    ),
                                    const SizedBox(height: 10),
                                    FieldInput(
                                      controller: _phone,
                                      hint: l10n.signupPhoneHint,
                                      icon: Icons.phone_outlined,
                                      keyboardType: TextInputType.phone,
                                      textInputAction: TextInputAction.next,
                                      autofillHints: const [AutofillHints.telephoneNumber],
                                      validator: _phoneCheck,
                                    ),
                                    const SizedBox(height: 10),
                                    FieldInput(
                                      controller: _password,
                                      hint: l10n.signupPasswordHint,
                                      icon: Icons.lock_outline_rounded,
                                      obscure: _obscurePwd,
                                      textInputAction: TextInputAction.next,
                                      autofillHints: const [AutofillHints.newPassword],
                                      validator: _passwordCheck,
                                      suffixIcon: PasswordToggleSuffix(
                                        visible: _obscurePwd,
                                        onTap: () => setState(
                                            () => _obscurePwd = !_obscurePwd),
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    FieldInput(
                                      controller: _confirm,
                                      hint: l10n.signupConfirmHint,
                                      icon: Icons.lock_outline_rounded,
                                      obscure: _obscureConfirm,
                                      textInputAction: TextInputAction.done,
                                      onSubmitted: (_) => _submit(),
                                      validator: _confirmCheck,
                                      suffixIcon: PasswordToggleSuffix(
                                        visible: _obscureConfirm,
                                        onTap: () => setState(() =>
                                            _obscureConfirm = !_obscureConfirm),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: Checkbox(
                                      value: _agreed,
                                      visualDensity: VisualDensity.compact,
                                      materialTapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                      onChanged: _loading
                                          ? null
                                          : (v) => setState(
                                              () => _agreed = v ?? false),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      '${l10n.signupAgreePrefix}${l10n.signupAgreePrivacy}${l10n.signupAgreeAnd}${l10n.signupAgreeTerms}${l10n.signupAgreeSuffix}',
                                      maxLines: 2,
                                      softWrap: true,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: AppColors.textSecondary,
                                        height: 1.35,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (_errorCode != null) ...[
                                const SizedBox(height: 10),
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
                              PrimaryButton(
                                label: l10n.signupButton,
                                loading: _loading,
                                height: 50,
                                onPressed: _submit,
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    l10n.signupHaveAccount,
                                    style: const TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: widget.onLogin,
                                    behavior: HitTestBehavior.opaque,
                                    child: Text(
                                      l10n.signupLogIn,
                                      style: const TextStyle(
                                        color: AppColors.textPrimary,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13.5,
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
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
