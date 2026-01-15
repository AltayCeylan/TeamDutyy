import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:teamduty/ui/td_scaffold.dart';

class ManagersPage extends StatelessWidget {
  const ManagersPage({super.key});

  @override
  Widget build(BuildContext context) {
    final u = FirebaseAuth.instance.currentUser;
    if (u == null) return const TDScaffold(body: Center(child: Text('Oturum yok')));

    final userDocStream = FirebaseFirestore.instance.collection('users').doc(u.uid).snapshots();

    return TDScaffold(
      appBar: AppBar(
        title: Text('Müdürler', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: userDocStream,
        builder: (context, userSnap) {
          if (userSnap.hasError) return Center(child: Text('Hata: ${userSnap.error}', style: GoogleFonts.outfit(color: Colors.white)));
          if (!userSnap.hasData) return const Center(child: CircularProgressIndicator(color: Colors.white));

          final companyId = userSnap.data!.data()?['activeCompanyId'] as String?;
          if (companyId == null || companyId.isEmpty) return const Center(child: Text('Aktif şirket bulunamadı.'));

          final depsStream = FirebaseFirestore.instance.collection('companies').doc(companyId).collection('departments').snapshots();
          final managersStream = FirebaseFirestore.instance.collection('companies').doc(companyId).collection('members').where('role', isEqualTo: 'manager').snapshots();
          final employeesStream = FirebaseFirestore.instance.collection('companies').doc(companyId).collection('members').where('role', isEqualTo: 'employee').snapshots();

          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: depsStream,
            builder: (context, depSnap) {
              if (depSnap.hasError) return Center(child: Text('Hata: ${depSnap.error}', style: GoogleFonts.outfit(color: Colors.white)));
              
              final deptNameById = <String, String>{};
              if (depSnap.hasData) {
                for (final d in depSnap.data!.docs) {
                  deptNameById[d.id] = (d.data()['name'] ?? '-') as String;
                }
              }

              return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: employeesStream,
                builder: (context, empSnap) {
                  final employees = empSnap.data?.docs ?? [];
                  employees.sort((a,b) => ((a.data()['displayName'] ?? '') as String).compareTo((b.data()['displayName'] ?? '') as String));

                  return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: managersStream,
                    builder: (context, manSnap) {
                      if (!manSnap.hasData) return const Center(child: CircularProgressIndicator(color: Colors.white));

                      final managers = manSnap.data!.docs;
                      
                      return ListView(
                        padding: const EdgeInsets.all(20),
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFF4C51BF).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFF4C51BF).withOpacity(0.3)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.info_outline, color: Colors.white70),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'Müdürler, sadece atandıkları departman verilerini görebilir.',
                                    style: GoogleFonts.outfit(color: Colors.white70, fontSize: 13),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          
                          _GradientButton(
                             icon: Icons.person_add_alt_1_rounded,
                             text: 'Yeni Müdür Ata',
                             onPressed: (employees.isEmpty || deptNameById.isEmpty) 
                                ? null 
                                : () async {
                                     await showDialog(
                                       context: context,
                                       builder: (_) => _PromoteToManagerDialog(
                                         companyId: companyId,
                                         employees: employees,
                                         deptNameById: deptNameById,
                                       ),
                                     );
                                  },
                          ),

                          const SizedBox(height: 24),

                          if (deptNameById.isEmpty)
                             Center(child: Text('Önce departman ekleyin.', style: GoogleFonts.outfit(color: Colors.white60)))
                          else if (managers.isEmpty)
                             Center(child: Text('Henüz müdür yok.', style: GoogleFonts.outfit(color: Colors.white60)))
                          else
                             ...managers.map((doc) {
                               final data = doc.data();
                               final uid = doc.id;
                               final name = (data['displayName'] ?? uid) as String;
                               final depId = (data['departmentId'] ?? '') as String;
                               final depName = depId.isEmpty ? 'Atanmamış' : (deptNameById[depId] ?? depId);

                               return Padding(
                                 padding: const EdgeInsets.only(bottom: 12),
                                 child: _ManagerCard(
                                   name: name,
                                   depName: depName,
                                   onEdit: () async {
                                     await showDialog(
                                        context: context,
                                        builder: (_) => _EditManagerDialog(
                                          companyId: companyId,
                                          uid: uid,
                                          initialName: name,
                                          initialDepartmentId: depId,
                                          deptNameById: deptNameById,
                                        ),
                                     );
                                   },
                                   onDowngrade: () async {
                                      final ok = await showDialog<bool>(
                                        context: context,
                                        builder: (_) => AlertDialog(
                                          backgroundColor: const Color(0xFF1E293B),
                                          title: Text('Yetkiyi Düşür', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
                                          content: Text('$name kişisi tekrar "çalışan" rolüne düşürülsün mü?', style: GoogleFonts.outfit(color: Colors.white70)),
                                          actions: [
                                            TextButton(onPressed: () => Navigator.pop(context, false), child: Text('İptal', style: GoogleFonts.outfit(color: Colors.white60))),
                                            TextButton(onPressed: () => Navigator.pop(context, true), child: Text('Evet', style: GoogleFonts.outfit(color: const Color(0xFF4C51BF), fontWeight: FontWeight.bold))),
                                          ],
                                        ),
                                      );
                                      if (ok == true) {
                                        await FirebaseFirestore.instance.collection('companies').doc(companyId).collection('members').doc(uid).set({'role': 'employee', 'updatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
                                      }
                                   },
                                   onDelete: () async {
                                      final ok = await showDialog<bool>(
                                        context: context,
                                        builder: (_) => AlertDialog(
                                          backgroundColor: const Color(0xFF1E293B),
                                          title: Text('Müdürü Sil', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
                                          content: Text('$name şirketten çıkarılsın mı?', style: GoogleFonts.outfit(color: Colors.white70)),
                                          actions: [
                                            TextButton(onPressed: () => Navigator.pop(context, false), child: Text('İptal', style: GoogleFonts.outfit(color: Colors.white60))),
                                            TextButton(onPressed: () => Navigator.pop(context, true), child: Text('Sil', style: GoogleFonts.outfit(color: Colors.redAccent, fontWeight: FontWeight.bold))),
                                          ],
                                        ),
                                      );
                                      if (ok == true) {
                                        await FirebaseFirestore.instance.collection('companies').doc(companyId).collection('members').doc(uid).delete();
                                      }
                                   },
                                 ),
                               );
                             }),
                        ],
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

class _ManagerCard extends StatelessWidget {
  final String name;
  final String depName;
  final VoidCallback onEdit;
  final VoidCallback onDowngrade;
  final VoidCallback onDelete;

  const _ManagerCard({required this.name, required this.depName, required this.onEdit, required this.onDowngrade, required this.onDelete});

  @override
  Widget build(BuildContext context) {
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
            decoration: BoxDecoration(color: const Color(0xFF4C51BF).withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.manage_accounts_rounded, color: Color(0xFF4C51BF)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 4),
                Text(depName, style: GoogleFonts.outfit(color: Colors.white54, fontSize: 13)),
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded, color: Colors.white70),
            color: const Color(0xFF1E293B),
            onSelected: (v) {
              if (v == 'edit') onEdit();
              if (v == 'downgrade') onDowngrade();
              if (v == 'delete') onDelete();
            },
            itemBuilder: (_) => [
               PopupMenuItem(value: 'edit', child: Text('Düzenle', style: GoogleFonts.outfit(color: Colors.white))),
               PopupMenuItem(value: 'downgrade', child: Text('Çalışan Yap', style: GoogleFonts.outfit(color: Colors.white))),
               PopupMenuItem(value: 'delete', child: Text('Sil', style: GoogleFonts.outfit(color: Colors.redAccent))),
            ],
          ),
        ],
      ),
    );
  }
}

class _PromoteToManagerDialog extends StatefulWidget {
  final String companyId;
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> employees;
  final Map<String, String> deptNameById;

  const _PromoteToManagerDialog({required this.companyId, required this.employees, required this.deptNameById});

  @override
  State<_PromoteToManagerDialog> createState() => _PromoteToManagerDialogState();
}

class _PromoteToManagerDialogState extends State<_PromoteToManagerDialog> {
  String? _selectedEmployeeUid;
  String? _depId;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    if (widget.employees.isNotEmpty) _selectedEmployeeUid = widget.employees.first.id;
  }

  Future<void> _save() async {
    if (_selectedEmployeeUid == null || _depId == null) return;
    setState(() => _loading = true);
    try {
      await FirebaseFirestore.instance.collection('companies').doc(widget.companyId).collection('members').doc(_selectedEmployeeUid).set(
        {'role': 'manager', 'departmentId': _depId, 'updatedAt': FieldValue.serverTimestamp()},
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
      title: Text('Çalışanı Müdür Yap', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
             padding: const EdgeInsets.symmetric(horizontal: 12),
             decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white12)),
             child: DropdownButtonHideUnderline(
               child: DropdownButton<String>(
                 value: _selectedEmployeeUid,
                 isExpanded: true,
                 dropdownColor: const Color(0xFF1E293B),
                 hint: Text('Çalışan Seç', style: GoogleFonts.outfit(color: Colors.white54)),
                 items: widget.employees.map((e) {
                   final d = e.data();
                   return DropdownMenuItem(
                     value: e.id,
                     child: Text((d['displayName'] ?? e.id) as String, style: GoogleFonts.outfit(color: Colors.white)),
                   );
                 }).toList(),
                 onChanged: (v) => setState(() => _selectedEmployeeUid = v),
               ),
             ),
          ),
          const SizedBox(height: 12),
          Container(
             padding: const EdgeInsets.symmetric(horizontal: 12),
             decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white12)),
             child: DropdownButtonHideUnderline(
               child: DropdownButton<String>(
                 value: _depId,
                 isExpanded: true,
                 dropdownColor: const Color(0xFF1E293B),
                 hint: Text('Departman Seç', style: GoogleFonts.outfit(color: Colors.white54)),
                 items: widget.deptNameById.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value, style: GoogleFonts.outfit(color: Colors.white)))).toList(),
                 onChanged: (v) => setState(() => _depId = v),
               ),
             ),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text('İptal', style: GoogleFonts.outfit(color: Colors.white60))),
        TextButton(onPressed: _loading ? null : _save, child: Text('Kaydet', style: GoogleFonts.outfit(color: const Color(0xFF4C51BF), fontWeight: FontWeight.bold))),
      ],
    );
  }
}

