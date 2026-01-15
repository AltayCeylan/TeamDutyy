import 'package:cloud_firestore/cloud_firestore.dart';

class DepartmentService {
  final _db = FirebaseFirestore.instance;

  Stream<QuerySnapshot<Map<String, dynamic>>> watchDepartments(String companyId) {
    return _db
        .collection('companies')
        .doc(companyId)
        .collection('departments')
        .orderBy('name')
        .snapshots();
  }

  Future<void> addDepartment({
    required String companyId,
    required String name,
  }) async {
    final ref = _db
        .collection('companies')
        .doc(companyId)
        .collection('departments')
        .doc();

    await ref.set({
      'name': name.trim(),
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
