import 'dart:math' as math;

import 'package:battery_plus/battery_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DeviceIdentity {
  const DeviceIdentity({
    required this.deviceId,
    required this.nickname,
    required this.registeredOwnerUid,
  });

  final String deviceId;
  final String nickname;
  final String registeredOwnerUid;

  DeviceIdentity copyWith({String? nickname}) {
    return DeviceIdentity(
      deviceId: deviceId,
      nickname: nickname ?? this.nickname,
      registeredOwnerUid: registeredOwnerUid,
    );
  }

  String get shortLabel {
    if (deviceId.length <= 8) return deviceId.toUpperCase();
    return deviceId.substring(0, 8).toUpperCase();
  }
}

enum SharingState { notConfigured, stopped, paused, active, permissionDisabled }

enum LocationFreshness {
  fresh,
  stale,
  unavailable,
  paused,
  notConnected,
  notConfigured,
  permissionDisabled,
}

enum BatteryHealth { healthy, low, critical, unknown }

enum RelationshipType {
  parent,
  child,
  spouse,
  sibling,
  guardian,
  caregiver,
  friend,
  other,
}

class FamilyMemberProfile {
  const FamilyMemberProfile({
    required this.uid,
    required this.displayName,
    required this.email,
    this.relationship = RelationshipType.other,
  });

  final String uid;
  final String displayName;
  final String email;
  final RelationshipType relationship;

  static FamilyMemberProfile fromFirestore(
    Map<String, dynamic> data, {
    required String fallbackUid,
  }) {
    final rawRelationship = data['relationship'];
    final relationship = RelationshipType.values.firstWhere(
      (item) => item.name == rawRelationship,
      orElse: () => RelationshipType.other,
    );
    return FamilyMemberProfile(
      uid: fallbackUid,
      displayName: (data['displayName'] as String?)?.trim().isNotEmpty == true
          ? (data['displayName'] as String).trim()
          : 'Family member',
      email: (data['email'] as String?) ?? '',
      relationship: relationship,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'displayName': displayName,
      'email': email,
      'relationship': relationship.name,
    };
  }
}

class SharedLocationRecord {
  const SharedLocationRecord({
    required this.ownerUid,
    required this.deviceId,
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.capturedAt,
    required this.syncedAt,
    required this.batteryLevel,
    required this.isCharging,
    required this.sharingSessionId,
    this.addressLabel,
  });

  final String ownerUid;
  final String deviceId;
  final double latitude;
  final double longitude;
  final double accuracy;
  final DateTime capturedAt;
  final DateTime syncedAt;
  final int batteryLevel;
  final bool isCharging;
  final String sharingSessionId;
  final String? addressLabel;

  bool get hasValidCoordinates {
    return latitude.isFinite &&
        longitude.isFinite &&
        latitude >= -90 &&
        latitude <= 90 &&
        longitude >= -180 &&
        longitude <= 180;
  }

  SharedLocationRecord copyWith({
    double? latitude,
    double? longitude,
    double? accuracy,
    DateTime? capturedAt,
    DateTime? syncedAt,
    int? batteryLevel,
    bool? isCharging,
    String? sharingSessionId,
    String? addressLabel,
  }) {
    return SharedLocationRecord(
      ownerUid: ownerUid,
      deviceId: deviceId,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      accuracy: accuracy ?? this.accuracy,
      capturedAt: capturedAt ?? this.capturedAt,
      syncedAt: syncedAt ?? this.syncedAt,
      batteryLevel: batteryLevel ?? this.batteryLevel,
      isCharging: isCharging ?? this.isCharging,
      sharingSessionId: sharingSessionId ?? this.sharingSessionId,
      addressLabel: addressLabel ?? this.addressLabel,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'ownerUid': ownerUid,
      'deviceId': deviceId,
      'latitude': latitude,
      'longitude': longitude,
      'accuracy': accuracy,
      'capturedAt': Timestamp.fromDate(capturedAt.toUtc()),
      'batteryLevel': batteryLevel,
      'isCharging': isCharging,
      'sharingSessionId': sharingSessionId,
      if (addressLabel != null && addressLabel!.isNotEmpty)
        'addressLabel': addressLabel,
    };
  }

