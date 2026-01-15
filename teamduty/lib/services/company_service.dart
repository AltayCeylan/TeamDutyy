import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CompanyService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String _companyCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final r = Random.secure();
    return List.generate(6, (_) => chars[r.nextInt(chars.length)]).join();
  }

  Future<({String companyId, String code})> createCompanyAndMakeMeAdmin({
    required String companyName,
    required String displayName,
  }) async {
    final u = _auth.currentUser;
    if (u == null) throw Exception('Önce yönetici giriş yapmalı.');

    final companyRef = _db.collection('companies').doc();
    final code = _companyCode(); // zaten büyük harf

    // 1) company
    await companyRef.set({
      'name': companyName.trim(),
      'code': code,
      'createdBy': u.uid,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // 2) members (admin)
    await companyRef.collection('members').doc(u.uid).set({
      'role': 'admin',
      'displayName': displayName.trim(),
      'createdAt': FieldValue.serverTimestamp(),
    });

    // 3) users/{uid} activeCompanyId
    await _db.collection('users').doc(u.uid).set(
      {
        'activeCompanyId': companyRef.id,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    // 4) companyCodes/{CODE} mapping (çalışan aktivasyon için)
    await _db.collection('companyCodes').doc(code).set({
      'companyId': companyRef.id,
      'name': companyName.trim(),
      'createdBy': u.uid,
      'createdAt': FieldValue.serverTimestamp(),
    });

    return (companyId: companyRef.id, code: code);
  }
}
