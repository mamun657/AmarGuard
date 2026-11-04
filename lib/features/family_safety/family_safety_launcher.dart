import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/services/local_prefs.dart';
import 'controllers/caresignal_controller.dart';
import 'controllers/family_safety_controller.dart';
import 'screens/family_safety_screen.dart';
import 'screens/caresignal_home_screen.dart';
import 'screens/caresignal_response_screen.dart';
import 'screens/family_invitation_screen.dart';
import '../silent_speak/screens/silent_speak_mode_selection_screen.dart';
import 'services/battery_service.dart';
import 'services/caresignal_api.dart';
import 'services/caresignal_recorder.dart';
import 'services/device_identity_service.dart';
import 'services/family_repository.dart';
import 'services/location_provider.dart';
import 'services/location_sync_service.dart';
import 'services/sharing_service_bridge.dart';
import 'screens/safety_inbox_screen.dart';

class FamilySafetyLauncher {
  FamilySafetyLauncher._();

  static Future<void> open(
    BuildContext context, {
    required bool isGuest,
    required SharedPreferences prefs,
    required FirebaseAuth auth,
    required FirebaseFirestore firestore,
  }) async {
    final controller = await _buildFamilySafetyController(
      prefs: prefs,
      auth: auth,
      firestore: firestore,
    );
    if (!context.mounted) {
      _disposeFamilySafetyController(controller);
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            FamilySafetyScreen(controller: controller, isGuest: isGuest),
      ),
    );
    _disposeFamilySafetyController(controller);
  }

  static Future<void> openSafetyInbox(
    BuildContext context, {
    required SharedPreferences prefs,
    required FirebaseAuth auth,
    required FirebaseFirestore firestore,
    required LocalPrefs localPrefs,
  }) async {
    final user = auth.currentUser;
    if (user == null) return;

    final identityService = DeviceIdentityService(prefs);
    final deviceId = await identityService.ensureDeviceId();
    final careSignalController = await _buildCareSignalController(
      auth: auth,
      identityService: identityService,
      languageCode: prefs.getString('language_code') ?? 'en',
    );
    if (!context.mounted || auth.currentUser?.uid != user.uid) {
      careSignalController.dispose();
      return;
    }

    final familyRepository = FamilyRepository(firestore, auth);
    try {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => SafetyInboxScreen(
            currentUserUid: user.uid,
            readCareRequestIds: localPrefs
                .readCareSignalRequestIds(user.uid)
                .toSet(),
            loadCareRequests: () async {
              final requests = await careSignalController.loadInbox();
              if (careSignalController.inboxRequestsErrorCode != null) {
                throw CareSignalException(
                  careSignalController.inboxRequestsErrorCode!,
                  careSignalController.errorMessage ??
                      'CareSignal inbox is unavailable.',
                );
              }
              return requests;
            },
            loadFamilyRequests: () => familyRepository.loadIncomingRequests(
              deviceId: deviceId,
              source: 'safety_inbox',
            ),
            markCareRequestRead: (requestId) =>
                localPrefs.markCareSignalRequestRead(user.uid, requestId),
            openCareRequest: (request) async {
              if (auth.currentUser?.uid != user.uid ||
                  request.recipientUid != user.uid) {
                return;
              }
              await Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => CareSignalResponseScreen(
                    controller: careSignalController,
                    request: request,
                  ),
                ),
              );
            },
            openFamilyRequest: (request) {
              if (auth.currentUser?.uid != user.uid ||
                  request.ownerUid != user.uid) {
                return Future<void>.value();
              }
              return openFamilyRequests(
                context,
                prefs: prefs,
                auth: auth,
                firestore: firestore,
              );
            },
          ),
        ),
      );
    } finally {
      careSignalController.dispose();
    }
  }

  static Future<void> openFamilyRequests(
    BuildContext context, {
    required SharedPreferences prefs,
    required FirebaseAuth auth,
    required FirebaseFirestore firestore,
  }) async {
    final user = auth.currentUser;
    if (user == null) return;
    final controller = await _buildFamilySafetyController(
      prefs: prefs,
      auth: auth,
      firestore: firestore,
    );
    try {
      await controller.initialize(isGuest: false);
      if (!context.mounted || auth.currentUser?.uid != user.uid) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => FamilyInvitationScreen(controller: controller),
        ),
      );
    } finally {
      _disposeFamilySafetyController(controller);
    }
  }

  static Future<void> openCareSignal(
    BuildContext context, {
    required SharedPreferences prefs,
    required FirebaseAuth auth,
    NavigatorState? navigator,
    String? initialRequestId,
    Future<void> Function(String requestId)? onIncomingRequestRead,
  }) async {
    final identityService = DeviceIdentityService(prefs);
    final controller = await _buildCareSignalController(
      auth: auth,
      identityService: identityService,
      languageCode: prefs.getString('language_code') ?? 'en',
    );
    if (!context.mounted) {
      controller.dispose();
      return;
    }
    final routeNavigator = navigator ?? Navigator.of(context);
    await routeNavigator.push(
      MaterialPageRoute<void>(
        builder: (_) => CareSignalHomeScreen(
          controller: controller,
          onBack: routeNavigator.pop,
          initialRequestId: initialRequestId,
          onIncomingRequestRead: onIncomingRequestRead,
        ),
      ),
    );
    controller.dispose();
  }

  static Future<void> openSilentSpeak(
    BuildContext context, {
    required SharedPreferences prefs,
    required FirebaseAuth auth,
  }) async {
    final identityService = DeviceIdentityService(prefs);
    final controller = await _buildCareSignalController(
      auth: auth,
      identityService: identityService,
      languageCode: prefs.getString('language_code') ?? 'en',
    );
    if (!context.mounted) {
      controller.dispose();
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SilentSpeakModeSelectionScreen(
          prefs: prefs,
          controller: controller,
        ),
      ),
    );
    controller.dispose();
  }

  static Future<CareSignalController> _buildCareSignalController({
    required FirebaseAuth auth,
    required DeviceIdentityService identityService,
    required String languageCode,
  }) async {
    final deviceId = await identityService.ensureDeviceId();
    final resolvedLanguage = languageCode == 'bn' ? 'bn' : 'bn-en';
    try {
      final config = CareSignalConfig.resolve();
      return CareSignalController(
        api: CareSignalApi(config: config, auth: auth),
        recorder: CareSignalRecorder(),
        deviceId: deviceId,
        languageCode: resolvedLanguage,
      );
    } catch (_) {
      return CareSignalController.unavailable(
        auth: auth,
        deviceId: deviceId,
        languageCode: resolvedLanguage,
      );
    }
  }

  static Future<FamilySafetyController> _buildFamilySafetyController({
    required SharedPreferences prefs,
    required FirebaseAuth auth,
    required FirebaseFirestore firestore,
  }) async {
    final repository = FamilyRepository(firestore, auth);
    final identityService = DeviceIdentityService(prefs);
    final batteryService = BatteryService();
    final syncService = LocationSyncService(
      repository: repository,
      batteryService: batteryService,
    );
    final careSignalController = await _buildCareSignalController(
      auth: auth,
      identityService: identityService,
      languageCode: prefs.getString('language_code') ?? 'en',
    );
    return FamilySafetyController(
      repository: repository,
      identityService: identityService,
      batteryService: batteryService,
      syncService: syncService,
      locationProvider: const GeolocatorLocationProvider(),
      serviceBridge: SharingServiceBridge(),
      serviceChannel: SharingServiceChannel(),
      auth: auth,
      careSignalController: careSignalController,
    );
  }

  static void _disposeFamilySafetyController(
    FamilySafetyController controller,
  ) {
    controller.dispose();
    controller.careSignalController.dispose();
  }
}
