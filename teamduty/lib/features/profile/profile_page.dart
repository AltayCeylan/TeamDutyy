import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../ui/td_scaffold.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;
  bool _loading = true;
  String? _displayName;
  String? _email;
  String? _role;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final u = _auth.currentUser;
    if (u == null) return;

    try {
      final userSnap = await _db.collection('users').doc(u.uid).get();
      final companyId = userSnap.data()?['activeCompanyId'] as String?;

      String? role;
      String? name;

      if (companyId != null) {
        final memSnap = await _db
            .collection('companies')
            .doc(companyId)
            .collection('members')
            .doc(u.uid)
            .get();
        role = memSnap.data()?['role'];
        name = memSnap.data()?['displayName'];
      }

      if (mounted) {
        setState(() {
          _displayName = name ?? u.displayName ?? 'Kullanıcı';
          _email = u.email;
          _role = role ?? 'Belirsiz';
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _signOut() async {
    await _auth.signOut();
    if (mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const TDScaffold(
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    return TDScaffold(
      appBar: AppBar(
        title: Text('Profilim', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => context.pop(),
        ),
      ),
      body: Center(
        child: Container(
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.person_rounded, size: 64, color: Colors.white),
              ),
              const SizedBox(height: 24),
              Text(
                _displayName ?? '-',
                style: GoogleFonts.outfit(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                _email ?? '-',
                style: GoogleFonts.outfit(color: Colors.white70, fontSize: 16),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.blueAccent.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.blueAccent.withOpacity(0.4)),
                ),
                child: Text(
                  'Rol: ${_role?.toUpperCase()}',
                  style: GoogleFonts.outfit(color: Colors.blueAccent, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 48),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _signOut,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent.withOpacity(0.2),
                    foregroundColor: Colors.redAccent,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Colors.redAccent.withOpacity(0.4)),
                    ),
                  ),
                  icon: const Icon(Icons.logout),
                  label: Text('Çıkış Yap', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
