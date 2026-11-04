import 'dart:async';

import 'package:amarguard/features/family_safety/controllers/family_safety_controller.dart';
import 'package:amarguard/features/family_safety/models/family_models.dart';
import 'package:amarguard/features/family_safety/services/battery_service.dart';
import 'package:amarguard/features/family_safety/services/device_identity_service.dart';
import 'package:amarguard/features/family_safety/services/family_repository.dart';
import 'package:amarguard/features/family_safety/services/location_provider.dart';
import 'package:amarguard/features/family_safety/services/location_sync_service.dart';
import 'package:amarguard/features/family_safety/services/sharing_service_bridge.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'viewer live listeners follow approved sharing states without reads',
    () async {
      final harness = _FamilySafetyHarness(remoteState: SharingState.active);
      await harness.controller.initialize(isGuest: false);
      await harness.flush();

      expect(harness.repository.activeLocationListeners, 1);
      expect(harness.repository.activeStatusListeners, 1);
      expect(harness.repository.ownerStatusReads, ['owner-1']);
      expect(harness.repository.ownerLocationReads, ['owner-1']);
      expect(harness.repository.viewerStatusReads, isEmpty);
      expect(harness.repository.viewerLocationReads, isEmpty);

      await harness.controller.refresh();
      await harness.controller.refresh();
      expect(harness.repository.activeMetadataListeners, 1);
      expect(harness.repository.activeLocationListeners, 1);
      expect(harness.repository.activeStatusListeners, 1);
      expect(harness.repository.viewerStatusReads, isEmpty);
      expect(harness.repository.viewerLocationReads, isEmpty);

      harness.repository.emitRemoteState(SharingState.paused);
      await harness.flush();
      expect(harness.repository.activeLocationListeners, 1);
      expect(harness.repository.activeStatusListeners, 1);
      expect(
        harness.controller.authorizedConnections.single.presence?.sharingState,
        SharingState.paused,
      );

      harness.repository.emitRemoteState(SharingState.stopped);
      await harness.flush();
      expect(harness.repository.activeLocationListeners, 0);
      expect(harness.repository.activeStatusListeners, 0);
      expect(harness.controller.authorizedConnections.single.location, isNull);
      expect(
        harness.controller.authorizedConnections.single.freshness,
        LocationFreshness.notConnected,
      );
      expect(harness.controller.errorMessage, isNull);

      harness.repository.emitRemoteState(SharingState.permissionDisabled);
      await harness.flush();
      expect(harness.repository.activeLocationListeners, 0);
      expect(harness.repository.activeStatusListeners, 0);
      expect(
        harness.controller.authorizedConnections.single.presence?.sharingState,
        SharingState.permissionDisabled,
      );

      harness.repository.emitRemoteState(SharingState.active);
      await harness.flush();
      expect(harness.repository.activeLocationListeners, 1);
      expect(harness.repository.activeStatusListeners, 1);
      expect(harness.repository.viewerStatusReads, isEmpty);
      expect(harness.repository.viewerLocationReads, isEmpty);

      harness.controller.dispose();
      await harness.flush();
      expect(harness.repository.activeLocationListeners, 0);
      expect(harness.repository.activeStatusListeners, 0);
    },
  );

  test('revocation and auth sign-out clean up all viewer listeners', () async {
    final harness = _FamilySafetyHarness(remoteState: SharingState.active);
    await harness.controller.initialize(isGuest: false);
    await harness.flush();
    expect(harness.repository.activeMetadataListeners, 1);
    expect(harness.repository.activeLocationListeners, 1);
    expect(harness.repository.activeStatusListeners, 1);

    harness.repository.emitViewerAccess(const []);
    await harness.flush();
    expect(harness.repository.activeMetadataListeners, 0);
    expect(harness.repository.activeLocationListeners, 0);
    expect(harness.repository.activeStatusListeners, 0);
    expect(harness.controller.authorizedConnections, isEmpty);

    harness.repository.emitViewerAccess([harness.viewerEntry]);
    await harness.flush();
    expect(harness.repository.activeMetadataListeners, 1);

    harness.auth.emit(null);
    await harness.flush();
    expect(harness.repository.activeMetadataListeners, 0);
    expect(harness.repository.activeLocationListeners, 0);
    expect(harness.repository.activeStatusListeners, 0);
    expect(harness.controller.authorizedConnections, isEmpty);

    harness.controller.dispose();
    await harness.flush();
  });

  test(
    'stopped viewer denial is expected but active denial remains visible',
    () async {
      final harness = _FamilySafetyHarness(remoteState: SharingState.active);
      await harness.controller.initialize(isGuest: false);
      await harness.flush();

      harness.repository.setRemoteStateWithoutNotify(SharingState.stopped);
      harness.repository.emitLocationError(
        FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied'),
      );
      await harness.flush();
      expect(harness.repository.activeLocationListeners, 0);
      expect(harness.controller.errorMessage, isNull);

      harness.repository.emitRemoteState(SharingState.active);
      await harness.flush();
      harness.repository.emitLocationError(
        FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied'),
      );
      await harness.flush();
      expect(harness.controller.errorMessage, contains('permission-denied'));

      expect(await harness.controller.startSharing(), isTrue);
      expect(harness.controller.errorMessage, contains('permission-denied'));

      harness.repository.emitLocationSnapshot(
        SharedLocationRecord(
          ownerUid: 'family-owner',
          deviceId: 'family-device',
          latitude: 23.8,
          longitude: 90.4,
          accuracy: 10,
          capturedAt: DateTime.now().toUtc(),
          syncedAt: DateTime.now().toUtc(),
          batteryLevel: 80,
          isCharging: false,
          sharingSessionId: 'family-session',
        ),
      );
      await harness.flush();
      expect(harness.controller.errorMessage, isNull);

      harness.controller.dispose();
      await harness.flush();
    },
  );

  test(
    'start and stop serialize location writes and ignore late callbacks',
    () async {
      final harness = _FamilySafetyHarness(remoteState: SharingState.stopped);
      await harness.controller.initialize(isGuest: false);
      await harness.flush();

      expect(await harness.controller.startSharing(), isTrue);
      expect(harness.repository.sharingStateWrites, [SharingState.active]);
      expect(
        harness.events.indexOf('state:active'),
        lessThan(harness.events.indexOf('service:start')),
      );

      harness.sync.blockSecondPublish = true;
      harness.serviceChannel.emit(
        _locationUpdate(harness.controller.sharingSessionId),
      );
      await harness.waitUntil(() => harness.sync.publishCalls == 2);

      final stopping = harness.controller.stopSharing();
      await harness.flush();
      expect(harness.repository.sharingStateWrites, [SharingState.active]);
      expect(harness.events, contains('service:stop'));

      harness.sync.releaseBlockedPublish();
      await stopping;
      expect(harness.repository.sharingStateWrites, [
        SharingState.active,
        SharingState.stopped,
      ]);
      expect(
        harness.events.indexOf('service:stop'),
        lessThan(harness.events.lastIndexOf('state:stopped')),
      );

      harness.serviceChannel.emit(_locationUpdate('old-session'));
      await harness.flush();
      expect(harness.sync.publishCalls, 2);

      harness.controller.dispose();
      await harness.flush();
    },
  );
}

