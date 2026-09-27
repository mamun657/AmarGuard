import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/locale/locale_controller.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'data/services/auth_service.dart';
import 'data/services/local_prefs.dart';
import 'data/services/user_service.dart';
import 'firebase_options.dart';
import 'l10n/generated/app_localizations.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Color(0xFFFFFBF4),
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  final initResult = await FirebaseInitializer.init(
    DefaultFirebaseOptions.currentPlatform,
  );

  if (!initResult.ok) {
    runApp(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: FirebaseUnavailableScreen(
          message: initResult.message,
        ),
      ),
    );
    return;
  }

  final prefs = await LocalPrefs.create();
  final authService = AuthService(FirebaseAuth.instance);
  final userService = UserService(
    FirebaseFirestore.instance,
    FirebaseAuth.instance,
  );
  final localeController = LocaleController(prefs);

  runApp(
    AmarguardApp(
      authService: authService,
      userService: userService,
      prefs: prefs,
      localeController: localeController,
    ),
  );
}

class AmarguardApp extends StatefulWidget {
  const AmarguardApp({
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
  State<AmarguardApp> createState() => _AmarguardAppState();
}

class _AmarguardAppState extends State<AmarguardApp> {
  @override
  void initState() {
    super.initState();
    widget.localeController.addListener(_onLocaleChanged);
  }

  @override
  void dispose() {
    widget.localeController.removeListener(_onLocaleChanged);
    super.dispose();
  }

  void _onLocaleChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final locale = widget.localeController.locale;
    return MaterialApp(
      title: 'AmarGuard',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(locale: locale),
      locale: locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: LocaleController.supported,
      home: AppRouter(
        authService: widget.authService,
        userService: widget.userService,
        prefs: widget.prefs,
        localeController: widget.localeController,
      ),
    );
  }
}
