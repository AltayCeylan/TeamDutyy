import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class EmployeeActivatePage extends StatefulWidget {
  const EmployeeActivatePage({super.key});

  @override
  State<EmployeeActivatePage> createState() => _EmployeeActivatePageState();
}

class _EmployeeActivatePageState extends State<EmployeeActivatePage> {
  final _companyCode = TextEditingController();
  final _employeeNo = TextEditingController();
  final _inviteCode = TextEditingController();
  final _displayName = TextEditingController();
  final _pass1 = TextEditingController();
  final _pass2 = TextEditingController();

  bool _loading = false;

  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;

  @override
  void dispose() {
    _companyCode.dispose();
    _employeeNo.dispose();
    _inviteCode.dispose();
    _displayName.dispose();
    _pass1.dispose();
    _pass2.dispose();
    super.dispose();
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  String _cleanNo(String s) => s.trim().toLowerCase();

  /// Çalışan hesapları için email adayları (case farkı yüzünden)
  List<String> _employeeEmailCandidates(String companyCode, String employeeNo) {
    final cRaw = companyCode.trim();
    final nRaw = employeeNo.trim();
    final n = _cleanNo(nRaw);

    final lower = '${cRaw.toLowerCase()}_${n}@teamduty.local';
    final upper = '${cRaw.toUpperCase()}_${n}@teamduty.local';
    final raw = '${cRaw}_${nRaw}@teamduty.local';

    return <String>{lower, upper, raw}.toList();
  }

  /// companyCodes doc'u case bağımsız bul (raw/UPPER/lower)
  /// 🔴 DİKKAT: rules read için signedIn() istiyor → bu fonksiyon sadece oturum açtıktan sonra çağrılır.
  Future<DocumentSnapshot<Map<String, dynamic>>> _getCompanyCodeDocSignedIn(String companyCode) async {
    final raw = companyCode.trim();
    if (raw.isEmpty) throw Exception('Company Code boş');

    final candidates = <String>{raw, raw.toUpperCase(), raw.toLowerCase()};
    for (final id in candidates) {
      final snap = await _db.collection('companyCodes').doc(id).get();
      if (snap.exists) return snap;
    }
    throw Exception('companyCodes/$raw bulunamadı (upper/lower da yok).');
  }

  Future<UserCredential> _signInWithAnyEmail(List<String> emails, String password) async {
    FirebaseAuthException? last;
    for (final e in emails) {
      try {
        return await _auth.signInWithEmailAndPassword(email: e, password: password);
      } on FirebaseAuthException catch (ex) {
        last = ex;
      }
    }
    throw last ?? FirebaseAuthException(code: 'invalid-credential', message: 'Giriş başarısız');
  }

  bool _isAuthMismatchCode(String code) {
    // Firebase bazen her şeyi invalid-credential diye döndürüyor
    return code == 'invalid-credential' || code == 'wrong-password' || code == 'user-not-found';
  }

  Future<void> _activate() async {
    final codeInput = _companyCode.text.trim();
    final noInput = _employeeNo.text.trim();
    final invite = _inviteCode.text.trim();
    final name = _displayName.text.trim();

    final newPass = _pass1.text.trim();
    final newPass2 = _pass2.text.trim();

    if (codeInput.isEmpty || noInput.isEmpty || invite.isEmpty || newPass.isEmpty || newPass2.isEmpty) {
      _snack('Company Code, Sicil No, Davet Kodu ve Yeni Şifre zorunlu.');
      return;
    }
    if (newPass.length < 6) {
      _snack('Yeni şifre en az 6 karakter olmalı.');
      return;
    }
    if (newPass != newPass2) {
      _snack('Şifreler aynı değil.');
      return;
    }

    setState(() => _loading = true);

    try {
      // ✅ 1) Önce AUTH (Firestore'a dokunma!)
      final emails = _employeeEmailCandidates(codeInput, noInput);
      final preferred = '${codeInput.toLowerCase()}_${_cleanNo(noInput)}@teamduty.local';

      UserCredential cred;

      try {
        // önce invite (ilk şifre) ile giriş dene
        cred = await _signInWithAnyEmail(emails, invite);
      } on FirebaseAuthException catch (e) {
        final c = e.code;

        if (_isAuthMismatchCode(c)) {
          // kullanıcı yok / şifre yanlış / invalid-credential -> create dene
          try {
            cred = await _auth.createUserWithEmailAndPassword(
              email: preferred,
              password: invite,
            );
          } on FirebaseAuthException catch (e2) {
            if (e2.code == 'email-already-in-use') {
              // Hesap var ama invite şifresi tutmadı -> daha önce aktive edilmiş
              throw Exception(
                'Bu çalışan hesabı zaten aktif edilmiş. Aktivasyon yerine normal Çalışan Giriş ekranından kendi şifrenle giriş yap.',
              );
            }
            rethrow;
          }
        } else {
          rethrow;
        }
      }

      final u = cred.user!;
      // ✅ Buradan sonra request.auth != null

      // ✅ 2) companyCode -> companyId (signed-in olduğumuz için rules geçer)
      final codeDoc = await _getCompanyCodeDocSignedIn(codeInput);
      final companyId = codeDoc.data()?['companyId'] as String?;
      if (companyId == null || companyId.isEmpty) {
        throw Exception('companyCodes/${codeDoc.id} içinde companyId yok.');
      }

      // ✅ 3) users/{uid}.activeCompanyId set
      await _db.collection('users').doc(u.uid).set(
        {
          'email': u.email,
          'activeCompanyId': companyId,
          'lastCompanyCode': codeDoc.id,
          'updatedAt': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      // ✅ 4) members/{uid} oluştur (rules burada invite doğruluyor)
      final memberRef = _db.collection('companies').doc(companyId).collection('members').doc(u.uid);

      await memberRef.set(
        {
          'role': 'employee',
          'displayName': name.isEmpty ? 'Çalışan' : name,
          'employeeNo': _cleanNo(noInput),
          'departmentId': null,
          'inviteCode': invite,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      // ✅ 5) Invite usedBy/usedAt işaretle (okumadan update)
      // Rules engellerse bile üyelik oluştuysa sistem çalışır.
      try {
        await _db.collection('companies').doc(companyId).collection('invites').doc(invite).update({
          'usedBy': u.uid,
          'usedAt': FieldValue.serverTimestamp(),
        });
      } catch (_) {}

      // ✅ 6) Şifreyi yeni şifreye çevir
      try {
        await u.updatePassword(newPass);
      } catch (_) {}

      if (!mounted) return;
      _snack('Aktivasyon tamam ✅');
      context.go('/employee');
    } on FirebaseAuthException catch (e) {
      _snack('Auth hata: ${e.message ?? e.code}');
    } on FirebaseException catch (e) {
      _snack('Firestore hata: ${e.code}');
    } catch (e) {
      _snack('Hata: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('İlk Giriş / Aktivasyon')),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                'Davet kodun ile hesabını aktif et ve yeni şifreni belirle.',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _companyCode,
                decoration: const InputDecoration(labelText: 'Company Code', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _employeeNo,
                decoration: const InputDecoration(labelText: 'Sicil No', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _inviteCode,
                decoration: const InputDecoration(labelText: 'Davet Kodu (ilk şifre)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _displayName,
                decoration: const InputDecoration(labelText: 'Ad Soyad (opsiyonel)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _pass1,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Yeni Şifre', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _pass2,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Yeni Şifre (tekrar)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _loading ? null : _activate,
                child: Text(_loading ? 'Aktif ediliyor...' : 'Aktivasyonu Tamamla'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _loading ? null : () => context.pop(),
                child: const Text('Geri dön'),
              ),
            ],
          ),
          if (_loading)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.08),
                child: const Center(child: CircularProgressIndicator()),
              ),
            ),
        ],
      ),
    );
  }
}
