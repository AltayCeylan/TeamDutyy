import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AdminCompany {
  final String companyId;
  final String companyName;
  final String companyCode;

  AdminCompany({
    required this.companyId,
    required this.companyName,
    required this.companyCode,
  });
}

class AdminCompanyService {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  /// ✅ Adminin aktif şirketini users/{uid}.activeCompanyId üzerinden bulur
  Future<AdminCompany?> getMyActiveAdminCompany() async {
    final u = _auth.currentUser;
    if (u == null) return null;

    // 1) users/{uid} -> activeCompanyId
    final userDoc = await _db.collection('users').doc(u.uid).get();
    final companyId = userDoc.data()?['activeCompanyId'] as String?;
    if (companyId == null || companyId.isEmpty) return null;

    // 2) companies/{companyId}/members/{uid} -> role admin mi?
    final memberDoc = await _db
        .collection('companies')
        .doc(companyId)
        .collection('members')
        .doc(u.uid)
        .get();

    if (!memberDoc.exists) return null;
    final role = (memberDoc.data()?['role'] ?? '') as String;
    if (role != 'admin') return null;

    // 3) companies/{companyId} bilgisi
    final companyDoc = await _db.collection('companies').doc(companyId).get();
    if (!companyDoc.exists) return null;

    final data = companyDoc.data()!;
    return AdminCompany(
      companyId: companyId,
      companyName: (data['name'] ?? '-') as String,
      companyCode: (data['code'] ?? '-') as String,
    );
  }

  /// ✅ Eski metodu kullanan sayfalar kırılmasın diye alias bıraktım
  Future<AdminCompany?> getMyFirstAdminCompany() => getMyActiveAdminCompany();
}
