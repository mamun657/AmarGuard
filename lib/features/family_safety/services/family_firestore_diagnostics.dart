import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class FamilyFirestoreDiagnostics {
  const FamilyFirestoreDiagnostics._();

  static void logFailure({
    required String operation,
    required String path,
    required String sharingState,
    required String role,
    required String source,
    required Object error,
    bool expected = false,
  }) {
    final category = error is FirebaseException
        ? error.code
        : error.runtimeType.toString();
    debugPrint(
      'FamilySafety firestore operation=$operation path=$path '
      'state=$sharingState role=$role error=$category source=$source '
      'expected=$expected',
    );
  }
}