SharingLocationUpdate _locationUpdate(String sessionId) {
  return SharingLocationUpdate(
    latitude: 23.8,
    longitude: 90.4,
    accuracy: 10,
    capturedAt: DateTime.now().toUtc().add(const Duration(minutes: 1)),
    sessionId: sessionId,
  );
}

class _FamilySafetyHarness {
  _FamilySafetyHarness({required SharingState remoteState}) {
    repository = _FakeFamilyRepository(
      remoteState: remoteState,
      events: events,
    );
    bridge = _FakeSharingServiceBridge(events: events);
    controller = FamilySafetyController(
      repository: repository,
      identityService: _FakeDeviceIdentityService(),
      batteryService: _FakeBatteryService(),
      syncService: sync,
      locationProvider: _FakeLocationProvider(),
      serviceBridge: bridge,
      serviceChannel: serviceChannel,
      auth: auth,
    );
  }

  final List<String> events = [];
  final _FakeFirebaseAuth auth = _FakeFirebaseAuth();
  final _FakeLocationSyncService sync = _FakeLocationSyncService();
  late final _FakeSharingServiceBridge bridge;
  final _FakeSharingServiceChannel serviceChannel =
      _FakeSharingServiceChannel();
  late final _FakeFamilyRepository repository;
  late final FamilySafetyController controller;

  ViewerAccessEntry get viewerEntry => repository.viewerEntry;

  Future<void> flush() async {
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
  }

  Future<void> waitUntil(bool Function() condition) async {
    for (var attempt = 0; attempt < 20 && !condition(); attempt++) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    expect(condition(), isTrue);
  }
}

class _FakeFirebaseAuth implements FirebaseAuth {
  User? _user = _FakeUser('owner-1');
  final StreamController<User?> _changes = StreamController<User?>.broadcast(
    sync: true,
  );

  @override
  User? get currentUser => _user;