  static SharedLocationRecord? fromFirestore(
    Map<String, dynamic> data, {
    required String ownerUid,
    required String deviceId,
    DateTime? serverReceiptFallback,
  }) {
    final latitude = _toDouble(data['latitude']);
    final longitude = _toDouble(data['longitude']);
    if (latitude == null || longitude == null) return null;
    final accuracy = _toDouble(data['accuracy']) ?? 0;
    final capturedAt =
        _toDateTime(data['capturedAt']) ??
        serverReceiptFallback ??
        DateTime.now().toUtc();
    final syncedAt =
        _toDateTime(data['syncedAt']) ?? serverReceiptFallback ?? capturedAt;
    final battery = _toInt(data['batteryLevel']);
    return SharedLocationRecord(
      ownerUid: ownerUid,
      deviceId: deviceId,
      latitude: latitude,
      longitude: longitude,
      accuracy: accuracy,
      capturedAt: capturedAt,
      syncedAt: syncedAt,
      batteryLevel: battery ?? -1,
      isCharging: data['isCharging'] == true,
      sharingSessionId: (data['sharingSessionId'] as String?) ?? '',
      addressLabel: data['addressLabel'] as String?,
    );
  }

  static double? _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  static int? _toInt(dynamic value) {
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  static DateTime? _toDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value)?.toUtc();
    return null;
  }
}

class DevicePresenceStatus {
  const DevicePresenceStatus({
    required this.sharingState,
    required this.lastHeartbeat,
    required this.lastSuccessfulUpload,
    required this.permissionState,
    this.batteryLevel = -1,
    this.isCharging = false,
    this.batteryObservedAt,
  });

  final SharingState sharingState;
  final DateTime? lastHeartbeat;
  final DateTime? lastSuccessfulUpload;
  final String permissionState;
  final int batteryLevel;
  final bool isCharging;
  final DateTime? batteryObservedAt;

  bool get isSharingActive => sharingState == SharingState.active;

  static DevicePresenceStatus empty() {
    return const DevicePresenceStatus(
      sharingState: SharingState.notConfigured,
      lastHeartbeat: null,
      lastSuccessfulUpload: null,
      permissionState: 'unknown',
    );
  }

  DevicePresenceStatus copyWith({
    SharingState? sharingState,
    DateTime? lastHeartbeat,
    DateTime? lastSuccessfulUpload,
    String? permissionState,
    int? batteryLevel,
    bool? isCharging,
    DateTime? batteryObservedAt,
  }) {
    return DevicePresenceStatus(
      sharingState: sharingState ?? this.sharingState,
      lastHeartbeat: lastHeartbeat ?? this.lastHeartbeat,
      lastSuccessfulUpload: lastSuccessfulUpload ?? this.lastSuccessfulUpload,
      permissionState: permissionState ?? this.permissionState,
      batteryLevel: batteryLevel ?? this.batteryLevel,
      isCharging: isCharging ?? this.isCharging,
      batteryObservedAt: batteryObservedAt ?? this.batteryObservedAt,
    );
  }

  static DevicePresenceStatus fromFirestore(Map<String, dynamic> data) {
    final rawState = data['sharingState'];
    final sharingState = SharingState.values.firstWhere(
      (item) => item.name == rawState,
      orElse: () => SharingState.notConfigured,
    );
    return DevicePresenceStatus(
      sharingState: sharingState,
      lastHeartbeat: _toDateTime(data['lastHeartbeat']),
      lastSuccessfulUpload: _toDateTime(data['lastSuccessfulUpload']),
      permissionState: (data['permissionState'] as String?) ?? 'unknown',
      batteryLevel: _toInt(data['batteryLevel']) ?? -1,
      isCharging: data['isCharging'] == true,
      batteryObservedAt: _toDateTime(data['batteryObservedAt']),
    );
  }

