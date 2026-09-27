import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserService {
  UserService(this._firestore, this._auth);

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  static const String collection = 'users';

  Future<void> createProfile({
    required String displayName,
    required String email,
    required String phoneNumber,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('No authenticated user found.');
    }

    final now = FieldValue.serverTimestamp();
    await _firestore.collection(collection).doc(user.uid).set({
      'displayName': displayName,
      'email': email,
      'phoneNumber': phoneNumber,
      'authProvider': 'email',
      'createdAt': now,
      'updatedAt': now,
    }, SetOptions(merge: true));
  }

  Future<void> updateLastActive() async {
    final user = _auth.currentUser;
    if (user == null) return;
    await _firestore.collection(collection).doc(user.uid).update({
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
