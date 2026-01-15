import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';


class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final _current = TextEditingController();
  final _newPass = TextEditingController();
  final _newPass2 = TextEditingController();

  bool _loading = false;

  @override
  void dispose() {
    _current.dispose();
    _newPass.dispose();
    _newPass2.dispose();
    super.dispose();
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _change() async {
    final cur = _current.text.trim();
    final np = _newPass.text.trim();
    final np2 = _newPass2.text.trim();

    if (cur.isEmpty) return _snack('Mevcut şifreyi yaz.');
    if (np.length < 6) return _snack('Yeni şifre en az 6 karakter olmalı.');
    if (np != np2) return _snack('Yeni şifreler aynı değil.');

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return _snack('Oturum yok.');
    final email = user.email;
    if (email == null) return _snack('Kullanıcı email bulunamadı.');

    setState(() => _loading = true);
    try {
      // ✅ Güvenli değişim için re-auth (Firebase bazen “requires recent login” ister)
      final cred = EmailAuthProvider.credential(email: email, password: cur);
      await user.reauthenticateWithCredential(cred);

      await user.updatePassword(np);
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set(
  {
    'passwordChanged': true,
    'passwordChangedAt': FieldValue.serverTimestamp(),
    'updatedAt': FieldValue.serverTimestamp(),
  },
  SetOptions(merge: true),
);

      if (!mounted) return;
      _snack('Şifre güncellendi ✅');
      context.pop();
    } on FirebaseAuthException catch (e) {
      if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        _snack('Mevcut şifre yanlış.');
      } else if (e.code == 'requires-recent-login') {
        _snack('Güvenlik için tekrar giriş gerekli. Çıkış yapıp tekrar deneyin.');
      } else {
        _snack('Hata: ${e.message ?? e.code}');
      }
    } catch (e) {
      _snack('Hata: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Şifre Değiştir'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: AbsorbPointer(
        absorbing: _loading,
        child: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            TextField(
              controller: _current,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Mevcut Şifre'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _newPass,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Yeni Şifre'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _newPass2,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Yeni Şifre (Tekrar)'),
            ),
            const SizedBox(height: 18),
            SizedBox(
              height: 52,
              child: FilledButton(
                onPressed: _change,
                child: _loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Kaydet'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
