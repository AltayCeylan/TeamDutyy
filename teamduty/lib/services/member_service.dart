import 'package:cloud_firestore/cloud_firestore.dart';

class MemberService {
  final _db = FirebaseFirestore.instance;

  Stream<QuerySnapshot<Map<String, dynamic>>> watchEmployees(String companyId) {
    return _db
        .collection('companies')
        .doc(companyId)
        .collection('members')
        .where('role', isEqualTo: 'employee')
        .snapshots();
  }

  Future<void> setEmployeeDepartment({
    required String companyId,
    required String uid,
    required String? departmentId, // null => departman kaldır
  }) async {
    final ref = _db
        .collection('companies')
        .doc(companyId)
        .collection('members')
        .doc(uid);

    await ref.update({
      'departmentId': departmentId,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
