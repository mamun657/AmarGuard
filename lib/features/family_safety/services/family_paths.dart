import 'package:cloud_firestore/cloud_firestore.dart';

class FamilyPaths {
  FamilyPaths._();

  static const String users = 'users';
  static const String devices = 'devices';
  static const String approvedViewers = 'approvedViewers';
  static const String location = 'location';
  static const String status = 'status';
  static const String current = 'current';
  static const String invitations = 'familyInvitations';
  static const String requests = 'requests';
  static const String incomingRequests = 'incomingRequests';

  static DocumentReference<Map<String, dynamic>> deviceDoc(
    String ownerUid,
    String deviceId,
  ) {
    return FirebaseFirestore.instance
        .collection(users)
        .doc(ownerUid)
        .collection(devices)
        .doc(deviceId);
  }

  static DocumentReference<Map<String, dynamic>> locationDoc(
    String ownerUid,
    String deviceId,
  ) {
    return deviceDoc(ownerUid, deviceId)
        .collection(location)
        .doc(current);
  }

  static DocumentReference<Map<String, dynamic>> statusDoc(
    String ownerUid,
    String deviceId,
  ) {
    return deviceDoc(ownerUid, deviceId)
        .collection(status)
        .doc(current);
  }

  static CollectionReference<Map<String, dynamic>> grantCollection(
    String ownerUid,
    String deviceId,
  ) {
    return deviceDoc(ownerUid, deviceId).collection(approvedViewers);
  }

  static DocumentReference<Map<String, dynamic>> grantDoc(
    String ownerUid,
    String deviceId,
    String viewerUid,
  ) {
    return grantCollection(ownerUid, deviceId).doc(viewerUid);
  }

  static CollectionReference<Map<String, dynamic>> requestCollection(
    String invitationId,
  ) {
    return FirebaseFirestore.instance
        .collection(invitations)
        .doc(invitationId)
        .collection(requests);
  }

  static DocumentReference<Map<String, dynamic>> requestDoc(
    String invitationId,
    String viewerUid,
  ) {
    return requestCollection(invitationId).doc(viewerUid);
  }

  static DocumentReference<Map<String, dynamic>> invitationDoc(
    String invitationId,
  ) {
    return FirebaseFirestore.instance.collection(invitations).doc(invitationId);
  }

  static DocumentReference<Map<String, dynamic>> incomingRequestDoc(
    String ownerUid,
    String deviceId,
    String viewerUid,
  ) {
    return deviceDoc(ownerUid, deviceId)
        .collection(incomingRequests)
        .doc(viewerUid);
  }
}
