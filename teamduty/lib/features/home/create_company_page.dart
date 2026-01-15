import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:teamduty/ui/td_scaffold.dart';

import '../../services/company_service.dart';

class CompanyCreatePage extends StatefulWidget {
  const CompanyCreatePage({super.key});

  @override
  State<CompanyCreatePage> createState() => _CompanyCreatePageState();
}

class _CompanyCreatePageState extends State<CompanyCreatePage> {
  final _companyName = TextEditingController();
  final _adminName = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _companyName.dispose();
    _adminName.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final name = _companyName.text.trim();
    final admin = _adminName.text.trim();

    if (name.isEmpty || admin.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Şirket adı ve yönetici adı zorunlu.', style: GoogleFonts.outfit(color: Colors.white)),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      final res = await CompanyService().createCompanyAndMakeMeAdmin(
        companyName: name,
        displayName: admin,
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
               Text('Şirket Oluşturuldu', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
             ],
           ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Şirketiniz kullanıma hazır!', style: GoogleFonts.outfit(color: Colors.white70)),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF4C51BF).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('ŞİRKET KODU', style: GoogleFonts.outfit(color: Colors.white60, fontSize: 10, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    SelectableText(res.code, style: GoogleFonts.outfit(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                         const Icon(Icons.copy, size: 14, color: Colors.white54),
                         const SizedBox(width: 4),
                         GestureDetector(
                           onTap: () {
                             Clipboard.setData(ClipboardData(text: res.code));
                             ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Kopyalandı', style: GoogleFonts.outfit())));
                           },
                           child: Text('Kopyala', style: GoogleFonts.outfit(color: Colors.white54, fontSize: 12, decoration: TextDecoration.underline)),
                         )
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text('Bu kodu çalışanlarınıza vererek şirketinize katılmalarını sağlayabilirsiniz.', style: GoogleFonts.outfit(color: Colors.white60, fontSize: 13)),
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

      if (mounted) context.go('/admin');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hata: $e', style: GoogleFonts.outfit(color: Colors.white)), backgroundColor: Colors.redAccent),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return TDScaffold(
      appBar: AppBar(
         title: Text('Şirket Oluştur', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
         backgroundColor: Colors.transparent,
         iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF16213E), Color(0xFF1A1A2E)]),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white10),
              boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10, offset: const Offset(0, 4))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 70, height: 70,
                    decoration: BoxDecoration(color: const Color(0xFF4C51BF).withOpacity(0.2), shape: BoxShape.circle),
                    child: const Icon(Icons.business_rounded, color: Color(0xFF4C51BF), size: 36),
                  ),
                ),
                const SizedBox(height: 24),
                Text('Yeni bir şirket oluşturun ve ekibinizi yönetmeye başlayın.', style: GoogleFonts.outfit(color: Colors.white70), textAlign: TextAlign.center),
                const SizedBox(height: 32),
                
                _buildInput(controller: _companyName, label: 'Şirket Adı', icon: Icons.store_rounded),
                const SizedBox(height: 16),
                _buildInput(controller: _adminName, label: 'Yönetici Ad Soyad', icon: Icons.person_rounded),
                const SizedBox(height: 32),

                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _create,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4C51BF),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 4,
                    ),
                    child: _loading 
                       ? const CircularProgressIndicator(color: Colors.white) 
                       : Text('Şirketi Oluştur', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ],
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