class _EditManagerDialog extends StatefulWidget {
  final String companyId;
  final String uid;
  final String initialName;
  final String initialDepartmentId;
  final Map<String, String> deptNameById;

  const _EditManagerDialog({required this.companyId, required this.uid, required this.initialName, required this.initialDepartmentId, required this.deptNameById});

  @override
  State<_EditManagerDialog> createState() => _EditManagerDialogState();
}

class _EditManagerDialogState extends State<_EditManagerDialog> {
  late final TextEditingController _name;
  String? _depId;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.initialName);
    _depId = widget.initialDepartmentId.isEmpty ? null : widget.initialDepartmentId;
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty || _depId == null) return;
    setState(() => _loading = true);
    try {
      await FirebaseFirestore.instance.collection('companies').doc(widget.companyId).collection('members').doc(widget.uid).set(
        {'displayName': name, 'departmentId': _depId, 'updatedAt': FieldValue.serverTimestamp()},
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
      title: Text('Müdürü Güncelle', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
             decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white12)),
             child: TextField(
               controller: _name,
               style: GoogleFonts.outfit(color: Colors.white),
               decoration: InputDecoration(
                 labelText: 'Ad Soyad',
                 labelStyle: GoogleFonts.outfit(color: Colors.white54),
                 border: InputBorder.none,
                 contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
               ),
             ),
          ),
          const SizedBox(height: 12),
          Container(
             padding: const EdgeInsets.symmetric(horizontal: 12),
             decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white12)),
             child: DropdownButtonHideUnderline(
               child: DropdownButton<String>(
                 value: _depId,
                 isExpanded: true,
                 dropdownColor: const Color(0xFF1E293B),
                 hint: Text('Departman Seç', style: GoogleFonts.outfit(color: Colors.white54)),
                 items: widget.deptNameById.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value, style: GoogleFonts.outfit(color: Colors.white)))).toList(),
                 onChanged: (v) => setState(() => _depId = v),
               ),
             ),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text('İptal', style: GoogleFonts.outfit(color: Colors.white60))),
        TextButton(onPressed: _loading ? null : _save, child: Text('Kaydet', style: GoogleFonts.outfit(color: const Color(0xFF4C51BF), fontWeight: FontWeight.bold))),
      ],
    );
  }
}

class _GradientButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final String text;
  final IconData icon;

  const _GradientButton({required this.onPressed, required this.text, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: onPressed == null ? 0.5 : 1,
      child: Container(
        width: double.infinity,
        height: 50,
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF4C51BF), Color(0xFF6B46C1)]),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: const Color(0xFF4C51BF).withOpacity(0.4), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(14),
            child: Row(
               mainAxisAlignment: MainAxisAlignment.center,
               children: [
                 Icon(icon, color: Colors.white),
                 const SizedBox(width: 10),
                 Text(text, style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
               ],
            ),
          ),
        ),
      ),
    );
  }
}
