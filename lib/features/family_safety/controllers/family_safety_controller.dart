import 'dart:async';

import 'package:battery_plus/battery_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../models/family_models.dart';
import '../services/battery_service.dart';
import '../services/device_identity_service.dart';
import '../services/family_exceptions.dart';
import '../services/family_firestore_diagnostics.dart';
import '../services/family_repository.dart';
import '../services/location_provider.dart';
import '../services/location_sync_service.dart';
import '../services/sharing_service_bridge.dart';
import 'caresignal_controller.dart';

enum CareLoadState { idle, loading, ready, error }

class FamilySafetyController extends ChangeNotifier {
  FamilySafetyController({
    required this._repository,
    required this._identityService,
    required this._batteryService,
    required this._syncService,
    required this._locationProvider,
    required this._serviceBridge,
    required this._serviceChannel,
    required this._auth,
    this._careSignalController,
  });

  final FamilyRepository _repository;
  final DeviceIdentityService _identityService;
  final BatteryService _batteryService;
  final LocationSyncService _syncService;
  final LocationProvider _locationProvider;
  final SharingServiceBridge _serviceBridge;
  final SharingServiceChannel _serviceChannel;
  final FirebaseAuth _auth;
  final CareSignalController? _careSignalController;

  CareLoadState _loadState = CareLoadState.idle;
  String? _errorMessage;
  String? _viewerErrorMessage;
  final Map<String, Map<String, String>> _viewerListenerErrors = {};
  DeviceIdentity? _deviceIdentity;
  SharingState _sharingState = SharingState.notConfigured;
  DevicePresenceStatus _presence = DevicePresenceStatus.empty();
  SharedLocationRecord? _currentLocation;
  BatteryAssessment _battery = BatteryAssessment(
    level: -1,
    state: BatteryState.unknown,
    observedAt: DateTime.now().toUtc(),
  );
  List<AccessGrant> _grants = const [];
  List<ConnectionRequest> _requests = const [];
  List<ViewerAccessEntry> _viewerAccess = const [];
  final Map<String, SharedLocationRecord?> _watchedLocations = {};
  final Map<String, DevicePresenceStatus> _watchedPresence = {};
  final Map<String, SharingState> _watchedSharingStates = {};
  final Map<String, StreamSubscription<SharingState?>> _deviceSubscriptions =
      {};
  final Map<String, StreamSubscription<SharedLocationRecord?>>
  _locationSubscriptions = {};
  final Map<String, StreamSubscription<DevicePresenceStatus>>
  _presenceSubscriptions = {};
  FamilyInvitation? _activeInvitation;
  bool _isGuest = false;
  String _sharingSessionId = '';
  StreamSubscription<SharingLocationUpdate>? _serviceUpdatesSubscription;
  StreamSubscription<List<ConnectionRequest>>? _incomingRequestsSubscription;
  StreamSubscription<List<ViewerAccessEntry>>? _viewerAccessSubscription;
  StreamSubscription<User?>? _authStateSubscription;
  Timer? _syncRetryTimer;
  SharingLocationUpdate? _pendingServiceUpdate;
  bool _syncInFlight = false;
  Completer<void>? _syncIdle;
  bool _sharingTransitionInProgress = false;
  bool _isDisposed = false;
  String? _boundUid;
  int _initializationGeneration = 0;

  CareLoadState get loadState => _loadState;

  String? get errorMessage => _viewerErrorMessage ?? _errorMessage;

  DeviceIdentity? get deviceIdentity => _deviceIdentity;

  SharingState get sharingState => _sharingState;

  DevicePresenceStatus get presence => _presence;

  SharedLocationRecord? get currentLocation => _currentLocation;

  BatteryAssessment get battery => _battery;

  List<AccessGrant> get grants => _grants;

  List<ConnectionRequest> get requests => _requests;

  List<ViewerAccessEntry> get viewerAccess => _viewerAccess;

  List<FamilyConnection> get authorizedConnections {
    final viewerUid = _auth.currentUser?.uid ?? '';
    return _viewerAccess.map((entry) {
      final key = _watchKey(entry.ownerUid, entry.deviceId);
      return FamilyConnection(
        ownerUid: entry.ownerUid,
        deviceId: entry.deviceId,
        grant: AccessGrant(
          viewerUid: viewerUid,
          ownerUid: entry.ownerUid,
          deviceId: entry.deviceId,
          grantedAt: entry.grantedAt,
          active: true,
          viewerDisplayName: entry.ownerDisplayName,
          relationship: entry.relationship,
        ),
        location: _watchedLocations[key],
        presence: _watchedPresence[key],
        ownerDisplayName: entry.ownerDisplayName,
        alias: entry.alias,
      );
    }).toList();
  }

  FamilyInvitation? get activeInvitation => _activeInvitation;

  bool get isGuest => _isGuest;

  String get sharingSessionId => _sharingSessionId;

