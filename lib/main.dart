import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/locale/locale_controller.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'data/services/auth_service.dart';
import 'data/services/local_prefs.dart';
import 'data/services/user_service.dart';
import 'features/family_safety/family_safety_launcher.dart';
import 'features/family_safety/services/caresignal_push_service.dart';
import 'firebase_options.dart';
import 'l10n/generated/app_localizations.dart';

final GlobalKey<NavigatorState> _appNavigatorKey = GlobalKey<NavigatorState>();

@pragma('vm:entry-point')
Future<void> careSignalFirebaseBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

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
        home: FirebaseUnavailableScreen(message: initResult.message),
      ),
    );
    return;
  }

  FirebaseMessaging.onBackgroundMessage(careSignalFirebaseBackgroundHandler);
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
  late final CareSignalPushService _pushService = CareSignalPushService(
    auth: FirebaseAuth.instance,
    onRequestTap: _queueIncomingRequest,
  );
  String? _pendingRequestId;
  bool _openingRequest = false;

  @override
  void initState() {
    super.initState();
    widget.localeController.addListener(_onLocaleChanged);
    unawaited(_initializePushService());
  }

  @override
  void dispose() {
    unawaited(_pushService.dispose());
    widget.localeController.removeListener(_onLocaleChanged);
    super.dispose();
  }

  Future<void> _initializePushService() async {
    try {
      await _pushService.initialize();
    } on FirebaseException catch (error) {
      debugPrint('CareSignal push initialization error=${error.code}');
    } on PlatformException catch (error) {
      debugPrint('CareSignal push initialization error=${error.code}');
    }
  }

  Future<void> _queueIncomingRequest(String requestId) async {
    _pendingRequestId = requestId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_openPendingRequest());
    });
  }

  Future<void> _openPendingRequest() async {
    final requestId = _pendingRequestId;
    final navigator = _appNavigatorKey.currentState;
    final context = _appNavigatorKey.currentContext;
    if (_openingRequest ||
        requestId == null ||
        navigator == null ||
        context == null ||
        FirebaseAuth.instance.currentUser == null) {
      return;
    }
    _pendingRequestId = null;
    _openingRequest = true;
    try {
      await FamilySafetyLauncher.openCareSignal(
        context,
        prefs: widget.prefs.preferences,
        auth: FirebaseAuth.instance,
        navigator: navigator,
        initialRequestId: requestId,
        onIncomingRequestRead: (openedRequestId) async {
          final uid = FirebaseAuth.instance.currentUser?.uid;
          if (uid == null) return;
          try {
            await widget.prefs.markCareSignalRequestRead(uid, openedRequestId);
          } catch (error) {
            debugPrint(
              'CareSignal local read marker error=${error.runtimeType}',
            );
          }
        },
      );
    } finally {
      _openingRequest = false;
    }
  }

  void _onLocaleChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final locale = widget.localeController.locale;
    return MaterialApp(
      navigatorKey: _appNavigatorKey,
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
        beforeSignOut: _pushService.unregisterCurrentToken,
      ),
    );
  }
}
