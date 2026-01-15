import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class InviteService {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  String _randCode(int len) {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final r = Random.secure();
    return List.generate(len, (_) => chars[r.nextInt(chars.length)]).join();
  }

  Future<String> createEmployeeInvite({
    required String companyId,
    required String employeeNo,
    required String displayName,
  }) async {
    final inviteCode = _randCode(10);

    final ref = _db
        .collection('companies')
        .doc(companyId)
        .collection('invites')
        .doc(inviteCode);

    await ref.set({
      'employeeNo': employeeNo.trim(),
      'displayName': displayName.trim(),
      'role': 'employee',
      'usedBy': null,
      'createdAt': FieldValue.serverTimestamp(),
    });

    return inviteCode;
  }

  Future<void> redeemInvite({
    required String companyCode,
    required String employeeNo,
    required String inviteCode,
    required String displayName,
  }) async {
    final u = _auth.currentUser;
    if (u == null) throw Exception('Önce giriş yapılmalı.');

    final code = companyCode.trim().toUpperCase();

    // ✅ companyId'yi companyCodes'tan bul
    final codeSnap = await _db.collection('companyCodes').doc(code).get();
    if (!codeSnap.exists) throw Exception('Şirket kodu bulunamadı.');

    final companyId = (codeSnap.data()?['companyId'] ?? '') as String;
    if (companyId.isEmpty) throw Exception('companyCodes kaydı hatalı.');

    final inviteRef = _db
        .collection('companies')
        .doc(companyId)
        .collection('invites')
        .doc(inviteCode.trim());

    final memberRef = _db
        .collection('companies')
        .doc(companyId)
        .collection('members')
        .doc(u.uid);

    // ✅ Invite'ı okumadan (read yok) batch ile yaz
    final batch = _db.batch();

    batch.set(memberRef, {
      'role': 'employee',
      'displayName': displayName.trim(),
      'employeeNo': employeeNo.trim(),
      'inviteCode': inviteCode.trim(),
      'createdAt': FieldValue.serverTimestamp(),
    });

    batch.update(inviteRef, {
      'usedBy': u.uid,
      'usedAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();

    // ✅ Çalışanın aktif şirketini users/{uid} içine yaz
    await _db.collection('users').doc(u.uid).set(
      {
        'activeCompanyId': companyId,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }
}
