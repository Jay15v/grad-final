import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class FirestoreService {
  final _users = FirebaseFirestore.instance
      .collection('users')
      .withConverter<UserModel>(
        fromFirestore: (snap, _) => UserModel.fromFirestore(snap),
        toFirestore: (user, _) => user.toMap(),
      );

  Future<UserModel?> getUser(String uid) async {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get()
        .timeout(const Duration(seconds: 10));
    if (!doc.exists || doc.data() == null) return null;
    return UserModel.fromFirestore(doc);
  }

  Future<void> createUserRecord(UserModel user) =>
      FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set(user.toMap());

  Stream<List<UserModel>> getAllUsers() => _users.snapshots().map(
        (snap) => snap.docs.map((d) => d.data()).toList(),
      );

  Stream<List<UserModel>> getParents() => _users
      .where('role', isEqualTo: 'parent')
      .snapshots()
      .map((snap) => snap.docs.map((d) => d.data()).toList());

  Stream<List<UserModel>> getChildrenOfParent(String parentId) => _users
      .where('parentId', isEqualTo: parentId)
      .snapshots()
      .map((snap) => snap.docs.map((d) => d.data()).toList());

  Future<UserModel?> getUserByEmail(String email) async {
    final snap = await _users.where('email', isEqualTo: email).limit(1).get();
    if (snap.docs.isEmpty) return null;
    return snap.docs.first.data();
  }

  Future<void> deleteUserRecord(String uid) =>
      _users.doc(uid).delete();
}
