import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:teamduty/ui/td_scaffold.dart';

import '../../services/admin_company_service.dart';
import '../../services/invite_service.dart';

class CreateInvitePage extends StatefulWidget {
  const CreateInvitePage({super.key});

  @override
  State<CreateInvitePage> createState() => _CreateInvitePageState();
}

class _CreateInvitePageState extends State<CreateInvitePage> {
  final _empName = TextEditingController();
  final _empNo = TextEditingController();
  bool _loading = false;

  late Future<AdminCompany?> _companyFuture;

  @override
  void initState() {
    super.initState();
    _companyFuture = AdminCompanyService().getMyActiveAdminCompany();
  }

  @override
  void dispose() {
    _empName.dispose();
    _empNo.dispose();
    super.dispose();
  }

  void _refresh() {
    setState(() {
      _companyFuture = AdminCompanyService().getMyActiveAdminCompany();
    });
  }

  Future<void> _createInvite(AdminCompany c) async {
    final name = _empName.text.trim();
    final no = _empNo.text.trim();

    if (name.isEmpty || no.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Çalışan adı ve numarası zorunlu.', style: GoogleFonts.outfit(color: Colors.white)),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      final code = await InviteService().createEmployeeInvite(
        companyId: c.companyId,
        employeeNo: no,
        displayName: name,
      );

      if (!mounted) return;

      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          title: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.greenAccent),
              const SizedBox(width: 10),
              Text('Davet Oluşturuldu', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _infoRow('Şirket Kodu', c.companyCode),
              const SizedBox(height: 8),
              _infoRow('Çalışan No', no),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: const Color(0xFF4C51BF).withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('DAVET KODU (İLK ŞİFRE)', style: GoogleFonts.outfit(color: Colors.white60, fontSize: 10, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    SelectableText(code, style: GoogleFonts.outfit(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                         const Icon(Icons.copy, size: 14, color: Colors.white54),
                         const SizedBox(width: 4),
                         GestureDetector(
                           onTap: () {
                             Clipboard.setData(ClipboardData(text: code));
                             ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Kopyalandı', style: GoogleFonts.outfit())));
                           },
                           child: Text('Kopyala', style: GoogleFonts.outfit(color: Colors.white54, fontSize: 12, decoration: TextDecoration.underline)),
                         )
                      ],
                    )
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Tamam', style: GoogleFonts.outfit(color: Colors.white)),
            ),
          ],
        ),
      );

      _empName.clear();
      _empNo.clear();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hata: $e', style: GoogleFonts.outfit(color: Colors.white)), backgroundColor: Colors.redAccent),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _infoRow(String label, String value) {
    return RichText(
      text: TextSpan(
        style: GoogleFonts.outfit(color: Colors.white70),
        children: [
          TextSpan(text: '$label: ', style: const TextStyle(fontWeight: FontWeight.bold)),
          TextSpan(text: value, style: const TextStyle(color: Colors.white)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return TDScaffold(
      appBar: AppBar(
        title: Text('Çalışan Daveti', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh, color: Colors.white)),
        ],
      ),
      body: FutureBuilder<AdminCompany?>(
        future: _companyFuture,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: Colors.white));
          if (snap.hasError) return Center(child: Text('Hata: ${snap.error}', style: GoogleFonts.outfit(color: Colors.white)));

          final company = snap.data;
          if (company == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Şirket Bulunamadı', style: GoogleFonts.outfit(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text('Önce şirket oluşturmalısın.', style: GoogleFonts.outfit(color: Colors.white60)),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: () => context.push('/company/create'),
                    style: FilledButton.styleFrom(backgroundColor: const Color(0xFF4C51BF)),
                    child: Text('Şirket Oluştur', style: GoogleFonts.outfit(color: Colors.white)),
                  ),
                ],
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF4C51BF), Color(0xFF6B46C1)]),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: const Color(0xFF4C51BF).withOpacity(0.4), blurRadius: 10, offset: const Offset(0, 4))],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.business_rounded, color: Colors.white)),
                        const SizedBox(width: 12),
                        Expanded(child: Text(company.companyName, style: GoogleFonts.outfit(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold))),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(8)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('ŞİRKET KODU: ', style: GoogleFonts.outfit(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                          Text(company.companyCode, style: GoogleFonts.outfit(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Yeni Davet', style: GoogleFonts.outfit(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 20),
                    _buildInput(controller: _empName, label: 'Çalışan Ad Soyad', icon: Icons.person_outline),
                    const SizedBox(height: 16),
                    _buildInput(controller: _empNo, label: 'Çalışan Numarası (Sicil)', icon: Icons.badge_outlined),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _loading ? null : () => _createInvite(company),
                        style: ElevatedButton.styleFrom(
                           backgroundColor: const Color(0xFF4C51BF),
                           foregroundColor: Colors.white,
                           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                           elevation: 4,
                        ),
                        child: _loading ? const CircularProgressIndicator(color: Colors.white) : Text('Davet Oluştur', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildInput({required TextEditingController controller, required String label, required IconData icon}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: TextField(
        controller: controller,
        style: GoogleFonts.outfit(color: Colors.white),
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: Colors.white54),
          labelText: label,
          labelStyle: GoogleFonts.outfit(color: Colors.white54),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }
}