  int get approvedViewerCount => _grants.where((grant) => grant.active).length;

  bool get isSyncStale {
    final lastUpload =
        _presence.lastSuccessfulUpload ??
        _currentLocation?.syncedAt ??
        _currentLocation?.capturedAt;
    return lastUpload == null ||
        DateTime.now().toUtc().difference(lastUpload) >
            LocationFreshnessEvaluator.freshWindow;
  }

  CareSignalController get careSignalController =>
      _careSignalController ??
      (throw StateError('CareSignal AI is not available for this session.'));

  bool get hasApprovedViewers => approvedViewerCount > 0;

  Future<void> initialize({required bool isGuest}) async {
    _isGuest = isGuest;
    if (isGuest) {
      _loadState = CareLoadState.ready;
      _sharingState = SharingState.notConfigured;
      notifyListeners();
      return;
    }
    final user = _auth.currentUser;
    if (user == null) {
      _loadState = CareLoadState.error;
      _errorMessage = 'unauthenticated';
      notifyListeners();
      return;
    }
    _boundUid = user.uid;
    _authStateSubscription ??= _auth.authStateChanges().listen(
      _handleAuthChange,
    );
    final generation = ++_initializationGeneration;
    _loadState = CareLoadState.loading;
    notifyListeners();
    try {
      final deviceId = await _identityService.ensureDeviceId();
      if (!_isCurrentInitialization(user.uid, generation)) return;
      final nickname = await _identityService.nicknameForDevice(deviceId);
      if (!_isCurrentInitialization(user.uid, generation)) return;
      _deviceIdentity = DeviceIdentity(
        deviceId: deviceId,
        nickname: nickname,
        registeredOwnerUid: user.uid,
      );
      await _repository.registerDevice(deviceId: deviceId, nickname: nickname);
      if (!_isCurrentInitialization(user.uid, generation)) return;
      _presence = await _repository.readDeviceStatus(
        ownerUid: user.uid,
        deviceId: deviceId,
      );
      if (!_isCurrentInitialization(user.uid, generation)) return;
      _currentLocation = await _repository.readCurrentLocation(
        ownerUid: user.uid,
        deviceId: deviceId,
      );
      if (!_isCurrentInitialization(user.uid, generation)) return;
      _sharingState = _resolveSharingState(_presence);
      _battery = await _batteryService.read();
      if (!_isCurrentInitialization(user.uid, generation)) return;
      await _refreshGrants(source: 'family_safety_initialize');
      if (!_isCurrentInitialization(user.uid, generation)) return;
      await _refreshRequests(source: 'family_safety_initialize');
      if (!_isCurrentInitialization(user.uid, generation)) return;
      await _refreshViewerAccess();
      if (!_isCurrentInitialization(user.uid, generation)) return;
      _activeInvitation = await _repository.loadActiveInvitation(
        deviceId: deviceId,
      );
      if (!_isCurrentInitialization(user.uid, generation)) return;
      _listenForIncomingRequests(deviceId);
      _listenForViewerAccess();
      _listenForServiceUpdates();
      _loadState = CareLoadState.ready;
      _errorMessage = null;
    } catch (error) {
      if (!_isCurrentInitialization(user.uid, generation)) return;
      _loadState = CareLoadState.error;
      _errorMessage = error.toString();
    }

    notifyListeners();
  }

  bool _isCurrentInitialization(String uid, int generation) {
    return !_isDisposed &&
        generation == _initializationGeneration &&
        _boundUid == uid &&
        _auth.currentUser?.uid == uid;
  }

  void _handleAuthChange(User? user) {
    final uid = user?.uid;
    if (_boundUid == uid || _isDisposed) return;
    _boundUid = uid;
    _initializationGeneration++;
    _syncRetryTimer?.cancel();
    _pendingServiceUpdate = null;
    _cancelFirestoreSubscriptions();
    _deviceIdentity = null;
    _presence = DevicePresenceStatus.empty();
    _currentLocation = null;
    _grants = const [];
    _requests = const [];
    _viewerAccess = const [];
    _viewerListenerErrors.clear();
    _viewerErrorMessage = null;
    _watchedLocations.clear();
    _watchedPresence.clear();
    _watchedSharingStates.clear();
    _sharingState = SharingState.notConfigured;
    _errorMessage = null;
    _loadState = user == null ? CareLoadState.idle : CareLoadState.loading;
    notifyListeners();
    if (user != null) unawaited(initialize(isGuest: false));
  }