  static DateTime? _toDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value)?.toUtc();
    return null;
  }

  static int? _toInt(dynamic value) {
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }
}

class AccessGrant {
  const AccessGrant({
    required this.viewerUid,
    required this.ownerUid,
    required this.deviceId,
    required this.grantedAt,
    required this.active,
    this.viewerDisplayName,
    this.viewerEmail,
    this.relationship = RelationshipType.other,
  });

  final String viewerUid;
  final String ownerUid;
  final String deviceId;
  final DateTime grantedAt;
  final bool active;
  final String? viewerDisplayName;
  final String? viewerEmail;
  final RelationshipType relationship;

  AccessGrant copyWith({
    bool? active,
    String? viewerDisplayName,
    String? viewerEmail,
    RelationshipType? relationship,
  }) {
    return AccessGrant(
      viewerUid: viewerUid,
      ownerUid: ownerUid,
      deviceId: deviceId,
      grantedAt: grantedAt,
      active: active ?? this.active,
      viewerDisplayName: viewerDisplayName ?? this.viewerDisplayName,
      viewerEmail: viewerEmail ?? this.viewerEmail,
      relationship: relationship ?? this.relationship,
    );
  }

  static AccessGrant fromFirestore(
    Map<String, dynamic> data, {
    required String ownerUid,
    required String deviceId,
    required String viewerUid,
  }) {
    final rawRelationship = data['relationship'];
    final relationship = RelationshipType.values.firstWhere(
      (item) => item.name == rawRelationship,
      orElse: () => RelationshipType.other,
    );
    return AccessGrant(
      viewerUid: viewerUid,
      ownerUid: ownerUid,
      deviceId: deviceId,
      grantedAt: _toDateTime(data['grantedAt']) ?? DateTime.now().toUtc(),
      active: data['active'] != false,
      viewerDisplayName: data['viewerDisplayName'] as String?,
      viewerEmail: data['viewerEmail'] as String?,
      relationship: relationship,
    );
  }

  static DateTime? _toDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value)?.toUtc();
    return null;
  }
}

class FamilyInvitation {
  const FamilyInvitation({
    required this.invitationId,
    required this.ownerUid,
    required this.ownerDisplayName,
    required this.createdAt,
    required this.expiresAt,
    required this.status,
    this.deviceId,
    this.deviceNickname,
    this.requestedCapabilities = const <String>[],
  });

  final String invitationId;
  final String ownerUid;
  final String ownerDisplayName;
  final DateTime createdAt;
  final DateTime expiresAt;
  final String status;
  final String? deviceId;
  final String? deviceNickname;
  final List<String> requestedCapabilities;

  bool get isExpired => DateTime.now().toUtc().isAfter(expiresAt);

  bool get isOpen => status == 'open' && !isExpired;

  int get remainingMinutes {
    final remaining = expiresAt.difference(DateTime.now().toUtc());
    if (remaining.isNegative) return 0;
    return remaining.inMinutes;
  }

  FamilyInvitation copyWith({String? status}) {
    return FamilyInvitation(
      invitationId: invitationId,
      ownerUid: ownerUid,
      ownerDisplayName: ownerDisplayName,
      createdAt: createdAt,
      expiresAt: expiresAt,
      status: status ?? this.status,
      deviceId: deviceId,
      deviceNickname: deviceNickname,
      requestedCapabilities: requestedCapabilities,
    );
  }

