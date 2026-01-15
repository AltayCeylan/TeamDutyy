import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'dart:ui'; // For clamp

enum LoginMode { admin, employee }

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with SingleTickerProviderStateMixin {
  LoginMode _mode = LoginMode.employee; // Varsayılan çalışan olsun
  late TabController _tabController;

  // Admin
  final _adminEmail = TextEditingController();
  final _adminPass = TextEditingController();

  // Employee
  final _companyCode = TextEditingController();
  final _employeeNo = TextEditingController();
  final _employeePass = TextEditingController();

  // Activation (ilk giriş)
  bool _isActivation = false;
  final _inviteCode = TextEditingController();
  final _newPass1 = TextEditingController();
  final _newPass2 = TextEditingController();
  final _displayName = TextEditingController();

  bool _loading = false;

  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this, initialIndex: 1);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {
          _mode = _tabController.index == 0 ? LoginMode.admin : LoginMode.employee;
        });
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _adminEmail.dispose();
    _adminPass.dispose();

    _companyCode.dispose();
    _employeeNo.dispose();
    _employeePass.dispose();

    _inviteCode.dispose();
    _newPass1.dispose();
    _newPass2.dispose();
    _displayName.dispose();
    super.dispose();
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.redAccent.shade700,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  String _cleanNo(String s) => s.trim().toLowerCase();

  /// Eski/yeni olası employee email formatlarını dener.
  List<String> _employeeEmailCandidates(String companyCode, String employeeNo) {
    final c = companyCode.trim();
    final nRaw = employeeNo.trim();
    final n = _cleanNo(nRaw);

    final candidates = <String>{
      // standart
      '${c.toLowerCase()}_${n}@teamduty.local',
      '${c.toUpperCase()}_${n}@teamduty.local',

      // dash
      '${c.toLowerCase()}-${n}@teamduty.local',
      '${c.toUpperCase()}-${n}@teamduty.local',

      // concat legacy
      '${c.toLowerCase()}${n}@teamduty.local',
      '${c.toUpperCase()}${n}@teamduty.local',

      // sadece no (aşırı legacy)
      '${n}@teamduty.local',

      // raw input
      '${c}_${nRaw}@teamduty.local',
      '${c}-${nRaw}@teamduty.local',
    };

    return candidates.toList();
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

  /// companyCodes doc'unu raw/UPPER/lower ile bulur.
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

  Future<String> _setActiveCompanyIdFromCode(String companyCode) async {
    final u = _auth.currentUser;
    if (u == null) throw Exception('Oturum yok');

    final codeDoc = await _getCompanyCodeDocSignedIn(companyCode);
    final companyId = codeDoc.data()?['companyId'] as String?;

    if (companyId == null || companyId.isEmpty) {
      throw Exception('companyCodes/${codeDoc.id} içinde companyId yok.');
    }

    await _db.collection('users').doc(u.uid).set(
      {
        'email': u.email,
        'activeCompanyId': companyId,
        'lastCompanyCode': codeDoc.id,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    return companyId;
  }

  Future<void> _routeByRole({required String companyId}) async {
    final u = _auth.currentUser;
    if (u == null) return;

    final memberSnap = await _db.collection('companies').doc(companyId).collection('members').doc(u.uid).get();
    final role = memberSnap.data()?['role'] as String? ?? 'employee';

    if (!mounted) return;

    if (role == 'admin') {
      context.go('/admin');
    } else if (role == 'manager') {
      context.go('/manager');
    } else {
      context.go('/employee');
    }
  }

  // =========================
  // ADMIN
  // =========================
  Future<void> _adminSignIn() async {
    final email = _adminEmail.text.trim();
    final pass = _adminPass.text.trim();
    if (email.isEmpty || pass.isEmpty) {
      _snack('Email ve şifre gir.');
      return;
    }

    setState(() => _loading = true);
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: pass);

      final u = _auth.currentUser!;
      final userSnap = await _db.collection('users').doc(u.uid).get();
      final companyId = userSnap.data()?['activeCompanyId'] as String?;

      if (!mounted) return;

      if (companyId == null || companyId.isEmpty) {
        context.go('/company/create');
        return;
      }

      await _routeByRole(companyId: companyId);
    } on FirebaseAuthException catch (e) {
      _snack('Admin giriş hata: ${e.message ?? e.code}');
    } catch (e) {
      _snack('Hata: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _adminSignUp() async {
    final email = _adminEmail.text.trim();
    final pass = _adminPass.text.trim();
    if (email.isEmpty || pass.isEmpty) {
      _snack('Email ve şifre gir.');
      return;
    }
    if (pass.length < 6) {
      _snack('Şifre en az 6 karakter olmalı.');
      return;
    }

    setState(() => _loading = true);
    try {
      final cred = await _auth.createUserWithEmailAndPassword(email: email, password: pass);

      await _db.collection('users').doc(cred.user!.uid).set(
        {
          'email': email,
          'activeCompanyId': null,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      if (!mounted) return;
      context.go('/company/create');
    } on FirebaseAuthException catch (e) {
      _snack('Admin kayıt hata: ${e.message ?? e.code}');
    } catch (e) {
      _snack('Hata: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // =========================
  // EMPLOYEE NORMAL LOGIN
  // =========================
  Future<void> _employeeLogin() async {
    final code = _companyCode.text.trim();
    final no = _employeeNo.text.trim();
    final pass = _employeePass.text.trim();

    if (code.isEmpty || no.isEmpty || pass.isEmpty) {
      _snack('Şirket Kodu + Sicil No + Şifre gir.');
      return;
    }

    setState(() => _loading = true);
    try {
      // 1) Auth sign-in
      final emails = _employeeEmailCandidates(code, no);
      await _signInWithAnyEmail(emails, pass);

      // 2) activeCompanyId set
      final companyId = await _setActiveCompanyIdFromCode(code);

      // 3) role yönlendirme
      await _routeByRole(companyId: companyId);
    } on FirebaseAuthException catch (e) {
      _snack('Çalışan giriş hata: ${e.code}');
    } on FirebaseException catch (e) {
      _snack('Firestore hata: ${e.code}');
    } catch (e) {
      _snack('Hata: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // =========================
  // EMPLOYEE ACTIVATION (FIRST TIME)
  // =========================
  Future<void> _employeeActivate() async {
    final code = _companyCode.text.trim();
    final no = _employeeNo.text.trim();
    final invite = _inviteCode.text.trim();
    final newPass1 = _newPass1.text.trim();
    final newPass2 = _newPass2.text.trim();
    final name = _displayName.text.trim();

    if (code.isEmpty || no.isEmpty || invite.isEmpty) {
      _snack('Şirket Kodu + Sicil No + Davet Kodu gerekli.');
      return;
    }
    if (newPass1.isEmpty || newPass2.isEmpty) {
      _snack('Yeni şifreyi gir.');
      return;
    }
    if (newPass1.length < 6) {
      _snack('Yeni şifre en az 6 karakter olmalı.');
      return;
    }
    if (newPass1 != newPass2) {
      _snack('Yeni şifreler aynı değil.');
      return;
    }

    setState(() => _loading = true);
    try {
      final emails = _employeeEmailCandidates(code, no);
      final preferred = '${code.toLowerCase()}_${_cleanNo(no)}@teamduty.local';

      UserCredential cred;

      // 1) Invite ile login dene
      try {
        cred = await _signInWithAnyEmail(emails, invite);
      } on FirebaseAuthException catch (e) {
        final c = e.code;
        final mismatch = (c == 'invalid-credential' || c == 'wrong-password' || c == 'user-not-found');

        if (!mismatch) rethrow;

        // 2) Olmazsa create dene (invite ilk şifre)
        try {
          cred = await _auth.createUserWithEmailAndPassword(email: preferred, password: invite);
        } on FirebaseAuthException catch (e2) {
          if (e2.code == 'email-already-in-use') {
            throw Exception('Bu çalışan hesabı zaten aktif edilmiş. Aktivasyon yerine normal giriş yap.');
          }
          rethrow;
        }
      }

      final u = cred.user!;

      // 3) activeCompanyId set
      final companyId = await _setActiveCompanyIdFromCode(code);

      // 4) members create (rules invite doğrulamasını burada yapar)
      final memberRef = _db.collection('companies').doc(companyId).collection('members').doc(u.uid);
      await memberRef.set(
        {
          'role': 'employee',
          'displayName': name.isEmpty ? 'Çalışan' : name,
          'employeeNo': _cleanNo(no),
          'departmentId': null,
          'inviteCode': invite,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      // 5) invite usedBy/usedAt (deneme)
      try {
        await _db.collection('companies').doc(companyId).collection('invites').doc(invite).update({
          'usedBy': u.uid,
          'usedAt': FieldValue.serverTimestamp(),
        });
      } catch (_) {}

      // 6) şifreyi yeni şifreye çek
      try {
        await u.updatePassword(newPass1);
      } catch (_) {}

      // 7) role route
      await _routeByRole(companyId: companyId);
    } on FirebaseException catch (e) {
      _snack('Firestore hata: ${e.code}');
    } on FirebaseAuthException catch (e) {
      _snack('Auth hata: ${e.code}');
    } catch (e) {
      _snack('Hata: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // =========================
  // UI COMPONENTS
  // =========================

  Widget _buildInput({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscure = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: Colors.blueGrey.shade400),
          labelText: label,
          labelStyle: TextStyle(color: Colors.blueGrey.shade600),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required VoidCallback onPressed,
    required String text,
    Color? color,
    Color? textColor,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: color ?? const Color(0xFF4C51BF), // Indigo like color
          foregroundColor: textColor ?? Colors.white,
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        onPressed: onPressed,
        child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background Gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          
          // Decorative Circles
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF0F3460).withOpacity(0.5),
              ),
            ),
          ),
          Positioned(
            bottom: -50,
            left: -50,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFE94560).withOpacity(0.1),
              ),
            ),
          ),

          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo / Branding
                  const Icon(Icons.diversity_3, size: 64, color: Colors.white),
                  const SizedBox(height: 16),
                  const Text(
                    'TEAM DUTY',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 2.0,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'İşini yönet, takımını güçlendir.',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.7),
                    ),
                  ),
                  const SizedBox(height: 40),

                  // Login Card
                  Card(
                    elevation: 12,
                    shadowColor: Colors.black26,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                    color: Colors.white,
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        children: [
                          // Custom Tab Bar
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: TabBar(
                              controller: _tabController,
                              indicator: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                color: const Color(0xFF4C51BF),
                                boxShadow: [BoxShadow(color: Colors.blueAccent.withOpacity(0.2), blurRadius: 4)],
                              ),
                              labelColor: Colors.white,
                              unselectedLabelColor: Colors.grey.shade600,
                              indicatorSize: TabBarIndicatorSize.tab,
                              dividerColor: Colors.transparent,
                              tabs: const [
                                Tab(text: 'Yönetici', icon: Icon(Icons.admin_panel_settings_outlined)),
                                Tab(text: 'Çalışan', icon: Icon(Icons.badge_outlined)),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Form Content
                          AnimatedSize(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                            child: _mode == LoginMode.admin 
                              ? _buildAdminForm() 
                              : _buildEmployeeForm(),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Loading Overlay
          if (_loading)
            Container(
              color: Colors.black45,
              child: const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAdminForm() {
    return Column(
      key: const ValueKey('admin'),
      children: [
        _buildInput(controller: _adminEmail, label: 'E-Posta Adresi', icon: Icons.email_outlined),
        _buildInput(controller: _adminPass, label: 'Parola', icon: Icons.lock_outline, obscure: true),
        const SizedBox(height: 24),
        _buildActionButton(onPressed: _adminSignIn, text: 'GİRİŞ YAP'),
        const SizedBox(height: 12),
        TextButton(
          onPressed: _adminSignUp,
          child: const Text('Hesabın yok mu? Kayıt Ol'),
        ),
      ],
    );
  }

  Widget _buildEmployeeForm() {
    return Column(
      key: const ValueKey('employee'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildInput(controller: _companyCode, label: 'Şirket Kodu', icon: Icons.business),
        _buildInput(controller: _employeeNo, label: 'Sicil No', icon: Icons.person_outline),
        
        // Activation Checkbox
        GestureDetector(
          onTap: () => setState(() => _isActivation = !_isActivation),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                SizedBox(
                  height: 24,
                  width: 24,
                  child: Checkbox(
                    value: _isActivation,
                    activeColor: const Color(0xFF4C51BF),
                    onChanged: (v) => setState(() => _isActivation = v ?? false),
                  ),
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text('İlk kez giriş yapıyorum (Aktivasyon)', style: TextStyle(fontSize: 13, color: Colors.blueGrey)),
                ),
              ],
            ),
          ),
        ),
        
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: _isActivation 
            ? Column(
                children: [
                   const SizedBox(height: 8),
                  _buildInput(controller: _inviteCode, label: 'Davet Kodu', icon: Icons.key),
                  _buildInput(controller: _displayName, label: 'Ad Soyad (Opsiyonel)', icon: Icons.text_fields),
                  _buildInput(controller: _newPass1, label: 'Yeni Parola', icon: Icons.lock_outline, obscure: true),
                  _buildInput(controller: _newPass2, label: 'Yeni Parola (Tekrar)', icon: Icons.lock, obscure: true),
                  const SizedBox(height: 24),
                  _buildActionButton(onPressed: _employeeActivate, text: 'HESABI AKTİFLEŞTİR', color: Colors.green.shade600),
                ],
              )
            : Column(
                children: [
                  const SizedBox(height: 8),
                  _buildInput(controller: _employeePass, label: 'Parola', icon: Icons.lock_outline, obscure: true),
                  const SizedBox(height: 24),
                  _buildActionButton(onPressed: _employeeLogin, text: 'GİRİŞ YAP'),
                ],
              ),
        ),
      ],
    );
  }
}