  void _cancelFirestoreSubscriptions() {
    unawaited(_incomingRequestsSubscription?.cancel());
    unawaited(_viewerAccessSubscription?.cancel());
    unawaited(_serviceUpdatesSubscription?.cancel());
    _incomingRequestsSubscription = null;
    _viewerAccessSubscription = null;
    _serviceUpdatesSubscription = null;
    for (final subscription in _deviceSubscriptions.values) {
      unawaited(subscription.cancel());
    }
    for (final subscription in _locationSubscriptions.values) {
      unawaited(subscription.cancel());
    }
    for (final subscription in _presenceSubscriptions.values) {
      unawaited(subscription.cancel());
    }
    _deviceSubscriptions.clear();
    _locationSubscriptions.clear();
    _presenceSubscriptions.clear();
  }

  void _listenForIncomingRequests(String deviceId) {
    _incomingRequestsSubscription?.cancel();
    _incomingRequestsSubscription = _repository
        .watchIncomingRequests(deviceId: deviceId)
        .listen(
          (requests) {
            if (_isDisposed) return;
            _requests = requests;
            notifyListeners();
          },
          onError: (Object error, StackTrace stackTrace) {
            if (_isDisposed) return;
            FamilyFirestoreDiagnostics.logFailure(
              operation: 'listen',
              path: 'users/<uid>/devices/<device>/incomingRequests',
              sharingState: _sharingState.name,
              role: 'owner',
              source: 'incoming_requests_listener',
              error: error,
            );
            _errorMessage = error.toString();
            notifyListeners();
          },
        );
  }

  void _listenForViewerAccess() {
    _viewerAccessSubscription?.cancel();
    _viewerAccessSubscription = _repository.watchViewerAccess().listen(
      (entries) {
        if (_isDisposed) return;
        _clearViewerListenerError(
          '__viewer_access__',
          'viewer_access_listener',
        );
        _viewerAccess = entries;
        _reconcileViewerWatchers(entries);
        notifyListeners();
      },
      onError: (Object error, StackTrace stackTrace) {
        if (_isDisposed) return;
        FamilyFirestoreDiagnostics.logFailure(
          operation: 'listen',
          path: 'familyViewerAccess/<uid>/grants',
          sharingState: _sharingState.name,
          role: 'viewer',
          source: 'viewer_access_listener',
          error: error,
        );
        _recordViewerListenerError(
          '__viewer_access__',
          'viewer_access_listener',
          error,
        );
        notifyListeners();
      },
    );
  }

  void _listenForServiceUpdates() {
    _serviceUpdatesSubscription?.cancel();
    _serviceUpdatesSubscription = _serviceChannel.updates().listen((update) {
      unawaited(_handleServiceUpdate(update));
    });
  }

  Future<void> _handleServiceUpdate(SharingLocationUpdate update) async {
    if (_isDisposed) return;
    final identity = _deviceIdentity;
    if (_sharingState != SharingState.active ||
        identity == null ||
        _auth.currentUser?.uid != identity.registeredOwnerUid ||
        (_sharingSessionId.isNotEmpty &&
            update.sessionId.isNotEmpty &&
            update.sessionId != _sharingSessionId)) {
      return;
    }
    _pendingServiceUpdate = update;
    await _flushPendingServiceUpdate();
  }

  Future<void> _flushPendingServiceUpdate() async {
    if (_syncInFlight) return;
    final update = _pendingServiceUpdate;
    if (update == null) return;
    final identity = _deviceIdentity;
    if (_sharingState != SharingState.active ||
        identity == null ||
        _auth.currentUser?.uid != identity.registeredOwnerUid) {
      _pendingServiceUpdate = null;
      return;
    }
    _pendingServiceUpdate = null;
    _syncInFlight = true;
    final idle = Completer<void>();
    _syncIdle = idle;
    try {
      final result = await _syncService.publish(
        ownerUid: identity.registeredOwnerUid,
        deviceId: identity.deviceId,
        location: AcquiredLocation(
          latitude: update.latitude,
          longitude: update.longitude,
          accuracy: update.accuracy,
          capturedAt: update.capturedAt,
          altitude: 0,
          speed: 0,
        ),
        sharingSessionId: update.sessionId.isEmpty
            ? _sharingSessionId
            : update.sessionId,
      );
      if (result.accepted) {
        _battery = _battery.copyWith(
          level: result.record.batteryLevel,
          state: result.record.isCharging
              ? BatteryState.charging
              : BatteryState.discharging,
          observedAt: DateTime.now().toUtc(),
        );
        _presence = _presence.copyWith(
          sharingState: SharingState.active,
          lastSuccessfulUpload: result.record.syncedAt,
          batteryLevel: result.record.batteryLevel,
          isCharging: result.record.isCharging,
          batteryObservedAt: result.record.syncedAt,
        );
        notifyListeners();
      }
    } on FirebaseException catch (error) {
      _errorMessage = error.code;
      FamilyFirestoreDiagnostics.logFailure(
        operation: 'write',
        path: 'users/<uid>/devices/<device>/{location,status}',
        sharingState: _sharingState.name,
        role: 'owner',
        source: 'background_location_update',
        error: error,
      );
      if (_sharingState == SharingState.active) _scheduleSyncRetry();
      notifyListeners();
    } catch (error) {
      _errorMessage = error.toString();
      if (_sharingState == SharingState.active) _scheduleSyncRetry();
      notifyListeners();
    } finally {
      _syncInFlight = false;
      if (!idle.isCompleted) idle.complete();
      if (identical(_syncIdle, idle)) _syncIdle = null;
      if (_sharingState == SharingState.active &&
          _pendingServiceUpdate != null) {
        unawaited(_flushPendingServiceUpdate());
      }
    }
  }

