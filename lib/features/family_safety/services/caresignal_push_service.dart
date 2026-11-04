import 'dart:async';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'caresignal_api.dart';

class CareSignalPushService {
  CareSignalPushService({required this.auth, required this.onRequestTap});

  final FirebaseAuth auth;
  final Future<void> Function(String requestId) onRequestTap;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<String>? _tokenSubscription;
  StreamSubscription<RemoteMessage>? _foregroundSubscription;
  StreamSubscription<RemoteMessage>? _openedSubscription;
  final Map<String, Future<void>> _registrationAttempts =
      <String, Future<void>>{};
  String? _registeredToken;
  String? _registeredUid;
  String? _pendingRequestId;
  bool _notificationsAllowed = false;

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'care_signal_requests',
    'CareSignal help requests',
    description: 'Incoming family CareSignal help requests',
    importance: Importance.high,
  );

  Future<void> initialize() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;

    await _localNotifications.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
      onDidReceiveNotificationResponse: (response) {
        final requestId = response.payload;
        if (requestId != null && requestId.isNotEmpty) {
          unawaited(_openRequest(requestId));
        }
      },
    );
    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(_channel);

    _foregroundSubscription = FirebaseMessaging.onMessage.listen(
      _showForegroundNotification,
      onError: (Object error) {
        debugPrint(
          'CareSignal foreground notification error=${error.runtimeType}',
        );
      },
    );
    _openedSubscription = FirebaseMessaging.onMessageOpenedApp.listen(
      _handleMessageTap,
    );
    _tokenSubscription = FirebaseMessaging.instance.onTokenRefresh.listen(
      _registerToken,
      onError: (Object error) {
        debugPrint('CareSignal FCM token refresh error=${error.runtimeType}');
      },
    );
    final permission = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    if (permission.authorizationStatus == AuthorizationStatus.denied) {
      debugPrint('CareSignal notifications permission=denied');
      return;
    }
    _notificationsAllowed = true;
    _authSubscription = auth.authStateChanges().listen(_handleAuthChange);

    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      await _handleMessageTap(initialMessage);
    }
  }

  Future<void> unregisterCurrentToken() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    final user = auth.currentUser;
    if (user == null) return;
    final String? token;
    try {
      token = _registeredToken ?? await FirebaseMessaging.instance.getToken();
    } on FirebaseException catch (error) {
      debugPrint('CareSignal FCM token unregister error=${error.code}');
      return;
    }
    if (token == null || token.isEmpty) return;
    CareSignalApi? api;
    try {
      api = _createApi();
      await api.unregisterFcmToken(token);
      _registeredToken = null;
      _registeredUid = null;
      debugPrint('CareSignal FCM token outcome=unregistered');
    } on CareSignalException catch (error) {
      debugPrint('CareSignal FCM token unregister error=${error.code}');
    } on SocketException {
      debugPrint('CareSignal FCM token unregister error=backend_unreachable');
    } on TimeoutException {
      debugPrint('CareSignal FCM token unregister error=backend_timeout');
    } finally {
      api?.dispose();
    }
  }

  Future<void> _handleAuthChange(User? user) async {
    if (user == null) {
      _registeredUid = null;
      return;
    }
    if (!_notificationsAllowed) return;
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) await _registerToken(token);
    } on FirebaseException catch (error) {
      debugPrint('CareSignal FCM token registration error=${error.code}');
    }
    final pending = _pendingRequestId;
    if (pending != null) {
      _pendingRequestId = null;
      await onRequestTap(pending);
    }
  }

  Future<void> _registerToken(String token) async {
    final user = auth.currentUser;
    if (user == null || token.isEmpty || !_notificationsAllowed) {
      return;
    }
    if (_registeredUid == user.uid && _registeredToken == token) return;
    final key = '${user.uid}:$token';
    final existingAttempt = _registrationAttempts[key];
    if (existingAttempt != null) {
      await existingAttempt;
      return;
    }

    final attempt = _registerTokenForUser(user.uid, token);
    _registrationAttempts[key] = attempt;
    try {
      await attempt;
    } finally {
      _registrationAttempts.remove(key);
    }
  }

  Future<void> _registerTokenForUser(String uid, String token) async {
    if (auth.currentUser?.uid != uid) return;
    CareSignalApi? api;
    try {
      api = _createApi();
      await api.registerFcmToken(token);
      if (auth.currentUser?.uid == uid) {
        _registeredUid = uid;
        _registeredToken = token;
      }
      debugPrint('CareSignal FCM token outcome=registered');
    } on FirebaseAuthException catch (error) {
      debugPrint(
        'CareSignal FCM token registration endpoint=/fcm/register '
        'category=${error.code} authorization_present=false',
      );
    } on CareSignalException catch (error) {
      debugPrint('CareSignal FCM token registration error=${error.code}');
    } on SocketException {
      debugPrint('CareSignal FCM token registration error=backend_unreachable');
    } on TimeoutException {
      debugPrint('CareSignal FCM token registration error=backend_timeout');
    } finally {
      api?.dispose();
    }
  }

  Future<void> _showForegroundNotification(RemoteMessage message) async {
    final requestId = message.data['requestId']?.toString();
    if (message.data['type'] != 'help_request' ||
        requestId == null ||
        requestId.isEmpty) {
      return;
    }
    await _localNotifications.show(
      id: requestId.hashCode & 0x7fffffff,
      title: message.notification?.title ?? 'AmarGuard — Help Request',
      body:
          message.notification?.body ??
          'Open AmarGuard to view the help request.',
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'care_signal_requests',
          'CareSignal help requests',
          channelDescription: 'Incoming family CareSignal help requests',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      payload: requestId,
    );
  }

  Future<void> _handleMessageTap(RemoteMessage message) async {
    if (message.data['type'] != 'help_request') return;
    final requestId = message.data['requestId']?.toString();
    if (requestId == null || requestId.isEmpty) return;
    await _openRequest(requestId);
  }

  Future<void> _openRequest(String requestId) async {
    if (auth.currentUser == null) {
      _pendingRequestId = requestId;
      return;
    }
    await onRequestTap(requestId);
  }

  CareSignalApi _createApi() {
    return CareSignalApi(config: CareSignalConfig.resolve(), auth: auth);
  }

  Future<void> dispose() async {
    await _authSubscription?.cancel();
    await _tokenSubscription?.cancel();
    await _foregroundSubscription?.cancel();
    await _openedSubscription?.cancel();
  }
}