  static FamilyInvitation fromFirestore(
    Map<String, dynamic> data, {
    required String invitationId,
  }) {
    final rawCapabilities = data['requestedCapabilities'];
    final capabilities = rawCapabilities is List
        ? rawCapabilities.map((item) => item.toString()).toList()
        : const <String>[];
    return FamilyInvitation(
      invitationId: invitationId,
      ownerUid: (data['ownerUid'] as String?) ?? '',
      ownerDisplayName: familyPersonLabel(
        displayName: data['ownerDisplayName'],
        email: data['ownerEmail'],
        fallback: 'AmarGuard user',
      ),
      createdAt: _toDateTime(data['createdAt']) ?? DateTime.now().toUtc(),
      expiresAt: _toDateTime(data['expiresAt']) ?? DateTime.now().toUtc(),
      status: (data['status'] as String?) ?? 'open',
      deviceId: data['deviceId'] as String?,
      deviceNickname: data['deviceNickname'] as String?,
      requestedCapabilities: capabilities,
    );
  }

  static DateTime? _toDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value)?.toUtc();
    return null;
  }
}

String familyPersonLabel({
  dynamic displayName,
  dynamic email,
  String fallback = 'Family member',
}) {
  final name = displayName is String ? displayName.trim() : '';
  if (name.isNotEmpty) return name;
  final mail = email is String ? email.trim() : '';
  if (mail.isNotEmpty) return mail;
  return fallback;
}

class ConnectionRequest {
  const ConnectionRequest({
    required this.viewerUid,
    required this.invitationId,
    required this.ownerUid,
    required this.viewerDisplayName,
    required this.viewerEmail,
    required this.requestedAt,
    required this.status,
    this.deviceId,
    this.relationship = RelationshipType.other,
    this.requestedCapabilities = const <String>[],
    this.alreadyPending = false,
  });

  final String viewerUid;
  final String invitationId;
  final String ownerUid;
  final String viewerDisplayName;
  final String viewerEmail;
  final String? deviceId;
  final DateTime? requestedAt;
  final String status;
  final RelationshipType relationship;
  final List<String> requestedCapabilities;
  final bool alreadyPending;

  bool get isPending => status == 'pending';

  static ConnectionRequest fromFirestore(
    Map<String, dynamic> data, {
    required String viewerUid,
    required String invitationId,
    required String ownerUid,
    bool alreadyPending = false,
  }) {
    final rawRelationship = data['relationship'];
    final relationship = RelationshipType.values.firstWhere(
      (item) => item.name == rawRelationship,
      orElse: () => RelationshipType.other,
    );
    final rawCapabilities = data['requestedCapabilities'];
    final capabilities = rawCapabilities is List
        ? rawCapabilities.map((item) => item.toString()).toList()
        : const <String>[];
    return ConnectionRequest(
      viewerUid: viewerUid,
      invitationId: invitationId,
      ownerUid: ownerUid,
      viewerDisplayName: familyPersonLabel(
        displayName: data['viewerDisplayName'],
        email: data['viewerEmail'],
      ),
      viewerEmail: (data['viewerEmail'] as String?) ?? '',
      deviceId: data['deviceId'] as String?,
      requestedAt: _toDateTime(data['requestedAt']),
      status: (data['status'] as String?) ?? 'pending',
      relationship: relationship,
      requestedCapabilities: capabilities,
      alreadyPending: alreadyPending,
    );
  }

  static DateTime? _toDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value)?.toUtc();
    return null;
  }
}

class FamilyConnection {
  const FamilyConnection({
    required this.ownerUid,
    required this.deviceId,
    required this.grant,
    this.location,
    this.presence,
    this.ownerDisplayName,
    this.deviceNickname,
    this.alias,
  });

  final String ownerUid;
  final String deviceId;
  final AccessGrant grant;
  final SharedLocationRecord? location;
  final DevicePresenceStatus? presence;
  final String? ownerDisplayName;
  final String? deviceNickname;
  final String? alias;

  bool get isActive => grant.active;

  String get memberKey => '${ownerUid}__$deviceId';

  String get viewerDisplayName => alias?.trim().isNotEmpty == true
      ? alias!.trim()
      : grant.viewerDisplayName?.trim().isNotEmpty == true
      ? grant.viewerDisplayName!.trim()
      : (ownerDisplayName?.trim().isNotEmpty == true
            ? ownerDisplayName!.trim()
            : 'Family member');

