import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  String _normCompanyCode(String code) => code.trim().toUpperCase();
  String _normEmployeeNo(String no) => no.trim();

  String _employeeEmail(String companyCode, String employeeNo) {
    final c = _normCompanyCode(companyCode).toLowerCase();
    final e = _normEmployeeNo(employeeNo).toLowerCase().replaceAll(' ', '');
    return '$e@$c.teamduty.app';
  }

  String _randomCode({int len = 10}) {
    const chars = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
    final r = Random.secure();
    return List.generate(len, (_) => chars[r.nextInt(chars.length)]).join();
  }

  // ✅ ADMIN SIGN UP (HATANI ÇÖZEN METOT)
  Future<void> adminSignUp({
    required String email,
    required String password,
  }) async {
    await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<void> adminSignIn({
    required String email,
    required String password,
  }) async {
    await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<void> signOut() async => _auth.signOut();

  // companyCodes/{CODE} -> companyId
  Future<String> getCompanyIdByCode(String companyCode) async {
    final code = _normCompanyCode(companyCode);
    final doc = await _db.collection('companyCodes').doc(code).get();
    if (!doc.exists) {
      throw Exception('Şirket kodu bulunamadı: $code');
    }
    final data = doc.data()!;
    final companyId = (data['companyId'] ?? '') as String;
    if (companyId.isEmpty) throw Exception('companyCodes/$code içinde companyId yok.');
    return companyId;
  }

  // ✅ EMPLOYEE ACTIVATE (invite ile ilk giriş)
  Future<void> employeeActivate({
    required String companyCode,
    required String employeeNo,
    required String inviteCode,
    required String password,
    required String displayName,
  }) async {
    final code = _normCompanyCode(companyCode);
    final empNo = _normEmployeeNo(employeeNo);
    final inv = inviteCode.trim();

    final email = _employeeEmail(code, empNo);

    // kullanıcı yoksa oluştur, varsa giriş dene
    try {
      await _auth.createUserWithEmailAndPassword(email: email, password: password);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        await _auth.signInWithEmailAndPassword(email: email, password: password);
      } else {
        rethrow;
      }
    }

    final u = _auth.currentUser;
    if (u == null) throw Exception('Auth user null (aktivasyon sonrası).');

    final companyId = await getCompanyIdByCode(code);

    final inviteRef = _db.collection('companies').doc(companyId).collection('invites').doc(inv);
    final memberRef = _db.collection('companies').doc(companyId).collection('members').doc(u.uid);

    await _db.runTransaction((tx) async {
      final inviteSnap = await tx.get(inviteRef);
      if (!inviteSnap.exists) throw Exception('Davet kodu bulunamadı.');

      final invData = inviteSnap.data() as Map<String, dynamic>;
      if (invData['usedBy'] != null) throw Exception('Bu davet kodu daha önce kullanılmış.');

      final invEmployeeNo = (invData['employeeNo'] ?? '') as String;
      if (invEmployeeNo != empNo) throw Exception('Çalışan numarası davet ile uyuşmuyor.');

      tx.update(inviteRef, {
        'usedBy': u.uid,
        'usedAt': FieldValue.serverTimestamp(),
      });

      // ✅ members/{uid} docId = uid (assignedToUid sorununu çözer)
      tx.set(
        memberRef,
        {
          'uid': u.uid,
          'role': 'employee',
          'displayName': displayName.trim(),
          'employeeNo': empNo,
          'departmentId': null,
          'inviteCode': inv,
          'createdAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    });

    // users/{uid}.activeCompanyId
   await _db.collection('users').doc(u.uid).set(
  {
    'activeCompanyId': companyId,
    'updatedAt': FieldValue.serverTimestamp(),

    // ✅ İlk girişte şifre adminin verdiği: çalışan sonra değiştirsin
    'passwordChanged': false,
    'passwordChangedAt': null,
  },
  SetOptions(merge: true),
);

  }

  // EMPLOYEE SIGN IN
  Future<void> employeeSignIn({
    required String companyCode,
    required String employeeNo,
    required String password,
  }) async {
    final code = _normCompanyCode(companyCode);
    final empNo = _normEmployeeNo(employeeNo);
    final email = _employeeEmail(code, empNo);

    await _auth.signInWithEmailAndPassword(email: email, password: password);

    final u = _auth.currentUser;
    if (u == null) throw Exception('Auth user null (signIn sonrası).');

    final companyId = await getCompanyIdByCode(code);

    await _db.collection('users').doc(u.uid).set(
      {
        'activeCompanyId': companyId,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  // Admin invite üretme (istersen kullanırsın)
  Future<String> createEmployeeInvite({
    required String companyId,
    required String employeeNo,
    required String displayName,
  }) async {
    final inv = _randomCode(len: 10);

    await _db.collection('companies').doc(companyId).collection('invites').doc(inv).set({
      'inviteCode': inv,
      'role': 'employee',
      'employeeNo': _normEmployeeNo(employeeNo),
      'displayName': displayName.trim(),
      'createdAt': FieldValue.serverTimestamp(),
      'createdBy': _auth.currentUser?.uid,
      'usedBy': null,
      'usedAt': null,
    });

    return inv;
  }
}
