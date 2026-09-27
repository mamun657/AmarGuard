import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_bn.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('bn'),
    Locale('en'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'AmarGuard'**
  String get appTitle;

  /// Brand tagline displayed in caps
  ///
  /// In en, this message translates to:
  /// **'UNDERSTAND BEFORE YOU TRUST.'**
  String get brandTagline;

  /// No description provided for @splashCredit.
  ///
  /// In en, this message translates to:
  /// **'by BinaryPulse'**
  String get splashCredit;

  /// Onboarding page 1 title
  ///
  /// In en, this message translates to:
  /// **'Stay safer in every\ndigital interaction.'**
  String get onboardingTitle1;

  /// Onboarding page 1 subtitle
  ///
  /// In en, this message translates to:
  /// **'Detect, understand and respond to risky\ncalls, messages, links and screenshots.'**
  String get onboardingSubtitle1;

  /// Onboarding page 2 title
  ///
  /// In en, this message translates to:
  /// **'Scams don\'t always\nstart with a link.'**
  String get onboardingTitle2;

  /// Onboarding page 2 subtitle
  ///
  /// In en, this message translates to:
  /// **'Sometimes, they start with\na conversation.'**
  String get onboardingSubtitle2;

  /// Onboarding page 3 title
  ///
  /// In en, this message translates to:
  /// **'Know why something\nfeels risky.'**
  String get onboardingTitle3;

  /// Onboarding page 3 subtitle
  ///
  /// In en, this message translates to:
  /// **'AI analyzes the whole interaction\nand explains the risk.'**
  String get onboardingSubtitle3;

  /// No description provided for @onboardingNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get onboardingNext;

  /// No description provided for @onboardingSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get onboardingSkip;

  /// No description provided for @onboardingGetStarted.
  ///
  /// In en, this message translates to:
  /// **'Get Started'**
  String get onboardingGetStarted;

  /// Sample scam chat bubble 1
  ///
  /// In en, this message translates to:
  /// **'You\'ve been selected\nfor a special offer!'**
  String get scamBubble1;

  /// No description provided for @scamBubble2.
  ///
  /// In en, this message translates to:
  /// **'Pay now to confirm.'**
  String get scamBubble2;

  /// No description provided for @scamBubble3.
  ///
  /// In en, this message translates to:
  /// **'Don\'t tell anyone.'**
  String get scamBubble3;

  /// No description provided for @scamBubble4.
  ///
  /// In en, this message translates to:
  /// **'Share your OTP.'**
  String get scamBubble4;

  /// No description provided for @pipelineStep1Title.
  ///
  /// In en, this message translates to:
  /// **'Conversation'**
  String get pipelineStep1Title;

  /// No description provided for @pipelineStep1Subtitle.
  ///
  /// In en, this message translates to:
  /// **'Voice to Text'**
  String get pipelineStep1Subtitle;

  /// No description provided for @pipelineStep2Title.
  ///
  /// In en, this message translates to:
  /// **'Context Analysis'**
  String get pipelineStep2Title;

  /// No description provided for @pipelineStep2Subtitle.
  ///
  /// In en, this message translates to:
  /// **'Find risk signals'**
  String get pipelineStep2Subtitle;

  /// No description provided for @pipelineStep3Title.
  ///
  /// In en, this message translates to:
  /// **'AI Risk Detection'**
  String get pipelineStep3Title;

  /// No description provided for @pipelineStep3Subtitle.
  ///
  /// In en, this message translates to:
  /// **'XGBoost + SHAP'**
  String get pipelineStep3Subtitle;

  /// No description provided for @pipelineStep4Title.
  ///
  /// In en, this message translates to:
  /// **'Clear Explanation'**
  String get pipelineStep4Title;

  /// No description provided for @pipelineStep4Subtitle.
  ///
  /// In en, this message translates to:
  /// **'Why is it risky?'**
  String get pipelineStep4Subtitle;

  /// No description provided for @loginWelcome.
  ///
  /// In en, this message translates to:
  /// **'Welcome Back'**
  String get loginWelcome;

  /// No description provided for @loginSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Log in to keep a safer digital life.'**
  String get loginSubtitle;

  /// No description provided for @loginEmailHint.
  ///
  /// In en, this message translates to:
  /// **'Email Address'**
  String get loginEmailHint;

  /// No description provided for @loginPasswordHint.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get loginPasswordHint;

  /// No description provided for @loginKeepMe.
  ///
  /// In en, this message translates to:
  /// **'Keep me signed in'**
  String get loginKeepMe;

  /// No description provided for @loginForgot.
  ///
  /// In en, this message translates to:
  /// **'Forgot Password?'**
  String get loginForgot;

  /// No description provided for @loginButton.
  ///
  /// In en, this message translates to:
  /// **'Log In'**
  String get loginButton;

  /// No description provided for @loginContinueAs.
  ///
  /// In en, this message translates to:
  /// **'or continue as'**
  String get loginContinueAs;

  /// No description provided for @loginGuest.
  ///
  /// In en, this message translates to:
  /// **'Continue as Guest'**
  String get loginGuest;

  /// No description provided for @loginNoAccount.
  ///
  /// In en, this message translates to:
  /// **'Don\'t have an account? '**
  String get loginNoAccount;

  /// No description provided for @loginSignUp.
  ///
  /// In en, this message translates to:
  /// **'Sign Up'**
  String get loginSignUp;

  /// No description provided for @signupTitle.
  ///
  /// In en, this message translates to:
  /// **'Create Your\nSafety Account'**
  String get signupTitle;

  /// No description provided for @signupSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Join AmarGuard and stay protected.'**
  String get signupSubtitle;

  /// No description provided for @signupNameHint.
  ///
  /// In en, this message translates to:
  /// **'Full Name'**
  String get signupNameHint;

  /// No description provided for @signupEmailHint.
  ///
  /// In en, this message translates to:
  /// **'Email Address'**
  String get signupEmailHint;

  /// No description provided for @signupPhoneHint.
  ///
  /// In en, this message translates to:
  /// **'Phone Number'**
  String get signupPhoneHint;

  /// No description provided for @signupPasswordHint.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get signupPasswordHint;

  /// No description provided for @signupConfirmHint.
  ///
  /// In en, this message translates to:
  /// **'Confirm Password'**
  String get signupConfirmHint;

  /// No description provided for @signupAgreePrefix.
  ///
  /// In en, this message translates to:
  /// **'I agree to the '**
  String get signupAgreePrefix;

  /// No description provided for @signupAgreePrivacy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get signupAgreePrivacy;

  /// No description provided for @signupAgreeAnd.
  ///
  /// In en, this message translates to:
  /// **' and '**
  String get signupAgreeAnd;

  /// No description provided for @signupAgreeTerms.
  ///
  /// In en, this message translates to:
  /// **'Terms.'**
  String get signupAgreeTerms;

  /// No description provided for @signupAgreeSuffix.
  ///
  /// In en, this message translates to:
  /// **''**
  String get signupAgreeSuffix;

  /// No description provided for @signupButton.
  ///
  /// In en, this message translates to:
  /// **'Create Account'**
  String get signupButton;

  /// No description provided for @signupHaveAccount.
  ///
  /// In en, this message translates to:
  /// **'Already have an account? '**
  String get signupHaveAccount;

  /// No description provided for @signupLogIn.
  ///
  /// In en, this message translates to:
  /// **'Log In'**
  String get signupLogIn;

  /// No description provided for @errorEmailRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter your email.'**
  String get errorEmailRequired;

  /// No description provided for @errorEmailInvalid.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid email address.'**
  String get errorEmailInvalid;

  /// No description provided for @errorPasswordRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter your password.'**
  String get errorPasswordRequired;

  /// No description provided for @errorPasswordShort.
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 6 characters.'**
  String get errorPasswordShort;

  /// No description provided for @errorNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter your full name.'**
  String get errorNameRequired;

  /// No description provided for @errorPhoneRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter your phone number.'**
  String get errorPhoneRequired;

  /// No description provided for @errorPhoneInvalid.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid phone number.'**
  String get errorPhoneInvalid;

  /// No description provided for @errorConfirmRequired.
  ///
  /// In en, this message translates to:
  /// **'Please confirm your password.'**
  String get errorConfirmRequired;

  /// No description provided for @errorConfirmMismatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match.'**
  String get errorConfirmMismatch;

  /// No description provided for @errorAgreeTerms.
  ///
  /// In en, this message translates to:
  /// **'Please agree to the Terms to continue.'**
  String get errorAgreeTerms;

  /// No description provided for @errorGeneric.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get errorGeneric;

  /// No description provided for @errorInvalidCredentials.
  ///
  /// In en, this message translates to:
  /// **'Email or password is incorrect.'**
  String get errorInvalidCredentials;

  /// No description provided for @errorAccountDisabled.
  ///
  /// In en, this message translates to:
  /// **'This account has been disabled.'**
  String get errorAccountDisabled;

  /// No description provided for @errorTooManyAttempts.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Please try again later.'**
  String get errorTooManyAttempts;

  /// No description provided for @errorNoInternet.
  ///
  /// In en, this message translates to:
  /// **'Please check your internet connection and try again.'**
  String get errorNoInternet;

  /// No description provided for @errorAccountExists.
  ///
  /// In en, this message translates to:
  /// **'An account with this email already exists.'**
  String get errorAccountExists;

  /// No description provided for @errorWeakPassword.
  ///
  /// In en, this message translates to:
  /// **'Please choose a stronger password.'**
  String get errorWeakPassword;

  /// No description provided for @errorSignupUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Account creation is currently unavailable.'**
  String get errorSignupUnavailable;

  /// No description provided for @greetingMorning.
  ///
  /// In en, this message translates to:
  /// **'Good morning,'**
  String get greetingMorning;

  /// No description provided for @greetingAfternoon.
  ///
  /// In en, this message translates to:
  /// **'Good afternoon,'**
  String get greetingAfternoon;

  /// No description provided for @greetingEvening.
  ///
  /// In en, this message translates to:
  /// **'Good evening,'**
  String get greetingEvening;

  /// No description provided for @safetyActive.
  ///
  /// In en, this message translates to:
  /// **'Your digital safety is active.'**
  String get safetyActive;

  /// No description provided for @protectedTitle.
  ///
  /// In en, this message translates to:
  /// **'You\'re Protected'**
  String get protectedTitle;

  /// No description provided for @protectedBody.
  ///
  /// In en, this message translates to:
  /// **'AmarGuard is ready to help you check suspicious interactions.'**
  String get protectedBody;

  /// No description provided for @quickActions.
  ///
  /// In en, this message translates to:
  /// **'Quick Actions'**
  String get quickActions;

  /// No description provided for @seeAll.
  ///
  /// In en, this message translates to:
  /// **'See All'**
  String get seeAll;

  /// No description provided for @serviceAnalyzeCallTitle.
  ///
  /// In en, this message translates to:
  /// **'Analyze Call'**
  String get serviceAnalyzeCallTitle;

  /// No description provided for @serviceAnalyzeCallDesc.
  ///
  /// In en, this message translates to:
  /// **'Detect scam & fraud'**
  String get serviceAnalyzeCallDesc;

  /// No description provided for @serviceCheckMessageTitle.
  ///
  /// In en, this message translates to:
  /// **'Check Message'**
  String get serviceCheckMessageTitle;

  /// No description provided for @serviceCheckMessageDesc.
  ///
  /// In en, this message translates to:
  /// **'Scan suspicious text'**
  String get serviceCheckMessageDesc;

  /// No description provided for @serviceCheckLinkTitle.
  ///
  /// In en, this message translates to:
  /// **'Check Link'**
  String get serviceCheckLinkTitle;

  /// No description provided for @serviceCheckLinkDesc.
  ///
  /// In en, this message translates to:
  /// **'Find unsafe websites'**
  String get serviceCheckLinkDesc;

  /// No description provided for @serviceScanScreenshotTitle.
  ///
  /// In en, this message translates to:
  /// **'Scan Screenshot'**
  String get serviceScanScreenshotTitle;

  /// No description provided for @serviceScanScreenshotDesc.
  ///
  /// In en, this message translates to:
  /// **'Identify scams in images'**
  String get serviceScanScreenshotDesc;

  /// No description provided for @serviceAnalyzeAudioTitle.
  ///
  /// In en, this message translates to:
  /// **'Analyze Audio'**
  String get serviceAnalyzeAudioTitle;

  /// No description provided for @serviceAnalyzeAudioDesc.
  ///
  /// In en, this message translates to:
  /// **'Detect voice scams'**
  String get serviceAnalyzeAudioDesc;

  /// No description provided for @serviceFamilySafetyTitle.
  ///
  /// In en, this message translates to:
  /// **'Family Safety'**
  String get serviceFamilySafetyTitle;

  /// No description provided for @serviceFamilySafetyDesc.
  ///
  /// In en, this message translates to:
  /// **'Trusted contacts & safety'**
  String get serviceFamilySafetyDesc;

  /// No description provided for @stayAlertTitle.
  ///
  /// In en, this message translates to:
  /// **'Stay Alert!'**
  String get stayAlertTitle;

  /// No description provided for @stayAlertBody.
  ///
  /// In en, this message translates to:
  /// **'Scams can happen in calls, messages, links and more.'**
  String get stayAlertBody;

  /// No description provided for @recentActivity.
  ///
  /// In en, this message translates to:
  /// **'Recent Activity'**
  String get recentActivity;

  /// No description provided for @riskHigh.
  ///
  /// In en, this message translates to:
  /// **'High Risk'**
  String get riskHigh;

  /// No description provided for @riskMedium.
  ///
  /// In en, this message translates to:
  /// **'Medium Risk'**
  String get riskMedium;

  /// No description provided for @riskLow.
  ///
  /// In en, this message translates to:
  /// **'Low Risk'**
  String get riskLow;

  /// No description provided for @activityCallTitle.
  ///
  /// In en, this message translates to:
  /// **'Unknown Call'**
  String get activityCallTitle;

  /// No description provided for @activityScreenshotTitle.
  ///
  /// In en, this message translates to:
  /// **'Screenshot Analysis'**
  String get activityScreenshotTitle;

  /// No description provided for @activityLinkTitle.
  ///
  /// In en, this message translates to:
  /// **'Suspicious Link'**
  String get activityLinkTitle;

  /// No description provided for @navHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// No description provided for @navProtect.
  ///
  /// In en, this message translates to:
  /// **'Protect'**
  String get navProtect;

  /// No description provided for @navAnalyze.
  ///
  /// In en, this message translates to:
  /// **'Analyze'**
  String get navAnalyze;

  /// No description provided for @navHistory.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get navHistory;

  /// No description provided for @navProfile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get navProfile;

  /// No description provided for @protectTitle.
  ///
  /// In en, this message translates to:
  /// **'Protect'**
  String get protectTitle;

  /// No description provided for @protectTagline.
  ///
  /// In en, this message translates to:
  /// **'Manage how AmarGuard keeps you safe across every interaction.'**
  String get protectTagline;

  /// No description provided for @analyzeTitle.
  ///
  /// In en, this message translates to:
  /// **'Analyze'**
  String get analyzeTitle;

  /// No description provided for @analyzeTagline.
  ///
  /// In en, this message translates to:
  /// **'Run a quick safety check on any call, message, link or file.'**
  String get analyzeTagline;

  /// No description provided for @historyTitle.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get historyTitle;

  /// No description provided for @historyTagline.
  ///
  /// In en, this message translates to:
  /// **'Review the analyses you have run and what AmarGuard found.'**
  String get historyTagline;

  /// No description provided for @profileTitle.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profileTitle;

  /// No description provided for @profileTagline.
  ///
  /// In en, this message translates to:
  /// **'Your account and AmarGuard preferences.'**
  String get profileTagline;

  /// No description provided for @profileGuestBadge.
  ///
  /// In en, this message translates to:
  /// **'Browsing as guest'**
  String get profileGuestBadge;

  /// No description provided for @profileActiveProtection.
  ///
  /// In en, this message translates to:
  /// **'Active Protection'**
  String get profileActiveProtection;

  /// No description provided for @profileActiveProtectionGuest.
  ///
  /// In en, this message translates to:
  /// **'Limited in guest mode'**
  String get profileActiveProtectionGuest;

  /// No description provided for @profileActiveProtectionUser.
  ///
  /// In en, this message translates to:
  /// **'Enabled across your account'**
  String get profileActiveProtectionUser;

  /// No description provided for @profileActivityHistory.
  ///
  /// In en, this message translates to:
  /// **'Activity History'**
  String get profileActivityHistory;

  /// No description provided for @profileActivityHistorySubtitle.
  ///
  /// In en, this message translates to:
  /// **'View recent analysis results'**
  String get profileActivityHistorySubtitle;

  /// No description provided for @profileHelp.
  ///
  /// In en, this message translates to:
  /// **'Help & Support'**
  String get profileHelp;

  /// No description provided for @profileHelpSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Get answers about AmarGuard'**
  String get profileHelpSubtitle;

  /// No description provided for @profileSignOut.
  ///
  /// In en, this message translates to:
  /// **'Sign Out'**
  String get profileSignOut;

  /// No description provided for @profileSignedOut.
  ///
  /// In en, this message translates to:
  /// **'Signed out'**
  String get profileSignedOut;

  /// No description provided for @settingsLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguage;

  /// No description provided for @settingsLanguageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get settingsLanguageEnglish;

  /// No description provided for @settingsLanguageBangla.
  ///
  /// In en, this message translates to:
  /// **'বাংলা'**
  String get settingsLanguageBangla;

  /// No description provided for @settingsLanguageSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose your preferred app language'**
  String get settingsLanguageSubtitle;

  /// No description provided for @placeholderSoonTitle.
  ///
  /// In en, this message translates to:
  /// **'Coming together soon'**
  String get placeholderSoonTitle;

  /// No description provided for @placeholderSoonBody.
  ///
  /// In en, this message translates to:
  /// **'This section is part of the AmarGuard roadmap and will be enabled once the next release is ready.'**
  String get placeholderSoonBody;

  /// No description provided for @placeholderNotifyTitle.
  ///
  /// In en, this message translates to:
  /// **'We\'ll let you know'**
  String get placeholderNotifyTitle;

  /// No description provided for @placeholderNotifyBody.
  ///
  /// In en, this message translates to:
  /// **'You will see updates here as soon as new protection features become available for your account.'**
  String get placeholderNotifyBody;

  /// No description provided for @maintenanceTitle.
  ///
  /// In en, this message translates to:
  /// **'System Maintenance'**
  String get maintenanceTitle;

  /// No description provided for @maintenanceBody.
  ///
  /// In en, this message translates to:
  /// **'{service} is temporarily unavailable while we complete system maintenance. Please try again later.'**
  String maintenanceBody(String service);

  /// No description provided for @maintenancePreparing.
  ///
  /// In en, this message translates to:
  /// **'We\'re preparing this feature for a future release.'**
  String get maintenancePreparing;

  /// No description provided for @maintenanceGotIt.
  ///
  /// In en, this message translates to:
  /// **'Got it'**
  String get maintenanceGotIt;

  /// No description provided for @snackMenuTitle.
  ///
  /// In en, this message translates to:
  /// **'Menu'**
  String get snackMenuTitle;

  /// No description provided for @snackMenuBody.
  ///
  /// In en, this message translates to:
  /// **'The side menu is being prepared for the next AmarGuard release.'**
  String get snackMenuBody;

  /// No description provided for @snackNotificationsTitle.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get snackNotificationsTitle;

  /// No description provided for @snackNotificationsBody.
  ///
  /// In en, this message translates to:
  /// **'You have no new safety alerts right now.'**
  String get snackNotificationsBody;

  /// No description provided for @firebaseUnavailableTitle.
  ///
  /// In en, this message translates to:
  /// **'Firebase unavailable'**
  String get firebaseUnavailableTitle;

  /// No description provided for @firebaseUnavailableFallback.
  ///
  /// In en, this message translates to:
  /// **'AmarGuard could not start. Please try again.'**
  String get firebaseUnavailableFallback;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['bn', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'bn':
      return AppLocalizationsBn();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
