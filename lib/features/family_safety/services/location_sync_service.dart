import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/family_models.dart';
import 'battery_service.dart';
import 'family_firestore_diagnostics.dart';
import 'family_paths.dart';
import 'family_repository.dart';
import 'location_provider.dart';

class SharingSyncResult {
  const SharingSyncResult({
    required this.accepted,
    required this.record,
    this.reason,
  });

  final bool accepted;
  final SharedLocationRecord record;
  final String? reason;
}

class LocationSyncService {
  LocationSyncService({
    required this._repository,
    required this._batteryService,
  });

  final FamilyRepository _repository;
  final BatteryService _batteryService;

  static const double minimumMovementMeters = 20;

  SharedLocationRecord? _lastAccepted;

  SharedLocationRecord? get lastAccepted => _lastAccepted;

  void seedLastAccepted(SharedLocationRecord? record) {
    _lastAccepted = record;
  }

  Future<SharingSyncResult> publish({
    required String ownerUid,
    required String deviceId,
    required AcquiredLocation location,
    required String sharingSessionId,
  }) async {
    if (!LocationValidation.isValid(
      latitude: location.latitude,
      longitude: location.longitude,
      accuracy: location.accuracy,
      capturedAt: location.capturedAt,
    )) {
      return SharingSyncResult(
        accepted: false,
        record:
            _lastAccepted ??
            SharedLocationRecord(
              ownerUid: ownerUid,
              deviceId: deviceId,
              latitude: location.latitude,
              longitude: location.longitude,
              accuracy: location.accuracy,
              capturedAt: location.capturedAt,
              syncedAt: DateTime.now().toUtc(),
              batteryLevel: -1,
              isCharging: false,
              sharingSessionId: sharingSessionId,
            ),
        reason: 'invalid_coordinates',
      );
    }

    final previous = _lastAccepted;
    if (previous != null) {
      if (!location.capturedAt.isAfter(previous.capturedAt)) {
        return SharingSyncResult(
          accepted: false,
          record: previous,
          reason: 'out_of_order',
        );
      }
      final moved = LocationValidation.distanceMeters(
        startLatitude: previous.latitude,
        startLongitude: previous.longitude,
        endLatitude: location.latitude,
        endLongitude: location.longitude,
      );
      final elapsed = location.capturedAt.difference(previous.capturedAt);
      if (moved < minimumMovementMeters &&
          elapsed < const Duration(minutes: 2)) {
        return SharingSyncResult(
          accepted: false,
          record: previous,
          reason: 'insufficient_movement',
        );
      }
    }

    final battery = await _batteryService.read();
    final record = SharedLocationRecord(
      ownerUid: ownerUid,
      deviceId: deviceId,
      latitude: location.latitude,
      longitude: location.longitude,
      accuracy: location.accuracy,
      capturedAt: location.capturedAt,
      syncedAt: DateTime.now().toUtc(),
      batteryLevel: battery.level,
      isCharging: battery.isCharging,
      sharingSessionId: sharingSessionId,
    );

    final locationDoc = FamilyPaths.locationDoc(ownerUid, deviceId);
    final statusDoc = FamilyPaths.statusDoc(ownerUid, deviceId);
    final batch = _repositoryFirestoreBatch();

    batch.set(locationDoc, {
      ...record.toFirestore(),
      'syncedAt': FieldValue.serverTimestamp(),
    });
    batch.set(statusDoc, {
      'sharingState': SharingState.active.name,
      'lastHeartbeat': FieldValue.serverTimestamp(),
      'lastSuccessfulUpload': FieldValue.serverTimestamp(),
      'permissionState': 'granted',
      'batteryLevel': battery.level,
      'isCharging': battery.isCharging,
      'batteryObservedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    try {
      await batch.commit();
    } on FirebaseException catch (error) {
      FamilyFirestoreDiagnostics.logFailure(
        operation: 'batch_write',
        path: 'users/<uid>/devices/<device>/{location/current,status/current}',
        sharingState: SharingState.active.name,
        role: 'owner',
        source: 'background_location_sync',
        error: error,
      );
      rethrow;
    }
    _lastAccepted = record;
    return SharingSyncResult(accepted: true, record: record);
  }

  Future<void> publishStatus({
    required String ownerUid,
    required String deviceId,
    required SharingState state,
    required String permissionState,
  }) async {
    final batch = _repositoryFirestoreBatch();
    batch.set(FamilyPaths.statusDoc(ownerUid, deviceId), {
      'sharingState': state.name,
      'lastHeartbeat': FieldValue.serverTimestamp(),
      'permissionState': permissionState,
    }, SetOptions(merge: true));
    try {
      await batch.commit();
    } on FirebaseException catch (error) {
      FamilyFirestoreDiagnostics.logFailure(
        operation: 'batch_write',
        path: 'users/<uid>/devices/<device>/status/current',
        sharingState: state.name,
        role: 'owner',
        source: 'sharing_state_transition',
        error: error,
      );
      rethrow;
    }
  }

  WriteBatch _repositoryFirestoreBatch() => _repository.firestore.batch();
}
