import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ManagerEmployeesTab extends StatefulWidget {
  final String companyId;
  final String deptId;

  const ManagerEmployeesTab({super.key, required this.companyId, required this.deptId});

  @override
  State<ManagerEmployeesTab> createState() => _ManagerEmployeesTabState();
}

class _ManagerEmployeesTabState extends State<ManagerEmployeesTab> {
  final _db = FirebaseFirestore.instance;

  Future<void> _editName(String uid, String current) async {
    final c = TextEditingController(text: current);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: Text('Ad Soyad Güncelle', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Container(
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white12)),
          child: TextField(
            controller: c,
            style: GoogleFonts.outfit(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Ad Soyad',
              labelStyle: GoogleFonts.outfit(color: Colors.white54),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('İptal', style: GoogleFonts.outfit(color: Colors.white60))),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text('Kaydet', style: GoogleFonts.outfit(color: const Color(0xFF4C51BF), fontWeight: FontWeight.bold))),
        ],
      ),
    );

    if (ok != true) return;
    if (c.text.trim().isEmpty) return;

    await _db.collection('companies').doc(widget.companyId).collection('members').doc(uid).update({
      'displayName': c.text.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Widget build(BuildContext context) {
    final membersStream = _db
        .collection('companies')
        .doc(widget.companyId)
        .collection('members')
        .where('departmentId', isEqualTo: widget.deptId)
        .snapshots();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: membersStream,
      builder: (context, snap) {
        if (snap.hasError) return Center(child: Text('Hata: ${snap.error}', style: GoogleFonts.outfit(color: Colors.white)));
        if (!snap.hasData) return const Center(child: CircularProgressIndicator(color: Colors.white));

        final docs = snap.data!.docs;
        if (docs.isEmpty) return Center(child: Text('Bu departmanda çalışan yok.', style: GoogleFonts.outfit(color: Colors.white60)));

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, i) {
            final doc = docs[i];
            final d = doc.data();
            final name = (d['displayName'] ?? '').toString();
            final empNo = (d['employeeNo'] ?? '').toString();
            final role = (d['role'] ?? '').toString();

            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white12),
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                       color: const Color(0xFF4C51BF).withOpacity(0.2),
                       borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.person, color: Color(0xFF4C51BF)),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name.isEmpty ? '(İsimsiz)' : name, style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text('Sicil: $empNo', style: GoogleFonts.outfit(color: Colors.white54, fontSize: 13)),
                            const SizedBox(width: 12),
                            Container(
                               padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                               decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                               child: Text(role.toUpperCase(), style: GoogleFonts.outfit(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, color: Colors.white70),
                    onPressed: () => _editName(doc.id, name),
                    tooltip: 'İsim Düzenle',
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
