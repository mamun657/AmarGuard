import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/family_models.dart';
import 'family_exceptions.dart';
import 'family_firestore_diagnostics.dart';
import 'family_paths.dart';
import 'secure_token.dart';

class FamilyRepository {
  FamilyRepository(this._firestore, this._auth);

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  FirebaseFirestore get firestore => _firestore;

  static const Duration invitationLifetime = Duration(hours: 48);

  String get _uid {
    final user = _auth.currentUser;
    if (user == null) {
      throw FamilySafetyException(FamilySafetyErrorCode.unauthenticated);
    }
    return user.uid;
  }

  bool get isSignedIn => _auth.currentUser != null;

  Future<void> registerDevice({
    required String deviceId,
    required String nickname,
  }) async {
    final ownerUid = _uid;
    try {
      final doc = FamilyPaths.deviceDoc(ownerUid, deviceId);
      final existing = await doc.get();
      if (!existing.exists) {
        await doc.set({
          'ownerUid': ownerUid,
          'deviceId': deviceId,
          'nickname': nickname,
          'sharingState': SharingState.stopped.name,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        return;
      }
      await doc.set({
        'nickname': nickname,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } on FirebaseException catch (error) {
      FamilyFirestoreDiagnostics.logFailure(
        operation: 'get_or_set',
        path: 'users/<uid>/devices/<device>',
        sharingState: 'unknown',
        role: 'owner',
        source: 'device_registration',
        error: error,
      );
      rethrow;
    }
  }

  Future<void> updateDeviceNickname({
    required String deviceId,
    required String nickname,
  }) async {
    await FamilyPaths.deviceDoc(_uid, deviceId).set({
      'nickname': nickname,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> setDeviceSharingState({
    required String deviceId,
    required SharingState state,
  }) async {
    try {
      await FamilyPaths.deviceDoc(_uid, deviceId).set({
        'sharingState': state.name,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } on FirebaseException catch (error) {
      FamilyFirestoreDiagnostics.logFailure(
        operation: 'set',
        path: 'users/<uid>/devices/<device>',
        sharingState: state.name,
        role: 'owner',
        source: 'sharing_state_transition',
        error: error,
      );
      rethrow;
    }
  }

  Future<DevicePresenceStatus> readDeviceStatus({
    required String ownerUid,
    required String deviceId,
    String source = 'family_safety_initialize',
  }) async {
    try {
      final snapshot = await FamilyPaths.statusDoc(ownerUid, deviceId).get();
      if (!snapshot.exists) return DevicePresenceStatus.empty();
      final data = snapshot.data();
      if (data == null) return DevicePresenceStatus.empty();
      return DevicePresenceStatus.fromFirestore(data);
    } on FirebaseException catch (error) {
      FamilyFirestoreDiagnostics.logFailure(
        operation: 'get',
        path: 'users/<uid>/devices/<device>/status/current',
        sharingState: 'unknown',
        role: _auth.currentUser?.uid == ownerUid ? 'owner' : 'viewer',
        source: source,
        error: error,
      );
      rethrow;
    }
  }

  Stream<SharingState?> watchDeviceSharingState({
    required String ownerUid,
    required String deviceId,
  }) {
    return FamilyPaths.deviceDoc(ownerUid, deviceId).snapshots().map((
      snapshot,
    ) {
      if (!snapshot.exists) return null;
      final rawState = snapshot.data()?['sharingState'];
      return SharingState.values.firstWhere(
        (state) => state.name == rawState,
        orElse: () => SharingState.notConfigured,
      );
    });
  }

  Future<SharingState?> readDeviceSharingState({
    required String ownerUid,
    required String deviceId,
    String source = 'viewer_authorization_check',
    bool logFailures = true,
  }) async {
    try {
      final snapshot = await FamilyPaths.deviceDoc(ownerUid, deviceId).get();
      if (!snapshot.exists) return null;
      final rawState = snapshot.data()?['sharingState'];
      return SharingState.values.firstWhere(
        (state) => state.name == rawState,
        orElse: () => SharingState.notConfigured,
      );
    } on FirebaseException catch (error) {
      if (logFailures) {
        FamilyFirestoreDiagnostics.logFailure(
          operation: 'get',
          path: 'users/<uid>/devices/<device>',
          sharingState: 'unknown',
          role: 'viewer',
          source: source,
          error: error,
        );
      }
      rethrow;
    }
  }

  Future<bool> hasViewerAccessEntry({
    required String ownerUid,
    required String deviceId,
    String source = 'viewer_revocation_check',
  }) async {
    final viewerUid = _uid;
    try {
      final snapshot = await _firestore
          .collection('familyViewerAccess')
          .doc(viewerUid)
          .collection('grants')
          .doc(_viewerIndexId(ownerUid, deviceId))
          .get();
      return snapshot.exists;
    } on FirebaseException catch (error) {
      FamilyFirestoreDiagnostics.logFailure(
        operation: 'get',
        path: 'familyViewerAccess/<uid>/grants/<owner>__<device>',
        sharingState: 'unknown',
        role: 'viewer',
        source: source,
        error: error,
      );
      rethrow;
    }
  }

  Stream<SharedLocationRecord?> watchCurrentLocation({
    required String ownerUid,
    required String deviceId,
  }) {
    return FamilyPaths.locationDoc(ownerUid, deviceId).snapshots().map((
      snapshot,
    ) {
      final data = snapshot.data();
      if (!snapshot.exists || data == null) return null;
      return SharedLocationRecord.fromFirestore(
        data,
        ownerUid: ownerUid,
        deviceId: deviceId,
        serverReceiptFallback: snapshot.metadata.hasPendingWrites ? null : null,
      );
    });
  }

  Stream<DevicePresenceStatus> watchDeviceStatus({
    required String ownerUid,
    required String deviceId,
  }) {
    return FamilyPaths.statusDoc(ownerUid, deviceId).snapshots().map((
      snapshot,
    ) {
      final data = snapshot.data();
      if (!snapshot.exists || data == null) return DevicePresenceStatus.empty();
      return DevicePresenceStatus.fromFirestore(data);
    });
  }

  Future<SharedLocationRecord?> readCurrentLocation({
    required String ownerUid,
    required String deviceId,
    String source = 'family_safety_initialize',
  }) async {
    try {
      final snapshot = await FamilyPaths.locationDoc(ownerUid, deviceId).get();
      final data = snapshot.data();
      if (!snapshot.exists || data == null) return null;
      return SharedLocationRecord.fromFirestore(
        data,
        ownerUid: ownerUid,
        deviceId: deviceId,
        serverReceiptFallback: null,
      );
    } on FirebaseException catch (error) {
      FamilyFirestoreDiagnostics.logFailure(
        operation: 'get',
        path: 'users/<uid>/devices/<device>/location/current',
        sharingState: 'unknown',
        role: _auth.currentUser?.uid == ownerUid ? 'owner' : 'viewer',
        source: source,
        error: error,
      );
      rethrow;
    }
  }

  Future<FamilyInvitation> createInvitation({
    required String deviceId,
    required String deviceNickname,
  }) async {
    final ownerUid = _uid;
    final device = await FamilyPaths.deviceDoc(ownerUid, deviceId).get();
    final deviceData = device.data();
    if (!device.exists ||
        deviceData == null ||
        deviceData['ownerUid'] != ownerUid ||
        deviceData['deviceId'] != deviceId) {
      throw FamilySafetyException(FamilySafetyErrorCode.invalidInvitation);
    }
    final ownerDisplayName = familyPersonLabel(
      displayName: _auth.currentUser?.displayName,
      email: _auth.currentUser?.email,
      fallback: '',
    );
    final token = SecureToken.generate();
    final now = DateTime.now().toUtc();
    final expiresAt = now.add(invitationLifetime);
    final doc = FamilyPaths.invitationDoc(token);
    await doc.set({
      'ownerUid': ownerUid,
      'ownerDisplayName': ownerDisplayName,
      'deviceId': deviceId,
      'deviceNickname': deviceNickname,
      'status': 'open',
      'requestedCapabilities': const ['viewLocation', 'viewBattery'],
      'createdAt': FieldValue.serverTimestamp(),
      'expiresAt': Timestamp.fromDate(expiresAt),
    });
    debugPrint(
      'FamilySafety invitation created '
      'ownerUid=$ownerUid ownerDeviceId=$deviceId',
    );
    return FamilyInvitation(
      invitationId: token,
      ownerUid: ownerUid,
      ownerDisplayName: familyPersonLabel(
        displayName: ownerDisplayName,
        email: _auth.currentUser?.email,
        fallback: 'AmarGuard user',
      ),
      createdAt: now,
      expiresAt: expiresAt,
      status: 'open',
      deviceId: deviceId,
      deviceNickname: deviceNickname,
      requestedCapabilities: const ['viewLocation', 'viewBattery'],
    );
  }

  Future<FamilyInvitation> readInvitation(String rawCode) async {
    final token = SecureToken.normalize(rawCode);
    if (token.isEmpty) {
      throw FamilySafetyException(FamilySafetyErrorCode.invitationMalformed);
    }
    try {
      final snapshot = await _readInvitationSnapshot(token);
      if (!snapshot.exists) {
        throw FamilySafetyException(FamilySafetyErrorCode.invitationNotFound);
      }
      final data = snapshot.data();
      if (data == null) {
        throw FamilySafetyException(FamilySafetyErrorCode.invitationNotFound);
      }
      final invitation = FamilyInvitation.fromFirestore(
        data,
        invitationId: snapshot.id,
      );
      if (invitation.status == 'cancelled' || invitation.status == 'closed') {
        throw FamilySafetyException(FamilySafetyErrorCode.invitationClosed);
      }
      if (invitation.isExpired || invitation.status != 'open') {
        throw FamilySafetyException(FamilySafetyErrorCode.invitationExpired);
      }
      return invitation;
    } on FamilySafetyException {
      rethrow;
    } on FirebaseException catch (error) {
      debugPrint(
        'FamilySafety readInvitation code=${error.code} message=${error.message}',
      );
      throw FamilySafetyException.fromFirebase(error);
    }
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> _readInvitationSnapshot(
    String token,
  ) async {
    final primary = await _firestore
        .collection(FamilyPaths.invitations)
        .doc(token)
        .get();
    if (primary.exists) return primary;
    final formatted = SecureToken.formatCode(token);
    if (formatted == token) return primary;
    return _firestore.collection(FamilyPaths.invitations).doc(formatted).get();
  }

  Future<FamilyInvitation?> loadActiveInvitation({
    required String deviceId,
  }) async {
    final snapshot = await _firestore
        .collection(FamilyPaths.invitations)
        .where('ownerUid', isEqualTo: _uid)
        .get();
    FamilyInvitation? latest;
    for (final doc in snapshot.docs) {
      final invitation = FamilyInvitation.fromFirestore(
        doc.data(),
        invitationId: doc.id,
      );
      if (invitation.deviceId != deviceId || !invitation.isOpen) {
        continue;
      }
      if (latest == null || invitation.createdAt.isAfter(latest.createdAt)) {
        latest = invitation;
      }
    }
    return latest;
  }

  Future<void> cancelInvitation(String invitationId) async {
    await FamilyPaths.invitationDoc(invitationId).set({
      'status': 'cancelled',
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<ConnectionRequest> submitConnectionRequest({
    required FamilyInvitation invitation,
    required RelationshipType relationship,
  }) async {
    final viewerUid = _uid;
    final viewer = _auth.currentUser;
    final deviceId = invitation.deviceId?.trim() ?? '';
    if (deviceId.isEmpty || invitation.invitationId.trim().isEmpty) {
      throw FamilySafetyException(FamilySafetyErrorCode.invalidInvitation);
    }
    if (viewerUid == invitation.ownerUid) {
      throw FamilySafetyException(FamilySafetyErrorCode.selfInvitation);
    }
    debugPrint(
      'FamilySafety submitConnectionRequest authPresent=true '
      'viewerIsOwner=${viewerUid == invitation.ownerUid}',
    );

    final invitationRef = _firestore
        .collection(FamilyPaths.invitations)
        .doc(invitation.invitationId);
    final requestRef = invitationRef
        .collection(FamilyPaths.requests)
        .doc(viewerUid);
    final incomingRef = _firestore
        .collection(FamilyPaths.users)
        .doc(invitation.ownerUid)
        .collection(FamilyPaths.devices)
        .doc(deviceId)
        .collection(FamilyPaths.incomingRequests)
        .doc(viewerUid);

    try {
      final result = await _firestore.runTransaction((transaction) async {
        final invitationSnap = await transaction.get(invitationRef);
        if (!invitationSnap.exists) {
          return (
            error: FamilySafetyErrorCode.invitationNotFound,
            request: null,
          );
        }
        final invitationData =
            invitationSnap.data() ?? const <String, dynamic>{};
        final liveInvitation = FamilyInvitation.fromFirestore(
          invitationData,
          invitationId: invitation.invitationId,
        );
        final liveDeviceId = liveInvitation.deviceId?.trim() ?? '';
        if (liveDeviceId.isEmpty) {
          return (
            error: FamilySafetyErrorCode.invalidInvitation,
            request: null,
          );
        }
        if (liveInvitation.ownerUid == viewerUid) {
          return (error: FamilySafetyErrorCode.selfInvitation, request: null);
        }
        if (liveInvitation.ownerUid != invitation.ownerUid ||
            liveDeviceId != deviceId) {
          return (
            error: FamilySafetyErrorCode.invalidInvitation,
            request: null,
          );
        }
        if (liveInvitation.status != 'open') {
          return (error: FamilySafetyErrorCode.invitationClosed, request: null);
        }
        if (liveInvitation.isExpired) {
          return (
            error: FamilySafetyErrorCode.invitationExpired,
            request: null,
          );
        }

        final existingRequest = await transaction.get(requestRef);
        final existingIncoming = await transaction.get(incomingRef);
        final incomingData = existingIncoming.data();
        if (existingIncoming.exists &&
            (incomingData?['viewerUid'] != viewerUid ||
                incomingData?['ownerUid'] != liveInvitation.ownerUid ||
                incomingData?['deviceId'] != liveDeviceId)) {
          return (error: FamilySafetyErrorCode.unknown, request: null);
        }

        if (existingRequest.exists) {
          final existingData =
              existingRequest.data() ?? const <String, dynamic>{};
          final existing = ConnectionRequest.fromFirestore(
            existingData,
            viewerUid: viewerUid,
            invitationId: invitation.invitationId,
            ownerUid: liveInvitation.ownerUid,
          );
          if (existing.isPending) {
            if (existingData['viewerUid'] != viewerUid ||
                existingData['ownerUid'] != liveInvitation.ownerUid ||
                existingData['invitationId'] != invitation.invitationId) {
              return (error: FamilySafetyErrorCode.unknown, request: null);
            }
            if (existingIncoming.exists) {
              if (incomingData?['status'] != 'pending' ||
                  incomingData?['invitationId'] != invitation.invitationId) {
                return (error: FamilySafetyErrorCode.unknown, request: null);
              }
            } else {
              transaction.set(incomingRef, {
                ...existingData,
                'deviceId': liveDeviceId,
              });
            }
            return (
              error: null,
              request: ConnectionRequest(
                viewerUid: existing.viewerUid,
                invitationId: existing.invitationId,
                ownerUid: existing.ownerUid,
                viewerDisplayName: existing.viewerDisplayName,
                viewerEmail: existing.viewerEmail,
                requestedAt: existing.requestedAt,
                status: existing.status,
                relationship: existing.relationship,
                requestedCapabilities: existing.requestedCapabilities,
                alreadyPending: true,
              ),
            );
          }
          return (error: FamilySafetyErrorCode.alreadyProcessed, request: null);
        }

        if (existingIncoming.exists) {
          final existingStatus = incomingData?['status'];
          if (existingStatus == 'pending') {
            final existingInvitationId =
                incomingData?['invitationId'] as String?;
            if (existingInvitationId == null || existingInvitationId.isEmpty) {
              return (error: FamilySafetyErrorCode.unknown, request: null);
            }
            return (
              error: null,
              request: ConnectionRequest.fromFirestore(
                incomingData!,
                viewerUid: viewerUid,
                invitationId: existingInvitationId,
                ownerUid: liveInvitation.ownerUid,
                alreadyPending: true,
              ),
            );
          }
          if (existingStatus == 'approved') {
            return (
              error: FamilySafetyErrorCode.alreadyProcessed,
              request: null,
            );
          }
          if (existingStatus != 'rejected' ||
              incomingData?['invitationId'] == invitation.invitationId) {
            return (
              error: FamilySafetyErrorCode.alreadyProcessed,
              request: null,
            );
          }
        }

        final viewerEmail = viewer?.email ?? '';
        final viewerDisplayName = familyPersonLabel(
          displayName: viewer?.displayName,
          email: viewerEmail,
          fallback: '',
        );
        final requestedAt = Timestamp.now();
        final requestPayload = <String, dynamic>{
          'viewerUid': viewerUid,
          'ownerUid': liveInvitation.ownerUid,
          'invitationId': invitation.invitationId,
          'viewerDisplayName': viewerDisplayName,
          'viewerEmail': viewerEmail,
          'relationship': relationship.name,
          'requestedCapabilities': liveInvitation.requestedCapabilities,
          'status': 'pending',
          'requestedAt': requestedAt,
        };
        final incomingPayload = <String, dynamic>{
          ...requestPayload,
          'deviceId': liveDeviceId,
        };
        transaction.set(requestRef, requestPayload);
        transaction.set(incomingRef, incomingPayload);
        return (
          error: null,
          request: ConnectionRequest(
            viewerUid: viewerUid,
            invitationId: invitation.invitationId,
            ownerUid: liveInvitation.ownerUid,
            viewerDisplayName: viewerDisplayName,
            viewerEmail: viewerEmail,
            requestedAt: requestedAt.toDate(),
            status: 'pending',
            relationship: relationship,
            requestedCapabilities: liveInvitation.requestedCapabilities,
          ),
        );
      });
      if (result.error != null) {
        throw FamilySafetyException(result.error!);
      }
      debugPrint(
        'FamilySafety request resolved status=${result.request!.status} '
        'alreadyPending=${result.request!.alreadyPending}',
      );
      return result.request!;
    } on FamilySafetyException {
      rethrow;
    } on FirebaseException catch (error) {
      debugPrint(
        'FamilySafety submitConnectionRequest operation=transaction '
        'paths=familyInvitations/<invitation>/requests/<viewer>,'
        'users/<owner>/devices/<device>/incomingRequests/<viewer> '
        'role=viewer error=${error.code}',
      );
      throw FamilySafetyException.fromFirebase(error);
    }
  }

  Stream<List<ConnectionRequest>> watchIncomingRequests({
    required String deviceId,
  }) {
    final ownerUid = _uid;
    return _firestore
        .collection(FamilyPaths.users)
        .doc(ownerUid)
        .collection(FamilyPaths.devices)
        .doc(deviceId)
        .collection(FamilyPaths.incomingRequests)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) => ConnectionRequest.fromFirestore(
                  doc.data(),
                  viewerUid: doc.id,
                  invitationId: (doc.data()['invitationId'] as String?) ?? '',
                  ownerUid: ownerUid,
                ),
              )
              .toList(),
        );
  }

  Future<List<ConnectionRequest>> loadIncomingRequests({
    required String deviceId,
    String source = 'family_safety_initialize',
  }) async {
    final ownerUid = _uid;
    late final QuerySnapshot<Map<String, dynamic>> snapshot;
    try {
      snapshot = await _firestore
          .collection(FamilyPaths.users)
          .doc(ownerUid)
          .collection(FamilyPaths.devices)
          .doc(deviceId)
          .collection(FamilyPaths.incomingRequests)
          .get();
    } on FirebaseException catch (error) {
      FamilyFirestoreDiagnostics.logFailure(
        operation: 'get',
        path: 'users/<uid>/devices/<device>/incomingRequests',
        sharingState: 'unknown',
        role: 'owner',
        source: source,
        error: error,
      );
      rethrow;
    }
    return snapshot.docs
        .map(
          (doc) => ConnectionRequest.fromFirestore(
            doc.data(),
            viewerUid: doc.id,
            invitationId: (doc.data()['invitationId'] as String?) ?? '',
            ownerUid: ownerUid,
          ),
        )
        .toList();
  }

  Future<AccessGrant> approveRequest({
    required String deviceId,
    required ConnectionRequest request,
    required RelationshipType relationship,
  }) async {
    final ownerUid = _uid;
    final invitationId = request.invitationId.trim();
    final viewerUid = request.viewerUid.trim();
    final requestDeviceId = request.deviceId?.trim();
    if (invitationId.isEmpty || viewerUid.isEmpty) {
      throw FamilySafetyException(FamilySafetyErrorCode.invalidInvitation);
    }
    if (requestDeviceId != null &&
        requestDeviceId.isNotEmpty &&
        requestDeviceId != deviceId) {
      throw FamilySafetyException(FamilySafetyErrorCode.invalidInvitation);
    }
    if (request.ownerUid.isNotEmpty && request.ownerUid != ownerUid) {
      throw FamilySafetyException(FamilySafetyErrorCode.permissionDenied);
    }

    final requestRef = FamilyPaths.requestDoc(invitationId, viewerUid);
    final incomingRef = FamilyPaths.incomingRequestDoc(
      ownerUid,
      deviceId,
      viewerUid,
    );
    final grantDoc = FamilyPaths.grantDoc(ownerUid, deviceId, viewerUid);
    final viewerIndexDoc = _firestore
        .collection('familyViewerAccess')
        .doc(viewerUid)
        .collection('grants')
        .doc(_viewerIndexId(ownerUid, deviceId));

    var approvalStage = 'read_request';
    try {
      return await _firestore.runTransaction((transaction) async {
        final requestSnapshot = await transaction.get(requestRef);
        final incomingSnapshot = await transaction.get(incomingRef);
        final grantSnapshot = await transaction.get(grantDoc);

        if (!requestSnapshot.exists || !incomingSnapshot.exists) {
          throw FamilySafetyException(FamilySafetyErrorCode.invalidInvitation);
        }
        final requestData = requestSnapshot.data() ?? const <String, dynamic>{};
        final incomingData =
            incomingSnapshot.data() ?? const <String, dynamic>{};
        final liveRequest = ConnectionRequest.fromFirestore(
          requestData,
          viewerUid: viewerUid,
          invitationId: invitationId,
          ownerUid: ownerUid,
        );
        if (requestData['viewerUid'] != viewerUid ||
            requestData['ownerUid'] != ownerUid ||
            requestData['invitationId'] != invitationId ||
            incomingData['viewerUid'] != viewerUid ||
            incomingData['ownerUid'] != ownerUid ||
            incomingData['deviceId'] != deviceId ||
            incomingData['invitationId'] != invitationId) {
          throw FamilySafetyException(FamilySafetyErrorCode.invalidInvitation);
        }
        final requestStatus = liveRequest.status;
        final incomingStatus = incomingData['status'] as String?;
        final bothPending =
            requestStatus == 'pending' && incomingStatus == 'pending';
        final bothApproved =
            requestStatus == 'approved' && incomingStatus == 'approved';
        final partiallyApproved =
            (requestStatus == 'approved' && incomingStatus == 'pending') ||
            (requestStatus == 'pending' && incomingStatus == 'approved');
        if (!bothPending && !bothApproved && !partiallyApproved) {
          throw FamilySafetyException(FamilySafetyErrorCode.alreadyProcessed);
        }

        final grantData = grantSnapshot.data();
        if (grantSnapshot.exists &&
            (grantData?['viewerUid'] != viewerUid ||
                grantData?['ownerUid'] != ownerUid ||
                grantData?['deviceId'] != deviceId)) {
          throw FamilySafetyException(FamilySafetyErrorCode.permissionDenied);
        }
        if (partiallyApproved &&
            (!grantSnapshot.exists || grantData?['active'] != true)) {
          throw FamilySafetyException(FamilySafetyErrorCode.invalidInvitation);
        }
        final viewerLabel = familyPersonLabel(
          displayName: liveRequest.viewerDisplayName,
          email: liveRequest.viewerEmail,
        );
        final ownerLabel = familyPersonLabel(
          displayName: _auth.currentUser?.displayName,
          email: _auth.currentUser?.email,
          fallback: '',
        );

        approvalStage = 'write_grant';
        if (!grantSnapshot.exists) {
          transaction.set(grantDoc, {
            'viewerUid': viewerUid,
            'ownerUid': ownerUid,
            'deviceId': deviceId,
            'invitationId': invitationId,
            'active': true,
            'relationship': relationship.name,
            'viewerDisplayName': viewerLabel,
            'viewerEmail': liveRequest.viewerEmail,
            'grantedAt': FieldValue.serverTimestamp(),
          });
        } else if (grantData?['active'] != true) {
          transaction.update(grantDoc, {'active': true});
        }

        approvalStage = 'write_viewer_index';
        transaction.set(viewerIndexDoc, {
          'ownerUid': ownerUid,
          'deviceId': deviceId,
          'ownerDisplayName': ownerLabel,
          'relationship': relationship.name,
          'grantedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        if (requestStatus == 'pending') {
          approvalStage = 'approve_request';
          transaction.update(requestRef, {
            'status': 'approved',
            'approvedAt': FieldValue.serverTimestamp(),
          });
        }
        if (incomingStatus == 'pending') {
          approvalStage = 'approve_incoming_request';
          transaction.update(incomingRef, {
            'status': 'approved',
            'approvedAt': FieldValue.serverTimestamp(),
          });
        }

        return AccessGrant(
          viewerUid: viewerUid,
          ownerUid: ownerUid,
          deviceId: deviceId,
          grantedAt: DateTime.now().toUtc(),
          active: true,
          viewerDisplayName: viewerLabel,
          viewerEmail: liveRequest.viewerEmail,
          relationship: relationship,
        );
      });
    } on FamilySafetyException {
      rethrow;
    } on FirebaseException catch (error) {
      debugPrint(
        'FamilySafety approveRequest operation=transaction '
        'stage=$approvalStage '
        'paths=familyInvitations/<invitation>/requests/<viewer>,'
        'users/<owner>/devices/<device>/incomingRequests/<viewer>,'
        'users/<owner>/devices/<device>/approvedViewers/<viewer>,'
        'familyViewerAccess/<viewer>/grants/<owner>__<device> '
        'role=owner error=${error.code}',
      );
      if (error.code == 'permission-denied') {
        throw FamilySafetyException(
          FamilySafetyErrorCode.approvalPermissionDenied,
          cause: error,
        );
      }
      throw FamilySafetyException.fromFirebase(error);
    }
  }

  Future<void> rejectRequest({
    required String deviceId,
    required ConnectionRequest request,
  }) async {
    final ownerUid = _uid;
    await FamilyPaths.requestDoc(request.invitationId, request.viewerUid).set({
      'status': 'rejected',
      'rejectedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await FamilyPaths.deviceDoc(
      ownerUid,
      deviceId,
    ).collection(FamilyPaths.incomingRequests).doc(request.viewerUid).set({
      'status': 'rejected',
      'rejectedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await FamilyPaths.invitationDoc(request.invitationId).set({
      'status': 'closed',
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> revokeViewer({
    required String deviceId,
    required String viewerUid,
  }) async {
    final ownerUid = _uid;
    final batch = _firestore.batch();
    batch.delete(FamilyPaths.grantDoc(ownerUid, deviceId, viewerUid));
    batch.delete(
      _firestore
          .collection('familyViewerAccess')
          .doc(viewerUid)
          .collection('grants')
          .doc(_viewerIndexId(ownerUid, deviceId)),
    );
    await batch.commit();
  }

  Future<void> revokeAccessAsViewer({
    required String ownerUid,
    required String deviceId,
  }) async {
    final viewerUid = _uid;
    final batch = _firestore.batch();
    batch.delete(FamilyPaths.grantDoc(ownerUid, deviceId, viewerUid));
    batch.delete(
      _firestore
          .collection('familyViewerAccess')
          .doc(viewerUid)
          .collection('grants')
          .doc(_viewerIndexId(ownerUid, deviceId)),
    );
    await batch.commit();
  }

  Future<void> updateViewerAlias({
    required String ownerUid,
    required String deviceId,
    required String alias,
  }) async {
    await _firestore
        .collection('familyViewerAccess')
        .doc(_uid)
        .collection('grants')
        .doc(_viewerIndexId(ownerUid, deviceId))
        .set({'alias': alias.trim()}, SetOptions(merge: true));
  }

  Stream<List<AccessGrant>> watchGrants({required String deviceId}) {
    final ownerUid = _uid;
    return FamilyPaths.grantCollection(ownerUid, deviceId).snapshots().map(
      (snapshot) => snapshot.docs
          .map(
            (doc) => AccessGrant.fromFirestore(
              doc.data(),
              ownerUid: ownerUid,
              deviceId: deviceId,
              viewerUid: doc.id,
            ),
          )
          .toList(),
    );
  }

  Future<List<AccessGrant>> loadGrants({
    required String deviceId,
    String source = 'family_safety_refresh',
  }) async {
    final ownerUid = _uid;
    late final QuerySnapshot<Map<String, dynamic>> snapshot;
    try {
      snapshot = await FamilyPaths.grantCollection(ownerUid, deviceId).get();
    } on FirebaseException catch (error) {
      FamilyFirestoreDiagnostics.logFailure(
        operation: 'get',
        path: 'users/<uid>/devices/<device>/approvedViewers',
        sharingState: 'unknown',
        role: 'owner',
        source: source,
        error: error,
      );
      rethrow;
    }
    return snapshot.docs
        .map(
          (doc) => AccessGrant.fromFirestore(
            doc.data(),
            ownerUid: ownerUid,
            deviceId: deviceId,
            viewerUid: doc.id,
          ),
        )
        .toList();
  }

  Stream<List<ViewerAccessEntry>> watchViewerAccess() {
    final viewerUid = _uid;
    return _firestore
        .collection('familyViewerAccess')
        .doc(viewerUid)
        .collection('grants')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => ViewerAccessEntry.fromFirestore(doc.data(), doc.id))
              .toList(),
        );
  }

  Future<List<ViewerAccessEntry>> loadViewerAccess({
    String source = 'family_safety_refresh',
  }) async {
    final viewerUid = _uid;
    late final QuerySnapshot<Map<String, dynamic>> snapshot;
    try {
      snapshot = await _firestore
          .collection('familyViewerAccess')
          .doc(viewerUid)
          .collection('grants')
          .get();
    } on FirebaseException catch (error) {
      FamilyFirestoreDiagnostics.logFailure(
        operation: 'get',
        path: 'familyViewerAccess/<uid>/grants',
        sharingState: 'unknown',
        role: 'viewer',
        source: source,
        error: error,
      );
      rethrow;
    }
    return snapshot.docs
        .map((doc) => ViewerAccessEntry.fromFirestore(doc.data(), doc.id))
        .toList();
  }

  String _viewerIndexId(String ownerUid, String deviceId) {
    return '${ownerUid}__$deviceId';
  }
}

class ViewerAccessEntry {
  const ViewerAccessEntry({
    required this.ownerUid,
    required this.deviceId,
    required this.ownerDisplayName,
    required this.relationship,
    required this.grantedAt,
    this.alias,
  });

  final String ownerUid;
  final String deviceId;
  final String ownerDisplayName;
  final RelationshipType relationship;
  final DateTime grantedAt;
  final String? alias;

  static ViewerAccessEntry fromFirestore(Map<String, dynamic> data, String id) {
    final rawRelationship = data['relationship'];
    final relationship = RelationshipType.values.firstWhere(
      (item) => item.name == rawRelationship,
      orElse: () => RelationshipType.other,
    );
    final grantedAt = data['grantedAt'];
    return ViewerAccessEntry(
      ownerUid: (data['ownerUid'] as String?) ?? '',
      deviceId: (data['deviceId'] as String?) ?? '',
      ownerDisplayName:
          (data['ownerDisplayName'] as String?) ?? 'Family member',
      alias: data['alias'] as String?,
      relationship: relationship,
      grantedAt: grantedAt is Timestamp
          ? grantedAt.toDate()
          : DateTime.tryParse('${grantedAt ?? ''}') ?? DateTime.now().toUtc(),
    );
  }
}
