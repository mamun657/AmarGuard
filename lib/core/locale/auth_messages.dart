import '../../data/services/auth_service.dart';
import '../../l10n/generated/app_localizations.dart';

class AuthMessages {
  AuthMessages._();

  static String forCode(AppLocalizations l10n, AuthErrorCode code) {
    switch (code) {
      case AuthErrorCode.invalidEmail:
        return l10n.errorEmailInvalid;
      case AuthErrorCode.invalidCredentials:
        return l10n.errorInvalidCredentials;
      case AuthErrorCode.accountDisabled:
        return l10n.errorAccountDisabled;
      case AuthErrorCode.tooManyAttempts:
        return l10n.errorTooManyAttempts;
      case AuthErrorCode.network:
        return l10n.errorNoInternet;
      case AuthErrorCode.accountExists:
        return l10n.errorAccountExists;
      case AuthErrorCode.weakPassword:
        return l10n.errorWeakPassword;
      case AuthErrorCode.signupUnavailable:
        return l10n.errorSignupUnavailable;
      case AuthErrorCode.generic:
        return l10n.errorGeneric;
    }
  }
}
