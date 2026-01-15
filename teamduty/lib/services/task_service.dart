import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class TaskService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Admin görev oluşturur.
  /// Not: assignedByUid parametresi yok — otomatik currentUser.uid yazılır.
  Future<String> createTask({
    required String companyId,
    required String title,
    String? description,
    required String assignedToUid,
    required String departmentId,
    DateTime? dueAt,
    String priority = 'normal',
  }) async {
    final u = _auth.currentUser;
    if (u == null) throw Exception('Oturum yok');

    final ref = _db
        .collection('companies')
        .doc(companyId)
        .collection('tasks')
        .doc();

    await ref.set({
      'title': title.trim(),
      'description': (description ?? '').trim(),
      'assignedToUid': assignedToUid,
      'assignedByUid': u.uid,
      'departmentId': departmentId,
      'status': 'pending', // pending | done | canceled
      'priority': priority,
      'dueAt': dueAt == null ? null : Timestamp.fromDate(dueAt),
      'createdAt': FieldValue.serverTimestamp(),
       'updatedAt': FieldValue.serverTimestamp(),
      'canceledAt': null,
      'canceledByUid': null,
      'cancelReason': null,
    });

    return ref.id;
  }

  Future<void> setDone({
    required String companyId,
    required String taskId,
    required bool done,
  }) async {
    final u = _auth.currentUser;
    if (u == null) throw Exception('Oturum yok');

    await _db
        .collection('companies')
        .doc(companyId)
        .collection('tasks')
        .doc(taskId)
        .update({
      'status': done ? 'done' : 'pending',
      'doneAt': done ? FieldValue.serverTimestamp() : FieldValue.delete(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> cancelTask({
    required String companyId,
    required String taskId,
    String? reason,
  }) async {
    final u = _auth.currentUser;
    if (u == null) throw Exception('Oturum yok');

    await _db
        .collection('companies')
        .doc(companyId)
        .collection('tasks')
        .doc(taskId)
        .update({
      'status': 'canceled',
      'canceledAt': FieldValue.serverTimestamp(),
      'canceledByUid': u.uid,
      'cancelReason': (reason ?? '').trim(),
      'updatedAt': FieldValue.serverTimestamp(),

      
    });
    Future<void> uncancelTask({
  required String companyId,
  required String taskId,
}) async {
  final u = _auth.currentUser;
  if (u == null) throw Exception('Oturum yok');

  await _db
      .collection('companies')
      .doc(companyId)
      .collection('tasks')
      .doc(taskId)
      .update({
    'status': 'pending',
    'canceledAt': FieldValue.delete(),
    'canceledByUid': FieldValue.delete(),
    'cancelReason': FieldValue.delete(),
    'updatedAt': FieldValue.serverTimestamp(),
  });
}

  }
}
