// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'AmarGuard';

  @override
  String get brandTagline => 'UNDERSTAND BEFORE YOU TRUST.';

  @override
  String get splashCredit => 'by BinaryPulse';

  @override
  String get onboardingTitle1 => 'Stay safer in every\ndigital interaction.';

  @override
  String get onboardingSubtitle1 =>
      'Detect, understand and respond to risky\ncalls, messages, links and screenshots.';

  @override
  String get onboardingTitle2 => 'Scams don\'t always\nstart with a link.';

  @override
  String get onboardingSubtitle2 =>
      'Sometimes, they start with\na conversation.';

  @override
  String get onboardingTitle3 => 'Know why something\nfeels risky.';

  @override
  String get onboardingSubtitle3 =>
      'AI analyzes the whole interaction\nand explains the risk.';

  @override
  String get onboardingNext => 'Next';

  @override
  String get onboardingSkip => 'Skip';

  @override
  String get onboardingGetStarted => 'Get Started';

  @override
  String get scamBubble1 => 'You\'ve been selected\nfor a special offer!';

  @override
  String get scamBubble2 => 'Pay now to confirm.';

  @override
  String get scamBubble3 => 'Don\'t tell anyone.';

  @override
  String get scamBubble4 => 'Share your OTP.';

  @override
  String get pipelineStep1Title => 'Conversation';

  @override
  String get pipelineStep1Subtitle => 'Voice to Text';

  @override
  String get pipelineStep2Title => 'Context Analysis';

  @override
  String get pipelineStep2Subtitle => 'Find risk signals';

  @override
  String get pipelineStep3Title => 'AI Risk Detection';

  @override
  String get pipelineStep3Subtitle => 'XGBoost + SHAP';

  @override
  String get pipelineStep4Title => 'Clear Explanation';

  @override
  String get pipelineStep4Subtitle => 'Why is it risky?';

  @override
  String get loginWelcome => 'Welcome Back';

  @override
  String get loginSubtitle => 'Log in to keep a safer digital life.';

  @override
  String get loginEmailHint => 'Email Address';

  @override
  String get loginPasswordHint => 'Password';

  @override
  String get loginKeepMe => 'Keep me signed in';

  @override
  String get loginForgot => 'Forgot Password?';

  @override
  String get loginButton => 'Log In';

  @override
  String get loginContinueAs => 'or continue as';

  @override
  String get loginGuest => 'Continue as Guest';

  @override
  String get loginNoAccount => 'Don\'t have an account? ';

  @override
  String get loginSignUp => 'Sign Up';

  @override
  String get signupTitle => 'Create Your\nSafety Account';

  @override
  String get signupSubtitle => 'Join AmarGuard and stay protected.';

  @override
  String get signupNameHint => 'Full Name';

  @override
  String get signupEmailHint => 'Email Address';

  @override
  String get signupPhoneHint => 'Phone Number';

  @override
  String get signupPasswordHint => 'Password';

  @override
  String get signupConfirmHint => 'Confirm Password';

  @override
  String get signupAgreePrefix => 'I agree to the ';

  @override
  String get signupAgreePrivacy => 'Privacy Policy';

  @override
  String get signupAgreeAnd => ' and ';

  @override
  String get signupAgreeTerms => 'Terms.';

  @override
  String get signupAgreeSuffix => '';

  @override
  String get signupButton => 'Create Account';

  @override
  String get signupHaveAccount => 'Already have an account? ';

  @override
  String get signupLogIn => 'Log In';

  @override
  String get errorEmailRequired => 'Please enter your email.';

  @override
  String get errorEmailInvalid => 'Please enter a valid email address.';

  @override
  String get errorPasswordRequired => 'Please enter your password.';

  @override
  String get errorPasswordShort => 'Password must be at least 6 characters.';

  @override
  String get errorNameRequired => 'Please enter your full name.';

  @override
  String get errorPhoneRequired => 'Please enter your phone number.';

  @override
  String get errorPhoneInvalid => 'Please enter a valid phone number.';

  @override
  String get errorConfirmRequired => 'Please confirm your password.';

  @override
  String get errorConfirmMismatch => 'Passwords do not match.';

  @override
  String get errorAgreeTerms => 'Please agree to the Terms to continue.';

  @override
  String get errorGeneric => 'Something went wrong. Please try again.';

  @override
  String get errorInvalidCredentials => 'Email or password is incorrect.';

  @override
  String get errorAccountDisabled => 'This account has been disabled.';

  @override
  String get errorTooManyAttempts =>
      'Too many attempts. Please try again later.';

  @override
  String get errorNoInternet =>
      'Please check your internet connection and try again.';

  @override
  String get errorAccountExists => 'An account with this email already exists.';

  @override
  String get errorWeakPassword => 'Please choose a stronger password.';

  @override
  String get errorSignupUnavailable =>
      'Account creation is currently unavailable.';

  @override
  String get greetingMorning => 'Good morning,';

  @override
  String get greetingAfternoon => 'Good afternoon,';

  @override
  String get greetingEvening => 'Good evening,';

  @override
  String get safetyActive => 'Your digital safety is active.';

  @override
  String get protectedTitle => 'You\'re Protected';

  @override
  String get protectedBody =>
      'AmarGuard is ready to help you check suspicious interactions.';

  @override
  String get quickActions => 'Quick Actions';

  @override
  String get seeAll => 'See All';

  @override
  String get serviceAnalyzeCallTitle => 'Analyze Call';

  @override
  String get serviceAnalyzeCallDesc => 'Detect scam & fraud';

  @override
  String get serviceCheckMessageTitle => 'Check Message';

  @override
  String get serviceCheckMessageDesc => 'Scan suspicious text';

  @override
  String get serviceCheckLinkTitle => 'Check Link';

  @override
  String get serviceCheckLinkDesc => 'Find unsafe websites';

  @override
  String get serviceScanScreenshotTitle => 'Scan Screenshot';

  @override
  String get serviceScanScreenshotDesc => 'Identify scams in images';

  @override
  String get serviceAnalyzeAudioTitle => 'Analyze Audio';

  @override
  String get serviceAnalyzeAudioDesc => 'Detect voice scams';

  @override
  String get serviceFamilySafetyTitle => 'Family Safety';

  @override
  String get serviceFamilySafetyDesc => 'Trusted contacts & safety';

  @override
  String get stayAlertTitle => 'Stay Alert!';

  @override
  String get stayAlertBody =>
      'Scams can happen in calls, messages, links and more.';

  @override
  String get recentActivity => 'Recent Activity';

  @override
  String get riskHigh => 'High Risk';

  @override
  String get riskMedium => 'Medium Risk';

  @override
  String get riskLow => 'Low Risk';

  @override
  String get activityCallTitle => 'Unknown Call';

  @override
  String get activityScreenshotTitle => 'Screenshot Analysis';

  @override
  String get activityLinkTitle => 'Suspicious Link';

  @override
  String get navHome => 'Home';

  @override
  String get navProtect => 'Protect';

  @override
  String get navAnalyze => 'Analyze';

  @override
  String get navHistory => 'History';

  @override
  String get navProfile => 'Profile';

  @override
  String get protectTitle => 'Protect';

  @override
  String get protectTagline =>
      'Manage how AmarGuard keeps you safe across every interaction.';

  @override
  String get analyzeTitle => 'Analyze';

  @override
  String get analyzeTagline =>
      'Run a quick safety check on any call, message, link or file.';

  @override
  String get historyTitle => 'History';

  @override
  String get historyTagline =>
      'Review the analyses you have run and what AmarGuard found.';

  @override
  String get profileTitle => 'Profile';

  @override
  String get profileTagline => 'Your account and AmarGuard preferences.';

  @override
  String get profileGuestBadge => 'Browsing as guest';

  @override
  String get profileActiveProtection => 'Active Protection';

  @override
  String get profileActiveProtectionGuest => 'Limited in guest mode';

  @override
  String get profileActiveProtectionUser => 'Enabled across your account';

  @override
  String get profileActivityHistory => 'Activity History';

  @override
  String get profileActivityHistorySubtitle => 'View recent analysis results';

  @override
  String get profileHelp => 'Help & Support';

  @override
  String get profileHelpSubtitle => 'Get answers about AmarGuard';

  @override
  String get profileSignOut => 'Sign Out';

  @override
  String get profileSignedOut => 'Signed out';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get settingsLanguageEnglish => 'English';

  @override
  String get settingsLanguageBangla => 'বাংলা';

  @override
  String get settingsLanguageSubtitle => 'Choose your preferred app language';

  @override
  String get placeholderSoonTitle => 'Coming together soon';

  @override
  String get placeholderSoonBody =>
      'This section is part of the AmarGuard roadmap and will be enabled once the next release is ready.';

  @override
  String get placeholderNotifyTitle => 'We\'ll let you know';

  @override
  String get placeholderNotifyBody =>
      'You will see updates here as soon as new protection features become available for your account.';

  @override
  String get maintenanceTitle => 'System Maintenance';

  @override
  String maintenanceBody(String service) {
    return '$service is temporarily unavailable while we complete system maintenance. Please try again later.';
  }

  @override
  String get maintenancePreparing =>
      'We\'re preparing this feature for a future release.';

  @override
  String get maintenanceGotIt => 'Got it';

  @override
  String get snackMenuTitle => 'Menu';

  @override
  String get snackMenuBody =>
      'The side menu is being prepared for the next AmarGuard release.';

  @override
  String get snackNotificationsTitle => 'Notifications';

  @override
  String get snackNotificationsBody =>
      'You have no new safety alerts right now.';

  @override
  String get firebaseUnavailableTitle => 'Firebase unavailable';

  @override
  String get firebaseUnavailableFallback =>
      'AmarGuard could not start. Please try again.';
}
