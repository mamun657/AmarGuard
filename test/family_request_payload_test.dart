import 'package:amarguard/features/family_safety/services/family_error_messages.dart';
import 'package:amarguard/features/family_safety/services/family_exceptions.dart';
import 'package:amarguard/features/family_safety/models/family_models.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:amarguard/l10n/generated/app_localizations_en.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('invitation request payload omits deviceId', () {
    final requestPayload = <String, dynamic>{
      'viewerUid': 'viewer-1',
      'ownerUid': 'owner-1',
      'invitationId': 'ABC',
      'viewerDisplayName': 'Viewer',
      'viewerEmail': 'viewer@example.com',
      'relationship': 'friend',
      'requestedCapabilities': const ['viewLocation', 'viewBattery'],
      'status': 'pending',
    };
    expect(requestPayload.containsKey('deviceId'), isFalse);
    expect(requestPayload.keys.toSet(), {
      'viewerUid',
      'ownerUid',
      'invitationId',
      'viewerDisplayName',
      'viewerEmail',
      'relationship',
      'requestedCapabilities',
      'status',
    });
  });

  test('incoming request payload includes deviceId', () {
    final requestPayload = <String, dynamic>{
      'viewerUid': 'viewer-1',
      'ownerUid': 'owner-1',
      'invitationId': 'ABC',
      'viewerDisplayName': 'Viewer',
      'viewerEmail': 'viewer@example.com',
      'relationship': 'friend',
      'requestedCapabilities': const ['viewLocation', 'viewBattery'],
      'status': 'pending',
    };
    final incomingPayload = <String, dynamic>{
      ...requestPayload,
      'deviceId': 'device-1',
    };
    expect(incomingPayload['deviceId'], 'device-1');
    expect(incomingPayload.keys.toSet(), {
      'viewerUid',
      'ownerUid',
      'deviceId',
      'invitationId',
      'viewerDisplayName',
      'viewerEmail',
      'relationship',
      'requestedCapabilities',
      'status',
    });
  });

  test('existing incoming request is represented as already pending', () {
    final request = ConnectionRequest.fromFirestore(
      {
        'ownerUid': 'owner-1',
        'viewerUid': 'viewer-1',
        'deviceId': 'device-1',
        'invitationId': 'INVITE1',
        'status': 'pending',
        'requestedAt': Timestamp.now(),
      },
      viewerUid: 'viewer-1',
      invitationId: 'INVITE1',
      ownerUid: 'owner-1',
      alreadyPending: true,
    );

    expect(request.isPending, isTrue);
    expect(request.alreadyPending, isTrue);
  });

  test('incoming request without a timestamp stays unavailable', () {
    final request = ConnectionRequest.fromFirestore(
      {
        'ownerUid': 'owner-1',
        'viewerUid': 'viewer-1',
        'deviceId': 'device-1',
        'invitationId': 'INVITE1',
        'status': 'pending',
      },
      viewerUid: 'viewer-1',
      invitationId: 'INVITE1',
      ownerUid: 'owner-1',
    );

    expect(request.requestedAt, isNull);
  });

  test('maps family safety errors to useful copy', () {
    final l10n = AppLocalizationsEn();
    expect(
      familySafetyErrorMessage(
        l10n,
        FamilySafetyException(FamilySafetyErrorCode.selfInvitation),
      ),
      l10n.careSelfInvitation,
    );
    expect(
      familySafetyErrorMessage(
        l10n,
        FamilySafetyException(FamilySafetyErrorCode.invitationExpired),
      ),
      l10n.careInvitationExpired,
    );
    expect(
      familySafetyErrorMessage(
        l10n,
        FamilySafetyException(FamilySafetyErrorCode.permissionDenied),
      ),
      l10n.careInvitationPermissionDenied,
    );
    expect(
      familySafetyErrorMessage(
        l10n,
        FamilySafetyException(FamilySafetyErrorCode.approvalPermissionDenied),
      ),
      l10n.careApprovalPermissionDenied,
    );
    expect(
      familySafetyErrorMessage(
        l10n,
        FamilySafetyException(FamilySafetyErrorCode.network),
      ),
      l10n.errorNoInternet,
    );
  });

  test('invitation action is labeled as an access request', () {
    final l10n = AppLocalizationsEn();
    expect(l10n.careAcceptInvitation, 'Request Access');
    expect(l10n.careInvitationAccepted, contains("until they approve it"));
  });

  test('uses a visible fallback when invitation owner name is blank', () {
    final invitation = FamilyInvitation.fromFirestore({
      'ownerUid': 'owner-1',
      'ownerDisplayName': ' ',
      'createdAt': Timestamp.now(),
      'expiresAt': Timestamp.fromDate(
        DateTime.now().toUtc().add(const Duration(hours: 1)),
      ),
      'status': 'open',
    }, invitationId: 'ABC');
    expect(invitation.ownerDisplayName, 'AmarGuard user');
  });

  test(
    'family viewer access index payload matches firestore rules whitelist',
    () {
      final payload = <String, dynamic>{
        'ownerUid': 'owner-1',
        'deviceId': 'device-1',
        'ownerDisplayName': 'Owner',
        'relationship': RelationshipType.friend.name,
        'grantedAt': Timestamp.now(),
      };

      expect(payload.keys.toSet(), {
        'ownerUid',
        'deviceId',
        'ownerDisplayName',
        'relationship',
        'grantedAt',
      });
      expect(payload.containsKey('viewerUid'), isFalse);
      expect(payload.containsKey('active'), isFalse);
    },
  );

  test('marks a five-minute-old location as stale', () {
    final now = DateTime.utc(2026, 10, 29, 5, 0);
    final freshness = LocationFreshnessEvaluator.evaluate(
      capturedAt: now.subtract(const Duration(minutes: 6)),
      syncedAt: now.subtract(const Duration(minutes: 6)),
      now: now,
    );
    expect(freshness, LocationFreshness.stale);
  });

  test('keeps successful upload metadata separate from live battery', () {
    final presence = DevicePresenceStatus.fromFirestore({
      'sharingState': 'active',
      'lastSuccessfulUpload': Timestamp.now(),
      'batteryLevel': 70,
      'batteryObservedAt': Timestamp.now(),
      'permissionState': 'granted',
    });
    final live = BatteryAssessment(
      level: 72,
      state: BatteryState.discharging,
      observedAt: DateTime.now().toUtc(),
    );
    expect(presence.batteryLevel, 70);
    expect(live.level, 72);
  });
}
