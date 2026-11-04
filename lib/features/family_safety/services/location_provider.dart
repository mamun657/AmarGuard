import 'dart:async';

import 'package:geolocator/geolocator.dart';

class AcquiredLocation {
  const AcquiredLocation({
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.capturedAt,
    required this.altitude,
    required this.speed,
  });

  final double latitude;
  final double longitude;
  final double accuracy;
  final DateTime capturedAt;
  final double altitude;
  final double speed;
}

enum LocationServiceState {
  ready,
  serviceDisabled,
  permissionDenied,
  permissionDeniedForever,
  permissionLimited,
  unavailable,
}

class LocationServiceException implements Exception {
  const LocationServiceException(this.state, this.cause);

  final LocationServiceState state;
  final Object? cause;

  @override
  String toString() => 'LocationServiceException(${state.name})';
}

abstract class LocationProvider {
  Future<bool> isServiceEnabled();

  Future<LocationPermission> checkPermission();

  Future<LocationPermission> requestPermission();

  Future<LocationAccuracyStatus> accuracyStatus();

  Future<AcquiredLocation> currentPosition({
    required Duration timeLimit,
  });

  Stream<AcquiredLocation> positionStream({
    required Duration interval,
    required double distanceFilter,
    required bool highAccuracy,
  });

  Future<bool> openLocationSettings();

  Future<bool> openAppSettings();
}

class GeolocatorLocationProvider implements LocationProvider {
  const GeolocatorLocationProvider();

  @override
  Future<bool> isServiceEnabled() => Geolocator.isLocationServiceEnabled();

  @override
  Future<LocationPermission> checkPermission() => Geolocator.checkPermission();

  @override
  Future<LocationPermission> requestPermission() =>
      Geolocator.requestPermission();

  @override
  Future<LocationAccuracyStatus> accuracyStatus() =>
      Geolocator.getLocationAccuracy();

  @override
  Future<AcquiredLocation> currentPosition({required Duration timeLimit}) async {
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: AndroidSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: timeLimit,
        ),
      );
      return _toAcquired(position);
    } on TimeoutException catch (error) {
      throw LocationServiceException(
        LocationServiceState.unavailable,
        error,
      );
    } on LocationServiceDisabledException catch (error) {
      throw LocationServiceException(
        LocationServiceState.serviceDisabled,
        error,
      );
    } on PermissionDeniedException catch (error) {
      throw LocationServiceException(
        LocationServiceState.permissionDenied,
        error,
      );
    } catch (error) {
      throw LocationServiceException(
        LocationServiceState.unavailable,
        error,
      );
    }
  }

  @override
  Stream<AcquiredLocation> positionStream({
    required Duration interval,
    required double distanceFilter,
    required bool highAccuracy,
  }) {
    final settings = AndroidSettings(
      accuracy: highAccuracy
          ? LocationAccuracy.high
          : LocationAccuracy.medium,
      distanceFilter: distanceFilter.round(),
      intervalDuration: interval,
      forceLocationManager: false,
    );
    return Geolocator.getPositionStream(locationSettings: settings).map(
      _toAcquired,
    );
  }

  @override
  Future<bool> openLocationSettings() => Geolocator.openLocationSettings();

  @override
  Future<bool> openAppSettings() => Geolocator.openAppSettings();

  AcquiredLocation _toAcquired(Position position) {
    return AcquiredLocation(
      latitude: position.latitude,
      longitude: position.longitude,
      accuracy: position.accuracy,
      capturedAt: position.timestamp.toUtc(),
      altitude: position.altitude,
      speed: position.speed,
    );
  }
}
