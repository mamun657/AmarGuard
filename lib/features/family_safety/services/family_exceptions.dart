import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

enum FamilySafetyErrorCode {
  unauthenticated,
  selfInvitation,
  invitationNotFound,
  invitationExpired,
  invitationClosed,
  invitationMalformed,
  invalidInvitation,
  duplicateRequest,
  alreadyProcessed,
  permissionDenied,
  approvalPermissionDenied,
  network,
  unknown,
}

class FamilySafetyException implements Exception {
  FamilySafetyException(this.code, {this.message, this.cause});

  final FamilySafetyErrorCode code;
  final String? message;
  final Object? cause;

  static FamilySafetyException fromFirebase(FirebaseException error) {
    debugPrint(
      'FamilySafety FirebaseException code=${error.code} message=${error.message}',
    );
    switch (error.code) {
      case 'permission-denied':
        return FamilySafetyException(
          FamilySafetyErrorCode.permissionDenied,
          message: error.message,
          cause: error,
        );
      case 'unavailable':
      case 'deadline-exceeded':
      case 'network-request-failed':
        return FamilySafetyException(
          FamilySafetyErrorCode.network,
          message: error.message,
          cause: error,
        );
      case 'not-found':
        return FamilySafetyException(
          FamilySafetyErrorCode.invitationNotFound,
          message: error.message,
          cause: error,
        );
      default:
        return FamilySafetyException(
          FamilySafetyErrorCode.unknown,
          message: error.message,
          cause: error,
        );
    }
  }

  @override
  String toString() {
    return 'FamilySafetyException(${code.name}, $message)';
  }
}
