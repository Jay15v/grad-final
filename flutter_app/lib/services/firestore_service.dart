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

  /// Real-time stream of unacknowledged blocked-message alerts for a parent.
  Stream<List<Map<String, dynamic>>> getBlockedAlerts(String parentId) =>
      FirebaseFirestore.instance
          .collection('blocked_alerts')
          .where('parent_id', isEqualTo: parentId)
          .snapshots()
          .map((snap) {
            final list = snap.docs
                .where((d) => d.data()['acknowledged'] != true)
                .map((d) => <String, dynamic>{'id': d.id, ...d.data()})
                .toList();
            list.sort((a, b) {
              final ta = (a['timestamp'] as num?) ?? 0;
              final tb = (b['timestamp'] as num?) ?? 0;
              return tb.compareTo(ta);
            });
            return list;
          });

  Future<void> acknowledgeBlockedAlert(String docId) =>
      FirebaseFirestore.instance
          .collection('blocked_alerts')
          .doc(docId)
          .update({'acknowledged': true});

  /// Real-time stream of unacknowledged HESITATE cases for a parent.
  Stream<List<Map<String, dynamic>>> getPendingReviews(String parentId) =>
      FirebaseFirestore.instance
          .collection('pending_reviews')
          .where('parent_id', isEqualTo: parentId)
          .snapshots()
          .map((snap) {
            final list = snap.docs
                .where((d) => d.data()['acknowledged'] != true)
                .map((d) => <String, dynamic>{'id': d.id, ...d.data()})
                .toList();
            list.sort((a, b) {
              final ta = (a['timestamp'] as num?) ?? 0;
              final tb = (b['timestamp'] as num?) ?? 0;
              return tb.compareTo(ta);
            });
            return list;
          });

  Future<void> acknowledgePendingReview(String docId) =>
      FirebaseFirestore.instance
          .collection('pending_reviews')
          .doc(docId)
          .update({'acknowledged': true});
}
