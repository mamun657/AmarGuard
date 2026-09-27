import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../data/services/auth_service.dart';
import '../../data/services/local_prefs.dart';
import '../../data/services/user_service.dart';
import '../../features/auth/login_screen.dart';
import '../../features/auth/signup_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/onboarding/onboarding_screen.dart';
import '../../features/splash/splash_screen.dart';
import '../../l10n/generated/app_localizations.dart';
import '../locale/locale_controller.dart';

enum AppRoute { splash, onboarding, login, signup, home }

class AppRouter extends StatefulWidget {
  const AppRouter({
    super.key,
    required this.authService,
    required this.userService,
    required this.prefs,
    required this.localeController,
  });

  final AuthService authService;
  final UserService userService;
  final LocalPrefs prefs;
  final LocaleController localeController;

  @override
  State<AppRouter> createState() => _AppRouterState();
}

class _AppRouterState extends State<AppRouter> {
  AppRoute _route = AppRoute.splash;
  bool _splashComplete = false;

  @override
  void initState() {
    super.initState();
    _scheduleSplashTransition();
    widget.authService.authStateChanges().listen((user) {
      if (!mounted || !_splashComplete) return;
      if (user != null) {
        _go(AppRoute.home);
      } else if (widget.prefs.hasCompletedOnboarding && _route != AppRoute.login) {
        _go(AppRoute.login);
      }
    });
  }

  void _scheduleSplashTransition() {
    Future.delayed(const Duration(milliseconds: 2500), () {
      if (!mounted) return;
      _splashComplete = true;
      _resolveRoute();
    });
  }

  void _resolveRoute() {
    final user = widget.authService.currentUser;
    if (user != null) {
      _go(AppRoute.home);
      return;
    }
    if (widget.prefs.isGuest) {
      _go(AppRoute.home);
      return;
    }
    if (!widget.prefs.hasCompletedOnboarding) {
      _go(AppRoute.onboarding);
    } else {
      _go(AppRoute.login);
    }
  }

  void _go(AppRoute route) {
    if (!mounted) return;
    setState(() => _route = route);
  }

  Future<void> _enterGuest() async {
    await widget.prefs.setGuest(true);
    _go(AppRoute.home);
  }

  Future<void> _completeOnboarding() async {
    await widget.prefs.markOnboardingComplete();
    _go(AppRoute.login);
  }

  Future<void> _signOut() async {
    await widget.prefs.clearGuest();
    await widget.authService.signOut();
    _go(AppRoute.login);
  }

  Future<void> _handleEmailAuthSuccess() async {
    await widget.prefs.clearGuest();
    _go(AppRoute.home);
  }

  Future<void> _handleSignupSuccess() async {
    await widget.prefs.clearGuest();
    _go(AppRoute.home);
  }

  Widget _build(BuildContext context) {
    switch (_route) {
      case AppRoute.splash:
        return const SplashScreen();
      case AppRoute.onboarding:
        return OnboardingScreen(onComplete: _completeOnboarding);
      case AppRoute.login:
        return LoginScreen(
          authService: widget.authService,
          onAuthSuccess: _handleEmailAuthSuccess,
          onSignUp: () => _go(AppRoute.signup),
          onGuest: _enterGuest,
        );
      case AppRoute.signup:
        return SignupScreen(
          authService: widget.authService,
          userService: widget.userService,
          onAuthSuccess: _handleSignupSuccess,
          onLogin: () => _go(AppRoute.login),
        );
      case AppRoute.home:
        return HomeScreen(
          authService: widget.authService,
          prefs: widget.prefs,
          localeController: widget.localeController,
          onSignedOut: _signOut,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 320),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.02),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        );
      },
      child: KeyedSubtree(
        key: ValueKey(_route),
        child: _build(context),
      ),
    );
  }
}

class FirebaseInitializer {
  FirebaseInitializer._();

  static Future<({bool ok, String? message})> init(
    FirebaseOptions options,
  ) async {
    try {
      await Firebase.initializeApp(options: options);
      return (ok: true, message: null);
    } catch (e) {
      return (ok: false, message: e.toString());
    }
  }
}

class FirebaseUnavailableScreen extends StatelessWidget {
  const FirebaseUnavailableScreen({super.key, required this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final displayMessage = message ?? l10n.firebaseUnavailableFallback;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: AppColors.danger.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.warning_amber_rounded,
                    color: AppColors.danger,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  l10n.firebaseUnavailableTitle,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  displayMessage,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
