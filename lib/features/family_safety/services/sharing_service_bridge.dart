import 'package:flutter/services.dart';

class SharingServiceStatus {
  const SharingServiceStatus({
    required this.isRunning,
    this.lastLatitude,
    this.lastLongitude,
    this.lastAccuracy,
    this.lastCapturedAt,
    this.sessionId,
    this.lastError,
  });

  final bool isRunning;
  final double? lastLatitude;
  final double? lastLongitude;
  final double? lastAccuracy;
  final DateTime? lastCapturedAt;
  final String? sessionId;
  final String? lastError;

  static const SharingServiceStatus unknown = SharingServiceStatus(isRunning: false);

  factory SharingServiceStatus.fromMap(Map<Object?, Object?> map) {
    final timestamp = map['capturedAt'];
    return SharingServiceStatus(
      isRunning: map['running'] == true,
      lastLatitude: (map['latitude'] as num?)?.toDouble(),
      lastLongitude: (map['longitude'] as num?)?.toDouble(),
      lastAccuracy: (map['accuracy'] as num?)?.toDouble(),
      lastCapturedAt: timestamp is int
          ? DateTime.fromMillisecondsSinceEpoch(timestamp, isUtc: true)
          : null,
      sessionId: map['sessionId'] as String?,
      lastError: map['error'] as String?,
    );
  }
}

class SharingServiceBridge {
  SharingServiceBridge({MethodChannel? channel})
      : _channel = channel ?? const MethodChannel(channelName);

  static const String channelName = 'com.binarypulse.amarguard/sharing_service';

  final MethodChannel _channel;

  Future<bool> start({
    required String sessionId,
    required int intervalSeconds,
    required int distanceFilterMeters,
  }) async {
    final result = await _channel.invokeMethod<bool>('startService', {
      'sessionId': sessionId,
      'intervalSeconds': intervalSeconds,
      'distanceFilterMeters': distanceFilterMeters,
    });
    return result ?? false;
  }

  Future<bool> pause() async {
    final result = await _channel.invokeMethod<bool>('pauseService');
    return result ?? false;
  }

  Future<bool> resume({required String sessionId}) async {
    final result = await _channel.invokeMethod<bool>('resumeService', {
      'sessionId': sessionId,
    });
    return result ?? false;
  }

  Future<bool> stop() async {
    final result = await _channel.invokeMethod<bool>('stopService');
    return result ?? false;
  }

  Future<SharingServiceStatus> status() async {
    final map = await _channel.invokeMapMethod<Object?, Object?>('status');
    if (map == null) return SharingServiceStatus.unknown;
    return SharingServiceStatus.fromMap(map);
  }

  Future<bool> openNotificationSettings() async {
    final result = await _channel.invokeMethod<bool>('openNotificationSettings');
    return result ?? false;
  }
}

class SharingLocationUpdate {
  const SharingLocationUpdate({
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.capturedAt,
    required this.sessionId,
  });

  final double latitude;
  final double longitude;
  final double accuracy;
  final DateTime capturedAt;
  final String sessionId;

  static SharingLocationUpdate? fromMap(Map<Object?, Object?> map) {
    final latitude = (map['latitude'] as num?)?.toDouble();
    final longitude = (map['longitude'] as num?)?.toDouble();
    final accuracy = (map['accuracy'] as num?)?.toDouble() ?? 0;
    final timestamp = map['capturedAt'];
    if (latitude == null || longitude == null) return null;
    return SharingLocationUpdate(
      latitude: latitude,
      longitude: longitude,
      accuracy: accuracy,
      capturedAt: timestamp is int
          ? DateTime.fromMillisecondsSinceEpoch(timestamp, isUtc: true)
          : DateTime.now().toUtc(),
      sessionId: (map['sessionId'] as String?) ?? '',
    );
  }
}

class SharingServiceChannel {
  SharingServiceChannel({EventChannel? channel})
      : _channel = channel ?? const EventChannel(
          'com.binarypulse.amarguard/sharing_service_events',
        );

  final EventChannel _channel;

  Stream<SharingLocationUpdate> updates() {
    return _channel.receiveBroadcastStream().map((event) {
      if (event is Map) {
        return SharingLocationUpdate.fromMap(event.cast<Object?, Object?>());
      }
      return null;
    }).where((update) => update != null).cast<SharingLocationUpdate>();
  }
}