  String get viewerEmail => grant.viewerEmail ?? '';

  LocationFreshness get freshness {
    final state = presence?.sharingState ?? SharingState.notConfigured;
    if (state == SharingState.paused) return LocationFreshness.paused;
    if (state == SharingState.stopped) return LocationFreshness.notConnected;
    if (state == SharingState.permissionDisabled) {
      return LocationFreshness.permissionDisabled;
    }
    if (location == null) {
      return state == SharingState.active
          ? LocationFreshness.unavailable
          : LocationFreshness.notConfigured;
    }
    if (!isActive) return LocationFreshness.notConnected;
    return LocationFreshnessEvaluator.evaluate(
      capturedAt: location!.capturedAt,
      syncedAt: location!.syncedAt,
      now: DateTime.now().toUtc(),
    );
  }
}

class LocationFreshnessEvaluator {
  LocationFreshnessEvaluator._();

  static const Duration freshWindow = Duration(minutes: 5);
  static const Duration staleWindow = Duration(minutes: 30);
  static const Duration unavailableWindow = Duration(hours: 6);

  static LocationFreshness evaluate({
    required DateTime capturedAt,
    required DateTime syncedAt,
    required DateTime now,
  }) {
    final reference = capturedAt.isBefore(syncedAt) ? capturedAt : syncedAt;
    final age = now.difference(reference);
    if (age <= freshWindow) return LocationFreshness.fresh;
    if (age <= staleWindow) return LocationFreshness.stale;
    return LocationFreshness.unavailable;
  }
}

class BatteryAssessment {
  const BatteryAssessment({
    required this.level,
    required this.state,
    required this.observedAt,
  });

  final int level;
  final BatteryState state;
  final DateTime observedAt;

  bool get isCharging =>
      state == BatteryState.charging || state == BatteryState.full;

  bool get hasKnownLevel => level >= 0 && level <= 100;

  BatteryHealth get health {
    if (!hasKnownLevel) return BatteryHealth.unknown;
    if (level <= 5) return BatteryHealth.critical;
    if (level <= 20) return BatteryHealth.low;
    return BatteryHealth.healthy;
  }

  BatteryAssessment copyWith({
    int? level,
    BatteryState? state,
    DateTime? observedAt,
  }) {
    return BatteryAssessment(
      level: level ?? this.level,
      state: state ?? this.state,
      observedAt: observedAt ?? this.observedAt,
    );
  }
}

class LocationValidation {
  LocationValidation._();

  static const double maxPlausibleAccuracy = 50000;

  static bool isValid({
    required double latitude,
    required double longitude,
    required double accuracy,
    required DateTime capturedAt,
  }) {
    if (!latitude.isFinite || !longitude.isFinite || !accuracy.isFinite) {
      return false;
    }
    if (latitude < -90 || latitude > 90) return false;
    if (longitude < -180 || longitude > 180) return false;
    if (accuracy < 0 || accuracy > maxPlausibleAccuracy) return false;
    if (capturedAt.millisecondsSinceEpoch <= 0) return false;
    return true;
  }

  static double distanceMeters({
    required double startLatitude,
    required double startLongitude,
    required double endLatitude,
    required double endLongitude,
  }) {
    const earthRadius = 6371000.0;
    final lat1 = startLatitude * math.pi / 180;
    final lat2 = endLatitude * math.pi / 180;
    final deltaLat = (endLatitude - startLatitude) * math.pi / 180;
    final deltaLon = (endLongitude - startLongitude) * math.pi / 180;
    final a =
        math.sin(deltaLat / 2) * math.sin(deltaLat / 2) +
        math.cos(lat1) *
            math.cos(lat2) *
            math.sin(deltaLon / 2) *
            math.sin(deltaLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadius * c;
  }
}
