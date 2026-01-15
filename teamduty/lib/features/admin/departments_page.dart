import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:teamduty/ui/td_scaffold.dart';

class DepartmentsPage extends StatefulWidget {
  const DepartmentsPage({super.key});

  @override
  State<DepartmentsPage> createState() => _DepartmentsPageState();
}

class _DepartmentsPageState extends State<DepartmentsPage> {
  final _name = TextEditingController();
  bool _creating = false;

  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _snack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.outfit(color: Colors.white)),
        backgroundColor: isError ? Colors.redAccent : Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<void> _createDepartment(String companyId) async {
    final name = _name.text.trim();
    if (name.isEmpty) return;

    setState(() => _creating = true);
    try {
      await _db.collection('companies').doc(companyId).collection('departments').add({
        'name': name,
        'managerUid': null,
        'createdAt': FieldValue.serverTimestamp(),
      });
      _name.clear();
      _snack('Departman oluşturuldu');
    } catch (e) {
      _snack('Hata: $e', isError: true);
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  Future<void> _assignManager({
    required String companyId,
    required String depId,
    required String depName,
    required String? currentManagerUid,
  }) async {
    final membersSnap = await _db
        .collection('companies')
        .doc(companyId)
        .collection('members')
        .where('departmentId', isEqualTo: depId)
        .where('role', whereIn: ['employee', 'manager'])
        .get();

    if (!mounted) return;

    if (membersSnap.docs.isEmpty) {
      _snack('Bu departmanda çalışan yok. Önce çalışan ekle.', isError: true);
      return;
    }

    String? selectedUid;
    await showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          title: Text('Müdür Ata', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
             children: [
               Text('Departman: $depName', style: GoogleFonts.outfit(color: Colors.white70)),
               const SizedBox(height: 16),
               Container(
                 padding: const EdgeInsets.symmetric(horizontal: 12),
                 decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white12)),
                 child: DropdownButtonHideUnderline(
                   child: DropdownButton<String>(
                     value: selectedUid,
                     isExpanded: true,
                     dropdownColor: const Color(0xFF1E293B),
                     style: GoogleFonts.outfit(color: Colors.white),
                     hint: Text('Çalışan Seç', style: GoogleFonts.outfit(color: Colors.white54)),
                     items: membersSnap.docs.map((d) {
                       final data = d.data();
                       final name = (data['displayName'] ?? d.id) as String;
                       final role = (data['role'] ?? '-') as String;
                       return DropdownMenuItem(
                         value: d.id,
                         child: Text('$name ($role)', overflow: TextOverflow.ellipsis, style: GoogleFonts.outfit(color: Colors.white)),
                       );
                     }).toList(),
                     onChanged: (v) => selectedUid = v,
                   ),
                 ),
               ),
             ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('İptal', style: GoogleFonts.outfit(color: Colors.white60)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text('Ata', style: GoogleFonts.outfit(color: const Color(0xFF4C51BF), fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    ).then((ok) async {
      if (ok != true) return;
      if (selectedUid == null) {
        _snack('Çalışan seçmelisin.', isError: true);
        return;
      }

      try {
        final batch = _db.batch();

        final depRef = _db.collection('companies').doc(companyId).collection('departments').doc(depId);
        batch.update(depRef, {
          'managerUid': selectedUid,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        final newMgrRef = _db.collection('companies').doc(companyId).collection('members').doc(selectedUid);
        batch.update(newMgrRef, {
          'role': 'manager',
          'departmentId': depId,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        if (currentManagerUid != null && currentManagerUid.isNotEmpty && currentManagerUid != selectedUid) {
          final oldMgrRef = _db.collection('companies').doc(companyId).collection('members').doc(currentManagerUid);
          batch.update(oldMgrRef, {
            'role': 'employee',
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }

        await batch.commit();
        _snack('Müdür atandı');
      } catch (e) {
        _snack('Hata: $e', isError: true);
      }
    });
  }

  Future<void> _removeManager({
    required String companyId,
    required String depId,
    required String depName,
    required String managerUid,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: Text('Müdürü Kaldır', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text('$depName departmanının müdürü kaldırılacak.\nİlgili kişi "employee" rolüne düşürülecek.', style: GoogleFonts.outfit(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('İptal', style: GoogleFonts.outfit(color: Colors.white60))),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text('Kaldır', style: GoogleFonts.outfit(color: Colors.redAccent, fontWeight: FontWeight.bold))),
        ],
      ),
    );

    if (ok != true) return;

    try {
      final batch = _db.batch();
      final depRef = _db.collection('companies').doc(companyId).collection('departments').doc(depId);

      batch.update(depRef, {
        'managerUid': null,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      final mgrRef = _db.collection('companies').doc(companyId).collection('members').doc(managerUid);

      batch.update(mgrRef, {
        'role': 'employee',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();
      _snack('Müdür kaldırıldı');
    } catch (e) {
      _snack('Hata: $e', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final u = _auth.currentUser;
    if (u == null) return const TDScaffold(body: Center(child: Text('Oturum yok')));

    final userStream = _db.collection('users').doc(u.uid).snapshots();

    return TDScaffold(
      appBar: AppBar(
        title: Text('Departmanlar', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: userStream,
        builder: (context, userSnap) {
          final companyId = userSnap.data?.data()?['activeCompanyId'] as String?;
          if (companyId == null || companyId.isEmpty) return Center(child: Text('Aktif şirket yok.', style: GoogleFonts.outfit(color: Colors.white)));

          final depsStream = _db.collection('companies').doc(companyId).collection('departments').orderBy('createdAt', descending: false).snapshots();
          final membersStream = _db.collection('companies').doc(companyId).collection('members').snapshots();

          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: membersStream,
            builder: (context, memSnap) {
              final nameByUid = <String, String>{};
              if (memSnap.hasData) {
                for (final m in memSnap.data!.docs) {
                  nameByUid[m.id] = (m.data()['displayName'] ?? m.id) as String;
                }
              }

              return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: depsStream,
                builder: (context, depSnap) {
                  if (depSnap.hasError) return Center(child: Text('Hata: ${depSnap.error}', style: GoogleFonts.outfit(color: Colors.white)));
                  if (!depSnap.hasData) return const Center(child: CircularProgressIndicator(color: Colors.white));

                  final deps = depSnap.data!.docs;

                  return ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
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
                             Text('Yeni Departman', style: GoogleFonts.outfit(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                             const SizedBox(height: 16),
                             Container(
                               decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white12)),
                               child: TextField(
                                 controller: _name,
                                 style: GoogleFonts.outfit(color: Colors.white),
                                 decoration: InputDecoration(
                                   labelText: 'Departman Adı',
                                   labelStyle: GoogleFonts.outfit(color: Colors.white54),
                                   hintText: 'Örn: İnsan Kaynakları',
                                   hintStyle: GoogleFonts.outfit(color: Colors.white24),
                                   border: InputBorder.none,
                                   contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                 ),
                               ),
                             ),
                             const SizedBox(height: 16),
                             _GradientButton(
                               onPressed: _creating ? () {} : () => _createDepartment(companyId),
                               text: _creating ? 'Oluşturuluyor...' : 'Departman Oluştur',
                             ),
                           ],
                         ),
                       ),
                       
                       const SizedBox(height: 24),
                       
                       if (deps.isEmpty)
                         Center(child: Text('Henüz departman yok.', style: GoogleFonts.outfit(color: Colors.white60)))
                       else
                         ...deps.map((d) {
                           final managerName = () {
                                final uid = d.data()['managerUid'] as String?;
                                if (uid == null || uid.isEmpty) return null;
                                return nameByUid[uid] ?? uid;
                              }();
                              
                           return Padding(
                             padding: const EdgeInsets.only(bottom: 12),
                             child: _DepartmentCard(
                               depId: d.id,
                               depName: (d.data()['name'] ?? d.id) as String,
                               managerUid: d.data()['managerUid'] as String?,
                               managerName: managerName,
                               onAssign: () => _assignManager(
                                 companyId: companyId,
                                 depId: d.id,
                                 depName: (d.data()['name'] ?? d.id) as String,
                                 currentManagerUid: d.data()['managerUid'] as String?,
                               ),
                               onRemove: (d.data()['managerUid'] is String && (d.data()['managerUid'] as String).isNotEmpty)
                                   ? () => _removeManager(
                                         companyId: companyId,
                                         depId: d.id,
                                         depName: (d.data()['name'] ?? d.id) as String,
                                         managerUid: d.data()['managerUid'] as String,
                                       )
                                   : null,
                             ),
                           );
                         }).toList(),
                    ],
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

class _DepartmentCard extends StatelessWidget {
  final String depId;
  final String depName;
  final String? managerUid;
  final String? managerName;
  final VoidCallback onAssign;
  final VoidCallback? onRemove;

  const _DepartmentCard({required this.depId, required this.depName, required this.managerUid, required this.managerName, required this.onAssign, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final hasMgr = managerUid != null && managerUid!.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: const Color(0xFF4C51BF).withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.apartment_rounded, color: Color(0xFF4C51BF)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(depName, style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
             padding: const EdgeInsets.all(12),
             decoration: BoxDecoration(color: Colors.white.withOpacity(0.03), borderRadius: BorderRadius.circular(12)),
             child: Row(
               children: [
                 Icon(Icons.person_outline, size: 16, color: Colors.white60),
                 const SizedBox(width: 8),
                 Text(hasMgr ? 'Müdür: ${managerName ?? managerUid}' : 'Müdür Atanmamış', style: GoogleFonts.outfit(color: Colors.white70, fontSize: 13, fontWeight: hasMgr ? FontWeight.bold : FontWeight.normal)),
               ],
             ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: onAssign,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    height: 40,
                    decoration: BoxDecoration(
                      color: hasMgr ? Colors.white.withOpacity(0.1) : const Color(0xFF4C51BF).withOpacity(0.8),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Center(child: Text(hasMgr ? 'Müdürü Değiştir' : 'Müdür Ata', style: GoogleFonts.outfit(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold))),
                  ),
                ),
              ),
              if (hasMgr) ...[
                const SizedBox(width: 10),
                InkWell(
                  onTap: onRemove,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    height: 40,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red.withOpacity(0.3)),
                    ),
                    child: const Icon(Icons.person_remove_alt_1_rounded, color: Colors.redAccent, size: 20),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _GradientButton extends StatelessWidget {
  final VoidCallback onPressed;
  final String text;
  const _GradientButton({required this.onPressed, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 48,
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
          child: Center(
             child: Text(text, style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          ),
        ),
      ),
    );
  }
}