  @override
  Stream<User?> authStateChanges() => _changes.stream;

  void emit(User? user) {
    _user = user;
    _changes.add(user);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeUser implements User {
  _FakeUser(this.uid);

  @override
  final String uid;

  @override
  String? get displayName => 'Owner';

  @override
  String? get email => 'owner@example.test';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeFamilyRepository implements FamilyRepository {
  _FakeFamilyRepository({required this.remoteState, required this.events}) {
    _viewerEntries.add(viewerEntry);
  }

  final List<String> events;
  SharingState remoteState;
  final _viewerEntries = <ViewerAccessEntry>[];
  final _viewerChanges = StreamController<List<ViewerAccessEntry>>.broadcast(
    sync: true,
  );
  final _stateChanges = StreamController<SharingState?>.broadcast(sync: true);
  final _locationChanges = StreamController<SharedLocationRecord?>.broadcast(
    sync: true,
  );
  final _presenceChanges = StreamController<DevicePresenceStatus>.broadcast(
    sync: true,
  );
  int activeMetadataListeners = 0;
  int activeLocationListeners = 0;
  int activeStatusListeners = 0;
  final List<String> ownerStatusReads = [];
  final List<String> ownerLocationReads = [];
  final List<String> viewerStatusReads = [];
  final List<String> viewerLocationReads = [];
  final List<SharingState> sharingStateWrites = [];

  ViewerAccessEntry get viewerEntry => ViewerAccessEntry(
    ownerUid: 'family-owner',
    deviceId: 'family-device',
    ownerDisplayName: 'Family owner',
    relationship: RelationshipType.parent,
    grantedAt: DateTime.utc(2026, 10, 1),
  );

  @override
  Future<void> registerDevice({
    required String deviceId,
    required String nickname,
  }) async {}

  @override
  Future<DevicePresenceStatus> readDeviceStatus({
    required String ownerUid,
    required String deviceId,
    String source = 'family_safety_initialize',
  }) async {
    (ownerUid == 'owner-1' ? ownerStatusReads : viewerStatusReads).add(
      ownerUid,
    );
    return DevicePresenceStatus.empty().copyWith(
      sharingState: ownerUid == 'owner-1' ? SharingState.stopped : remoteState,
    );
  }

  @override
  Future<SharedLocationRecord?> readCurrentLocation({
    required String ownerUid,
    required String deviceId,
    String source = 'family_safety_initialize',
  }) async {
    (ownerUid == 'owner-1' ? ownerLocationReads : viewerLocationReads).add(
      ownerUid,
    );
    return null;
  }

  @override
  Future<List<AccessGrant>> loadGrants({
    required String deviceId,
    String source = 'family_safety_refresh',
  }) async => const [];

  @override
  Future<List<ConnectionRequest>> loadIncomingRequests({
    required String deviceId,
    String source = 'family_safety_initialize',
  }) async => const [];

  @override
  Future<List<ViewerAccessEntry>> loadViewerAccess({
    String source = 'family_safety_refresh',
  }) async => [viewerEntry];

  @override
  Future<FamilyInvitation?> loadActiveInvitation({
    required String deviceId,
  }) async => null;

  @override
  Stream<List<ConnectionRequest>> watchIncomingRequests({
    required String deviceId,
  }) => Stream.value(const []);

  @override
  Stream<List<ViewerAccessEntry>> watchViewerAccess() async* {
    yield [viewerEntry];
    yield* _viewerChanges.stream;
  }

  @override
  Stream<SharingState?> watchDeviceSharingState({
    required String ownerUid,
    required String deviceId,
  }) async* {
    activeMetadataListeners++;
    try {
      yield remoteState;
      yield* _stateChanges.stream;
    } finally {
      activeMetadataListeners--;
    }
  }

  @override
  Stream<SharedLocationRecord?> watchCurrentLocation({
    required String ownerUid,
    required String deviceId,
  }) async* {
    activeLocationListeners++;
    try {
      yield* _locationChanges.stream;
    } finally {
      activeLocationListeners--;
    }
  }

  @override
  Stream<DevicePresenceStatus> watchDeviceStatus({
    required String ownerUid,
    required String deviceId,
  }) async* {
    activeStatusListeners++;
    try {
      yield* _presenceChanges.stream;
    } finally {
      activeStatusListeners--;
    }
  }

  @override
  Future<SharingState?> readDeviceSharingState({
    required String ownerUid,
    required String deviceId,
    String source = 'viewer_authorization_check',
    bool logFailures = true,
  }) async => remoteState;

  @override
  Future<bool> hasViewerAccessEntry({
    required String ownerUid,
    required String deviceId,
    String source = 'viewer_revocation_check',
  }) async => _viewerEntries.any(
    (entry) => entry.ownerUid == ownerUid && entry.deviceId == deviceId,
  );

  @override
  Future<void> setDeviceSharingState({
    required String deviceId,
    required SharingState state,
  }) async {
    sharingStateWrites.add(state);
    events.add('state:${state.name}');
  }

  void emitRemoteState(SharingState state) {
    remoteState = state;
    _stateChanges.add(state);
  }

  void setRemoteStateWithoutNotify(SharingState state) {
    remoteState = state;
  }

  void emitLocationError(Object error) => _locationChanges.addError(error);

  void emitLocationSnapshot(SharedLocationRecord location) {
    _locationChanges.add(location);
  }

  void emitViewerAccess(List<ViewerAccessEntry> entries) {
    _viewerEntries
      ..clear()
      ..addAll(entries);
    _viewerChanges.add(entries);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeDeviceIdentityService implements DeviceIdentityService {
  @override
  Future<String> ensureDeviceId() async => 'device-1';

  @override
  Future<String> nicknameForDevice(String deviceId) async => 'My Device';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeBatteryService implements BatteryService {
  @override
  Future<BatteryAssessment> read() async => BatteryAssessment(
    level: 80,
    state: BatteryState.discharging,
    observedAt: DateTime.now().toUtc(),
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeLocationProvider implements LocationProvider {
  @override
  Future<bool> isServiceEnabled() async => true;

  @override
  Future<LocationPermission> checkPermission() async =>
      LocationPermission.always;

  @override
  Future<LocationPermission> requestPermission() async =>
      LocationPermission.always;

  @override
  Future<LocationAccuracyStatus> accuracyStatus() async =>
      LocationAccuracyStatus.precise;

  @override
  Future<AcquiredLocation> currentPosition({
    required Duration timeLimit,
  }) async => AcquiredLocation(
    latitude: 23.8,
    longitude: 90.4,
    accuracy: 10,
    capturedAt: DateTime.now().toUtc(),
    altitude: 0,
    speed: 0,
  );

  @override
  Stream<AcquiredLocation> positionStream({
    required Duration interval,
    required double distanceFilter,
    required bool highAccuracy,
  }) => const Stream.empty();

  @override
  Future<bool> openLocationSettings() async => true;

  @override
  Future<bool> openAppSettings() async => true;
}

class _FakeLocationSyncService implements LocationSyncService {
  int publishCalls = 0;
  bool blockSecondPublish = false;
  final Completer<void> _blockedPublish = Completer<void>();

  @override
  Future<SharingSyncResult> publish({
    required String ownerUid,
    required String deviceId,
    required AcquiredLocation location,
    required String sharingSessionId,
  }) async {
    publishCalls++;
    if (publishCalls == 2 && blockSecondPublish) {
      await _blockedPublish.future;
    }
    final record = SharedLocationRecord(
      ownerUid: ownerUid,
      deviceId: deviceId,
      latitude: location.latitude,
      longitude: location.longitude,
      accuracy: location.accuracy,
      capturedAt: location.capturedAt,
      syncedAt: DateTime.now().toUtc(),
      batteryLevel: 80,
      isCharging: false,
      sharingSessionId: sharingSessionId,
    );
    return SharingSyncResult(accepted: true, record: record);
  }

  @override
  Future<void> publishStatus({
    required String ownerUid,
    required String deviceId,
    required SharingState state,
    required String permissionState,
  }) async {}

  void releaseBlockedPublish() {
    if (!_blockedPublish.isCompleted) _blockedPublish.complete();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeSharingServiceBridge implements SharingServiceBridge {
  _FakeSharingServiceBridge({this.events = const []});

  final List<String> events;

  @override
  Future<bool> start({
    required String sessionId,
    required int intervalSeconds,
    required int distanceFilterMeters,
  }) async {
    events.add('service:start');
    return true;
  }

  @override
  Future<bool> pause() async {
    events.add('service:pause');
    return true;
  }

  @override
  Future<bool> resume({required String sessionId}) async {
    events.add('service:resume');
    return true;
  }

  @override
  Future<bool> stop() async {
    events.add('service:stop');
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeSharingServiceChannel implements SharingServiceChannel {
  final StreamController<SharingLocationUpdate> _updates =
      StreamController<SharingLocationUpdate>.broadcast(sync: true);

  @override
  Stream<SharingLocationUpdate> updates() => _updates.stream;

  void emit(SharingLocationUpdate update) => _updates.add(update);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
