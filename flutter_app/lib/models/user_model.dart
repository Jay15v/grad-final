import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String email;
  final String name;
  final String role; // 'admin' | 'parent' | 'child'
  final String? parentId; // only set for child accounts
  final DateTime createdAt;

  const UserModel({
    required this.uid,
    required this.email,
    required this.name,
    required this.role,
    this.parentId,
    required this.createdAt,
  });

  factory UserModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return UserModel(
      uid: doc.id,
      email: data['email'] as String,
      name: data['name'] as String,
      role: data['role'] as String,
      parentId: data['parentId'] as String?,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
    'email': email,
    'name': name,
    'role': role,
    if (parentId != null) 'parentId': parentId,
    'createdAt': Timestamp.fromDate(createdAt),
  };
}
