import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:teamduty/ui/td_scaffold.dart';

class EmployeesPage extends StatelessWidget {
  const EmployeesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final u = FirebaseAuth.instance.currentUser;
    if (u == null) return const TDScaffold(body: Center(child: Text('Oturum yok')));

    final userDocStream = FirebaseFirestore.instance.collection('users').doc(u.uid).snapshots();

    return TDScaffold(
      appBar: AppBar(
        title: Text('Çalışanlar', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            tooltip: 'Davet Oluştur',
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.person_add_alt_1_rounded, color: Colors.white)
            ),
            onPressed: () => context.push('/admin/invite'),
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: userDocStream,
        builder: (context, userSnap) {
          final companyId = userSnap.data?.data()?['activeCompanyId'] as String?;
          if (companyId == null || companyId.isEmpty) {
             return Center(child: Text('Aktif şirket bulunamadı.', style: GoogleFonts.outfit(color: Colors.white)));
          }

          final depsStream = FirebaseFirestore.instance.collection('companies').doc(companyId).collection('departments').snapshots();
          final employeesStream = FirebaseFirestore.instance.collection('companies').doc(companyId).collection('members').where('role', isEqualTo: 'employee').snapshots();

          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: depsStream,
            builder: (context, depSnap) {
              return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: employeesStream,
                builder: (context, empSnap) {
                  if (depSnap.hasError) return Center(child: Text('Departman hata: ${depSnap.error}', style: GoogleFonts.outfit(color: Colors.white)));
                  if (empSnap.hasError) return Center(child: Text('Çalışan hata: ${empSnap.error}', style: GoogleFonts.outfit(color: Colors.white)));
                  if (!depSnap.hasData || !empSnap.hasData) return const Center(child: CircularProgressIndicator(color: Colors.white));

                  final deptNameById = <String, String>{};
                  for (final d in depSnap.data!.docs) {
                    deptNameById[d.id] = (d.data()['name'] ?? '-') as String;
                  }

                  final employees = empSnap.data!.docs.toList();
                  employees.sort((a, b) {
                    final an = ((a.data()['displayName'] ?? '') as String).toLowerCase();
                    final bn = ((b.data()['displayName'] ?? '') as String).toLowerCase();
                    return an.compareTo(bn);
                  });

                  if (employees.isEmpty) {
                    return Center(child: Text('Henüz çalışan yok.', style: GoogleFonts.outfit(color: Colors.white60)));
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: employees.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, i) {
                      final doc = employees[i];
                      final data = doc.data();
                      final uid = doc.id;

                      final name = (data['displayName'] ?? uid) as String;
                      final employeeNo = (data['employeeNo'] ?? '-') as String;
                      final depId = (data['departmentId'] ?? '') as String;
                      final depName = depId.isEmpty ? 'Atanmamış' : (deptNameById[depId] ?? 'Bilinmeyen');

                      return _EmployeeCard(
                         name: name,
                         employeeNo: employeeNo,
                         depName: depName,
                         onEdit: () async {
                           await showDialog(
                              context: context,
                              builder: (_) => _EditEmployeeDialog(
                                companyId: companyId,
                                uid: uid,
                                initialName: name,
                                initialNo: employeeNo,
                                initialDepartmentId: depId,
                                deptNameById: deptNameById,
                              ),
                           );
                         },
                         onDelete: () async {
                            final ok = await showDialog<bool>(
                              context: context,
                              builder: (_) => AlertDialog(
                                backgroundColor: const Color(0xFF1E293B),
                                title: Text('Çalışanı Sil', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
                                content: Text('$name şirketten çıkarılsın mı?\n\nNot: Firebase Auth hesabı silinmez ama şirket verilerine erişemez.', style: GoogleFonts.outfit(color: Colors.white70)),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Vazgeç', style: GoogleFonts.outfit(color: Colors.white60))),
                                  TextButton(onPressed: () => Navigator.pop(context, true), child: Text('Sil', style: GoogleFonts.outfit(color: Colors.redAccent, fontWeight: FontWeight.bold))),
                                ],
                              ),
                            );

                            if (ok == true) {
                              await FirebaseFirestore.instance.collection('companies').doc(companyId).collection('members').doc(uid).delete();
                            }
                         },
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _EmployeeCard extends StatelessWidget {
  final String name;
  final String employeeNo;
  final String depName;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _EmployeeCard({required this.name, required this.employeeNo, required this.depName, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
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
                  Text(name, style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.badge_outlined, size: 14, color: Colors.white54),
                      const SizedBox(width: 4),
                      Text(employeeNo, style: GoogleFonts.outfit(color: Colors.white54, fontSize: 13)),
                      const SizedBox(width: 12),
                      Icon(Icons.apartment_outlined, size: 14, color: Colors.white54),
                      const SizedBox(width: 4),
                      Text(depName, style: GoogleFonts.outfit(color: Colors.white54, fontSize: 13)),
                    ],
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded, color: Colors.white70),
              color: const Color(0xFF1E293B),
              itemBuilder: (_) => [
                 PopupMenuItem(value: 'edit', child: Text('Düzenle', style: GoogleFonts.outfit(color: Colors.white))),
                 PopupMenuItem(value: 'delete', child: Text('Sil', style: GoogleFonts.outfit(color: Colors.redAccent))),
              ],
              onSelected: (v) {
                if (v == 'edit') onEdit();
                if (v == 'delete') onDelete();
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _EditEmployeeDialog extends StatefulWidget {
  const _EditEmployeeDialog({
    required this.companyId,
    required this.uid,
    required this.initialName,
    required this.initialNo,
    required this.initialDepartmentId,
    required this.deptNameById,
  });

  final String companyId;
  final String uid;
  final String initialName;
  final String initialNo;
  final String initialDepartmentId;
  final Map<String, String> deptNameById;

  @override
  State<_EditEmployeeDialog> createState() => _EditEmployeeDialogState();
}

class _EditEmployeeDialogState extends State<_EditEmployeeDialog> {
  late final TextEditingController _name;
  late final TextEditingController _no;
  String? _depId;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.initialName);
    _no = TextEditingController(text: widget.initialNo);
    _depId = widget.initialDepartmentId.isEmpty ? null : widget.initialDepartmentId;
  }

  @override
  void dispose() {
    _name.dispose();
    _no.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    final no = _no.text.trim();
    if (name.isEmpty || no.isEmpty) return;

    setState(() => _loading = true);
    try {
      await FirebaseFirestore.instance.collection('companies').doc(widget.companyId).collection('members').doc(widget.uid).set(
        {'displayName': name, 'employeeNo': no, 'departmentId': _depId, 'updatedAt': FieldValue.serverTimestamp()},
        SetOptions(merge: true),
      );
      if (!mounted) return;
      Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1E293B),
      title: Text('Çalışanı Güncelle', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildInput(controller: _name, label: 'Ad Soyad'),
          const SizedBox(height: 12),
          _buildInput(controller: _no, label: 'Çalışan No'),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
             decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white12)),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String?>(
                value: _depId,
                isExpanded: true,
                dropdownColor: const Color(0xFF1E293B),
                style: GoogleFonts.outfit(color: Colors.white),
                hint: Text('Departman Seç', style: GoogleFonts.outfit(color: Colors.white54)),
                items: [
                  DropdownMenuItem(value: null, child: Text('Departman yok', style: GoogleFonts.outfit(color: Colors.white))),
                  ...widget.deptNameById.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value, style: GoogleFonts.outfit(color: Colors.white)))),
                ],
                onChanged: (v) => setState(() => _depId = v),
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: _loading ? null : () => Navigator.pop(context), child: Text('İptal', style: GoogleFonts.outfit(color: Colors.white60))),
        TextButton(onPressed: _loading ? null : _save, child: Text(_loading ? 'Kaydediliyor...' : 'Kaydet', style: GoogleFonts.outfit(color: const Color(0xFF4C51BF), fontWeight: FontWeight.bold))),
      ],
    );
  }

  Widget _buildInput({required TextEditingController controller, required String label}) {
    return Container(
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white12)),
      child: TextField(
        controller: controller,
        style: GoogleFonts.outfit(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: GoogleFonts.outfit(color: Colors.white54),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }
}