  void _scheduleSyncRetry() {
    _syncRetryTimer?.cancel();
    _syncRetryTimer = Timer(const Duration(seconds: 30), () {
      unawaited(_flushPendingServiceUpdate());
    });
  }

  Future<bool> requestForegroundPermission() async {
    final permission = await _locationProvider.requestPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      final identity = _deviceIdentity;
      if (identity != null &&
          _auth.currentUser?.uid == identity.registeredOwnerUid) {
        await _setPermissionDisabled(identity);
      } else {
        _sharingState = SharingState.permissionDisabled;
        notifyListeners();
      }
      return false;
    }
    return true;
  }

  Future<bool> isLocationServiceEnabled() {
    return _locationProvider.isServiceEnabled();
  }

  Future<LocationPermission> currentPermission() {
    return _locationProvider.checkPermission();
  }

  Future<bool> startSharing() async {
    if (_sharingTransitionInProgress) return false;
    final identity = _deviceIdentity;
    if (identity == null ||
        _auth.currentUser?.uid != identity.registeredOwnerUid) {
      return false;
    }
    _sharingTransitionInProgress = true;
    try {
      return await _startSharing(identity);
    } finally {
      _sharingTransitionInProgress = false;
    }
  }

  Future<bool> _startSharing(DeviceIdentity identity) async {
    final serviceEnabled = await _locationProvider.isServiceEnabled();
    if (!serviceEnabled) {
      _errorMessage = 'location_service_disabled';
      notifyListeners();
      return false;
    }
    final permission = await _locationProvider.checkPermission();
    if (permission != LocationPermission.always &&
        permission != LocationPermission.whileInUse) {
      await _setPermissionDisabled(identity);
      return false;
    }
    final nextSessionId = _buildSessionId();
    try {
      await _repository.setDeviceSharingState(
        deviceId: identity.deviceId,
        state: SharingState.active,
      );
      await _syncService.publishStatus(
        ownerUid: identity.registeredOwnerUid,
        deviceId: identity.deviceId,
        state: SharingState.active,
        permissionState: 'granted',
      );
      _sharingSessionId = nextSessionId;
      _sharingState = SharingState.active;
      final started = await _serviceBridge.start(
        sessionId: _sharingSessionId,
        intervalSeconds: 90,
        distanceFilterMeters: 20,
      );
      if (!started) {
        throw StateError('service_start_failed');
      }
      await _captureInitialLocation(identity);
      notifyListeners();
      return true;
    } catch (error) {
      await _serviceBridge.stop();
      _sharingState = SharingState.stopped;
      _sharingSessionId = '';
      await _repository.setDeviceSharingState(
        deviceId: identity.deviceId,
        state: SharingState.stopped,
      );
      await _syncService.publishStatus(
        ownerUid: identity.registeredOwnerUid,
        deviceId: identity.deviceId,
        state: SharingState.stopped,
        permissionState: 'granted',
      );
      _errorMessage = error.toString();
      notifyListeners();
      return false;
    }
  }

  Future<void> _setPermissionDisabled(DeviceIdentity identity) async {
    _sharingState = SharingState.permissionDisabled;
    _pendingServiceUpdate = null;
    _syncRetryTimer?.cancel();
    await _serviceBridge.stop();
    await _waitForSyncIdle();
    await _repository.setDeviceSharingState(
      deviceId: identity.deviceId,
      state: SharingState.permissionDisabled,
    );
    await _syncService.publishStatus(
      ownerUid: identity.registeredOwnerUid,
      deviceId: identity.deviceId,
      state: SharingState.permissionDisabled,
      permissionState: 'denied',
    );
    _presence = _presence.copyWith(
      sharingState: SharingState.permissionDisabled,
      permissionState: 'denied',
    );
    notifyListeners();
  }

  Future<void> _captureInitialLocation(DeviceIdentity identity) async {
    try {
      final location = await _locationProvider.currentPosition(
        timeLimit: const Duration(seconds: 25),
      );
      final result = await _syncService.publish(
        ownerUid: identity.registeredOwnerUid,
        deviceId: identity.deviceId,
        location: location,
        sharingSessionId: _sharingSessionId,
      );
      if (result.accepted) {
        _battery = _battery.copyWith(
          level: result.record.batteryLevel,
          state: result.record.isCharging
              ? BatteryState.charging
              : BatteryState.discharging,
          observedAt: DateTime.now().toUtc(),
        );
        _presence = _presence.copyWith(
          sharingState: SharingState.active,
          lastSuccessfulUpload: result.record.syncedAt,
          batteryLevel: result.record.batteryLevel,
          isCharging: result.record.isCharging,
          batteryObservedAt: result.record.syncedAt,
        );
      }
    } catch (error) {
      _errorMessage = error.toString();
      notifyListeners();
    }
  }

  Future<void> pauseSharing() async {
    if (_sharingTransitionInProgress) return;
    final identity = _deviceIdentity;
    if (identity == null ||
        _auth.currentUser?.uid != identity.registeredOwnerUid) {
      return;
    }
    _sharingTransitionInProgress = true;
    _sharingState = SharingState.paused;
    _pendingServiceUpdate = null;
    _syncRetryTimer?.cancel();
    try {
      await _serviceBridge.pause();
      await _waitForSyncIdle();
      await _repository.setDeviceSharingState(
        deviceId: identity.deviceId,
        state: SharingState.paused,
      );
      await _syncService.publishStatus(
        ownerUid: identity.registeredOwnerUid,
        deviceId: identity.deviceId,
        state: SharingState.paused,
        permissionState: 'granted',
      );
      _presence = _presence.copyWith(sharingState: SharingState.paused);
      notifyListeners();
    } finally {
      _sharingTransitionInProgress = false;
    }
  }

  Future<void> resumeSharing() async {
    if (_sharingTransitionInProgress) return;
    final identity = _deviceIdentity;
    if (identity == null ||
        _auth.currentUser?.uid != identity.registeredOwnerUid) {
      return;
    }
    _sharingTransitionInProgress = true;
    try {
      if (_sharingSessionId.isEmpty) {
        _sharingSessionId = _buildSessionId();
      }
      await _repository.setDeviceSharingState(
        deviceId: identity.deviceId,
        state: SharingState.active,
      );
      await _syncService.publishStatus(
        ownerUid: identity.registeredOwnerUid,
        deviceId: identity.deviceId,
        state: SharingState.active,
        permissionState: 'granted',
      );
      _sharingState = SharingState.active;
      final resumed = await _serviceBridge.resume(sessionId: _sharingSessionId);
      if (!resumed) {
        _sharingState = SharingState.paused;
        await _repository.setDeviceSharingState(
          deviceId: identity.deviceId,
          state: SharingState.paused,
        );
        await _syncService.publishStatus(
          ownerUid: identity.registeredOwnerUid,
          deviceId: identity.deviceId,
          state: SharingState.paused,
          permissionState: 'granted',
        );
        _errorMessage = 'service_resume_failed';
        notifyListeners();
        return;
      }
      _presence = _presence.copyWith(sharingState: SharingState.active);
      notifyListeners();
    } finally {
      _sharingTransitionInProgress = false;
    }
  }

  Future<void> stopSharing() async {
    if (_sharingTransitionInProgress) return;
    final identity = _deviceIdentity;
    if (identity == null ||
        _auth.currentUser?.uid != identity.registeredOwnerUid) {
      return;
    }
    _sharingTransitionInProgress = true;
    _sharingState = SharingState.stopped;
    _pendingServiceUpdate = null;
    _syncRetryTimer?.cancel();
    try {
      await _serviceBridge.stop();
      await _waitForSyncIdle();
      _sharingSessionId = '';
      await _repository.setDeviceSharingState(
        deviceId: identity.deviceId,
        state: SharingState.stopped,
      );
      await _syncService.publishStatus(
        ownerUid: identity.registeredOwnerUid,
        deviceId: identity.deviceId,
        state: SharingState.stopped,
        permissionState: 'granted',
      );
      _presence = _presence.copyWith(sharingState: SharingState.stopped);
      notifyListeners();
    } finally {
      _sharingTransitionInProgress = false;
    }
  }

  Future<void> _waitForSyncIdle() async {
    final idle = _syncIdle;
    if (idle != null) await idle.future;
  }

  Future<void> renameDevice(String nickname) async {
    final identity = _deviceIdentity;
    if (identity == null) return;
    final trimmed = nickname.trim();
    if (trimmed.isEmpty) return;
    await _identityService.saveNickname(identity.deviceId, trimmed);
    _deviceIdentity = identity.copyWith(nickname: trimmed);
    await _repository.updateDeviceNickname(
      deviceId: identity.deviceId,
      nickname: trimmed,
    );
    notifyListeners();
  }

  Future<void> _refreshGrants({String source = 'family_safety_refresh'}) async {
    final identity = _deviceIdentity;
    if (identity == null) return;
    _grants = await _repository.loadGrants(
      deviceId: identity.deviceId,
      source: source,
    );
  }

  Future<void> _refreshRequests({
    String source = 'family_safety_refresh',
  }) async {
    final identity = _deviceIdentity;
    if (identity == null) return;
    _requests = await _repository.loadIncomingRequests(
      deviceId: identity.deviceId,
      source: source,
    );
  }

  Future<void> _refreshViewerAccess({
    String source = 'family_safety_initialize',
  }) async {
    _viewerAccess = await _repository.loadViewerAccess(source: source);
    _clearViewerListenerError('__viewer_access__', 'viewer_access_listener');
    _reconcileViewerWatchers(_viewerAccess);
  }

  void _reconcileViewerWatchers(List<ViewerAccessEntry> entries) {
    final activeKeys = <String>{};
    for (final entry in entries) {
      final key = _watchKey(entry.ownerUid, entry.deviceId);
      activeKeys.add(key);
      _watchConnection(entry.ownerUid, entry.deviceId);
    }
    for (final key in _deviceSubscriptions.keys.toList()) {
      if (!activeKeys.contains(key)) {
        _removeViewerConnection(key);
      }
    }
  }

  void _watchConnection(String ownerUid, String deviceId) {
    final key = _watchKey(ownerUid, deviceId);
    if (_deviceSubscriptions.containsKey(key)) return;
    _deviceSubscriptions[key] = _repository
        .watchDeviceSharingState(ownerUid: ownerUid, deviceId: deviceId)
        .listen(
          (state) {
            if (_isDisposed) return;
            if (state == null) {
              unawaited(
                _handleViewerReadError(
                  key: key,
                  path: 'users/<uid>/devices/<device>',
                  operation: 'listen',
                  source: 'viewer_device_metadata_listener',
                  error: StateError('approved_device_missing'),
                ),
              );
              return;
            }
            _clearViewerListenerError(key, 'viewer_device_metadata_listener');
            _applyViewerSharingState(key, ownerUid, deviceId, state);
          },
          onError: (Object error, StackTrace stackTrace) {
            if (_isDisposed) return;
            unawaited(
              _handleViewerReadError(
                key: key,
                path: 'users/<uid>/devices/<device>',
                operation: 'listen',
                source: 'viewer_device_metadata_listener',
                error: error,
              ),
            );
          },
        );
  }

  bool _viewerMayReadLiveData(SharingState state) {
    return state == SharingState.active || state == SharingState.paused;
  }

  void _applyViewerSharingState(
    String key,
    String ownerUid,
    String deviceId,
    SharingState state,
  ) {
    _watchedSharingStates[key] = state;
    final oldPresence = _watchedPresence[key] ?? DevicePresenceStatus.empty();
    _watchedPresence[key] = oldPresence.copyWith(sharingState: state);
    if (_viewerMayReadLiveData(state)) {
      _watchLiveConnection(ownerUid, deviceId, key);
    } else {
      _stopLiveConnection(key, state);
    }
    notifyListeners();
  }

  void _watchLiveConnection(String ownerUid, String deviceId, String key) {
    if (!_locationSubscriptions.containsKey(key)) {
      _locationSubscriptions[key] = _repository
          .watchCurrentLocation(ownerUid: ownerUid, deviceId: deviceId)
          .listen(
            (location) {
              if (_isDisposed ||
                  !_viewerMayReadLiveData(
                    _watchedSharingStates[key] ?? SharingState.notConfigured,
                  )) {
                return;
              }
              _clearViewerListenerError(key, 'viewer_location_listener');
              _watchedLocations[key] = location;
              notifyListeners();
            },
            onError: (Object error, StackTrace stackTrace) {
              if (_isDisposed) return;
              unawaited(
                _handleViewerReadError(
                  key: key,
                  path: 'users/<uid>/devices/<device>/location/current',
                  operation: 'listen',
                  source: 'viewer_location_listener',
                  error: error,
                ),
              );
            },
          );
    }
    if (!_presenceSubscriptions.containsKey(key)) {
      _presenceSubscriptions[key] = _repository
          .watchDeviceStatus(ownerUid: ownerUid, deviceId: deviceId)
          .listen(
            (presence) {
              if (_isDisposed ||
                  !_viewerMayReadLiveData(
                    _watchedSharingStates[key] ?? SharingState.notConfigured,
                  )) {
                return;
              }
              _clearViewerListenerError(key, 'viewer_status_listener');
              _watchedPresence[key] = presence.copyWith(
                sharingState: _watchedSharingStates[key],
              );
              notifyListeners();
            },
            onError: (Object error, StackTrace stackTrace) {
              if (_isDisposed) return;
              unawaited(
                _handleViewerReadError(
                  key: key,
                  path: 'users/<uid>/devices/<device>/status/current',
                  operation: 'listen',
                  source: 'viewer_status_listener',
                  error: error,
                ),
              );
            },
          );
    }
  }

  void _stopLiveConnection(String key, SharingState state) {
    _watchedLocations.remove(key);
    final oldPresence = _watchedPresence[key] ?? DevicePresenceStatus.empty();
    _watchedPresence[key] = oldPresence.copyWith(sharingState: state);
    unawaited(_locationSubscriptions.remove(key)?.cancel());
    unawaited(_presenceSubscriptions.remove(key)?.cancel());
  }

  Future<void> _handleViewerReadError({
    required String key,
    required String path,
    required String operation,
    required String source,
    required Object error,
  }) async {
    ViewerAccessEntry? entry;
    for (final candidate in _viewerAccess) {
      if (_watchKey(candidate.ownerUid, candidate.deviceId) == key) {
        entry = candidate;
        break;
      }
    }
    if (entry == null || _isDisposed) return;

    if ((error is FirebaseException && error.code == 'permission-denied') ||
        error is StateError) {
      Object? metadataReadError;
      try {
        final state = await _repository.readDeviceSharingState(
          ownerUid: entry.ownerUid,
          deviceId: entry.deviceId,
          source: source,
          logFailures: false,
        );
        if (_isDisposed) return;
        if (state != null && !_viewerMayReadLiveData(state)) {
          _applyViewerSharingState(key, entry.ownerUid, entry.deviceId, state);
          FamilyFirestoreDiagnostics.logFailure(
            operation: operation,
            path: path,
            sharingState: state.name,
            role: 'viewer',
            source: source,
            error: error,
            expected: true,
          );
          _clearViewerListenerErrorsForKey(key);
          return;
        }
      } catch (checkError) {
        metadataReadError = checkError;
      }
      if (_isDisposed) return;

      try {
        final stillApproved = await _repository.hasViewerAccessEntry(
          ownerUid: entry.ownerUid,
          deviceId: entry.deviceId,
          source: source,
        );
        if (_isDisposed) return;
        if (!stillApproved) {
          FamilyFirestoreDiagnostics.logFailure(
            operation: operation,
            path: path,
            sharingState: _watchedSharingStates[key]?.name ?? 'unknown',
            role: 'viewer',
            source: source,
            error: error,
            expected: true,
          );
          _clearViewerListenerErrorsForKey(key);
          _removeViewerConnection(key);
          notifyListeners();
          return;
        }
      } catch (checkError) {
        if (_isDisposed) return;
        FamilyFirestoreDiagnostics.logFailure(
          operation: 'get',
          path: 'familyViewerAccess/<uid>/grants/<owner>__<device>',
          sharingState: _watchedSharingStates[key]?.name ?? 'unknown',
          role: 'viewer',
          source: source,
          error: checkError,
        );
      }
      if (_isDisposed) return;
      if (metadataReadError != null) {
        FamilyFirestoreDiagnostics.logFailure(
          operation: 'get',
          path: 'users/<uid>/devices/<device>',
          sharingState: 'unknown',
          role: 'viewer',
          source: source,
          error: metadataReadError,
        );
      }
    }

    FamilyFirestoreDiagnostics.logFailure(
      operation: operation,
      path: path,
      sharingState: _watchedSharingStates[key]?.name ?? 'unknown',
      role: 'viewer',
      source: source,
      error: error,
    );
    _recordViewerListenerError(key, source, error);
    notifyListeners();
  }

  void _recordViewerListenerError(String key, String source, Object error) {
    _viewerListenerErrors.putIfAbsent(key, () => {})[source] = error.toString();
    _refreshViewerErrorMessage();
  }

  void _clearViewerListenerError(String key, String source) {
    final errors = _viewerListenerErrors[key];
    errors?.remove(source);
    if (errors?.isEmpty == true) _viewerListenerErrors.remove(key);
    _refreshViewerErrorMessage();
  }

  void _clearViewerListenerErrorsForKey(String key) {
    _viewerListenerErrors.remove(key);
    _refreshViewerErrorMessage();
  }

  void _refreshViewerErrorMessage() {
    _viewerErrorMessage = null;
    for (final errors in _viewerListenerErrors.values) {
      if (errors.isNotEmpty) _viewerErrorMessage = errors.values.last;
    }
  }

  void _removeViewerConnection(String key) {
    _viewerAccess = _viewerAccess
        .where((entry) => _watchKey(entry.ownerUid, entry.deviceId) != key)
        .toList();
    _watchedLocations.remove(key);
    _watchedPresence.remove(key);
    _watchedSharingStates.remove(key);
    _clearViewerListenerErrorsForKey(key);
    unawaited(_deviceSubscriptions.remove(key)?.cancel());
    unawaited(_locationSubscriptions.remove(key)?.cancel());
    unawaited(_presenceSubscriptions.remove(key)?.cancel());
  }

  String _watchKey(String ownerUid, String deviceId) =>
      '${ownerUid}__$deviceId';

  bool isOwnInvitation(FamilyInvitation invitation) {
    final uid = _auth.currentUser?.uid;
    return uid != null && uid == invitation.ownerUid;
  }

  Future<void> refresh() async {
    try {
      await _refreshOwnDeviceState();
      await _refreshGrants(source: 'family_safety_refresh');
      await _refreshRequests(source: 'family_safety_refresh');
      await _refreshViewerAccess(source: 'family_safety_refresh');
      _errorMessage = null;
    } on FirebaseException catch (error) {
      _errorMessage = error.toString();
    } catch (error) {
      _errorMessage = error.toString();
    }
    notifyListeners();
  }

  Future<void> _refreshOwnDeviceState() async {
    final identity = _deviceIdentity;
    if (identity == null ||
        _auth.currentUser?.uid != identity.registeredOwnerUid) {
      return;
    }
    _presence = await _repository.readDeviceStatus(
      ownerUid: identity.registeredOwnerUid,
      deviceId: identity.deviceId,
      source: 'family_safety_refresh',
    );
    _currentLocation = await _repository.readCurrentLocation(
      ownerUid: identity.registeredOwnerUid,
      deviceId: identity.deviceId,
      source: 'family_safety_refresh',
    );
    _sharingState = _resolveSharingState(_presence);
  }

  Future<FamilyInvitation> createInvitation() async {
    final identity = _deviceIdentity;
    if (identity == null) {
      throw StateError('Device is not registered.');
    }
    final invitation = await _repository.createInvitation(
      deviceId: identity.deviceId,
      deviceNickname: identity.nickname,
    );
    _activeInvitation = invitation;
    notifyListeners();
    return invitation;
  }

  Future<FamilyInvitation> lookupInvitation(String code) async {
    return _repository.readInvitation(code);
  }

  Future<void> cancelInvitation(String invitationId) async {
    await _repository.cancelInvitation(invitationId);
    if (_activeInvitation?.invitationId == invitationId) {
      _activeInvitation = _activeInvitation!.copyWith(status: 'cancelled');
    }
    notifyListeners();
  }

  Future<bool> submitRequest({
    required FamilyInvitation invitation,
    required RelationshipType relationship,
  }) async {
    if (isOwnInvitation(invitation)) {
      throw FamilySafetyException(FamilySafetyErrorCode.selfInvitation);
    }
    final request = await _repository.submitConnectionRequest(
      invitation: invitation,
      relationship: relationship,
    );
    notifyListeners();
    return request.alreadyPending;
  }

  Future<void> approveRequest(ConnectionRequest request) async {
    final identity = _deviceIdentity;
    if (identity == null) return;
    await _repository.approveRequest(
      deviceId: identity.deviceId,
      request: request,
      relationship: request.relationship,
    );
    await _refreshGrants();
    await _refreshRequests();
    notifyListeners();
  }

  Future<void> rejectRequest(ConnectionRequest request) async {
    final identity = _deviceIdentity;
    if (identity == null) return;
    await _repository.rejectRequest(
      deviceId: identity.deviceId,
      request: request,
    );
    await _refreshRequests();
    notifyListeners();
  }

  Future<void> revokeViewer(String viewerUid) async {
    final identity = _deviceIdentity;
    if (identity == null) return;
    await _repository.revokeViewer(
      deviceId: identity.deviceId,
      viewerUid: viewerUid,
    );
    await _refreshGrants();
    notifyListeners();
  }

  Future<void> removeConnection(FamilyConnection connection) async {
    await _repository.revokeAccessAsViewer(
      ownerUid: connection.ownerUid,
      deviceId: connection.deviceId,
    );
    await _refreshViewerAccess(source: 'family_safety_refresh');
    notifyListeners();
  }

  Future<void> updateConnectionAlias(
    FamilyConnection connection,
    String alias,
  ) async {
    await _repository.updateViewerAlias(
      ownerUid: connection.ownerUid,
      deviceId: connection.deviceId,
      alias: alias,
    );
    await _refreshViewerAccess();
    notifyListeners();
  }

  SharingState _resolveSharingState(DevicePresenceStatus status) {
    switch (status.sharingState) {
      case SharingState.active:
        return SharingState.active;
      case SharingState.paused:
        return SharingState.paused;
      case SharingState.permissionDisabled:
        return SharingState.permissionDisabled;
      case SharingState.stopped:
        return SharingState.stopped;
      case SharingState.notConfigured:
        return SharingState.notConfigured;
    }
  }

  String _buildSessionId() {
    final now = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    return 'sess_$now';
  }

  @override
  void dispose() {
    _isDisposed = true;
    _initializationGeneration++;
    _syncRetryTimer?.cancel();
    _authStateSubscription?.cancel();
    _cancelFirestoreSubscriptions();
    _viewerListenerErrors.clear();
    _viewerErrorMessage = null;
    _watchedLocations.clear();
    _watchedPresence.clear();
    _watchedSharingStates.clear();
    super.dispose();
  }
}
