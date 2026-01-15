import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ManagerStatsTab extends StatelessWidget {
  final String companyId;
  final String deptId;
  final String myUid;

  const ManagerStatsTab({super.key, required this.companyId, required this.deptId, required this.myUid});

  @override
  Widget build(BuildContext context) {
    final db = FirebaseFirestore.instance;

    final tasksStream = db
        .collection('companies')
        .doc(companyId)
        .collection('tasks')
        .where('departmentId', isEqualTo: deptId)
        .snapshots();

    final membersStream = db
        .collection('companies')
        .doc(companyId)
        .collection('members')
        .where('departmentId', isEqualTo: deptId)
        .snapshots();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: membersStream,
      builder: (context, membersSnap) {
        final uidToName = <String, String>{};
        if (membersSnap.hasData) {
          for (final m in membersSnap.data!.docs) {
            final d = m.data();
            final name = (d['displayName'] ?? '').toString();
            uidToName[m.id] = name;
          }
        }

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: tasksStream,
          builder: (context, tasksSnap) {
            if (tasksSnap.hasError) return Center(child: Text('Hata: ${tasksSnap.error}', style: GoogleFonts.outfit(color: Colors.white)));
            if (!tasksSnap.hasData) return const Center(child: CircularProgressIndicator(color: Colors.white));

            final tasks = tasksSnap.data!.docs.map((e) => e.data()).toList();

            int total = tasks.length;
            int done = tasks.where((t) => (t['status'] ?? '') == 'done').length;
            int pending = tasks.where((t) => (t['status'] ?? '') == 'pending').length;

            final now = DateTime.now();
            int overdue = tasks.where((t) {
              if ((t['status'] ?? '') != 'pending') return false;
              final due = t['dueAt'];
              return due is Timestamp && due.toDate().isBefore(now);
            }).length;

            final perEmployee = <String, Map<String, int>>{};
            for (final t in tasks) {
              final uid = (t['assignedToUid'] ?? '').toString();
              if (uid.isEmpty) continue;
              perEmployee.putIfAbsent(uid, () => {'total': 0, 'done': 0});
              perEmployee[uid]!['total'] = perEmployee[uid]!['total']! + 1;
              if ((t['status'] ?? '') == 'done') {
                perEmployee[uid]!['done'] = perEmployee[uid]!['done']! + 1;
              }
            }

            final items = perEmployee.entries.toList()
              ..sort((a, b) => (b.value['total']!).compareTo(a.value['total']!));

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
                    children: [
                      Text('DEPARTMAN ÖZETİ', style: GoogleFonts.outfit(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _StatItem(label: 'Toplam', value: '$total', icon: Icons.assignment_rounded),
                          _StatItem(label: 'Bekleyen', value: '$pending', icon: Icons.pending_actions_rounded),
                          _StatItem(label: 'Biten', value: '$done', icon: Icons.task_alt_rounded),
                          _StatItem(label: 'Geciken', value: '$overdue', icon: Icons.warning_amber_rounded, isAlert: true),
                        ],
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 24),
                Text('Çalışan Bazlı İstatistik', style: GoogleFonts.outfit(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),

                if (items.isEmpty)
                   Center(child: Text('Veri yok.', style: GoogleFonts.outfit(color: Colors.white60)))
                else
                   ...items.map((e) {
                     final name = uidToName[e.key] ?? e.key;
                     final t = e.value['total']!;
                     final d = e.value['done']!;
                     final p = t > 0 ? (d / t) : 0.0;
                     
                     return Container(
                       margin: const EdgeInsets.only(bottom: 12),
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
                             mainAxisAlignment: MainAxisAlignment.spaceBetween,
                             children: [
                               Text(name.isEmpty ? '(İsimsiz)' : name, style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
                               Text('${(p * 100).toInt()}%', style: GoogleFonts.outfit(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
                             ],
                           ),
                           const SizedBox(height: 8),
                           ClipRRect(
                             borderRadius: BorderRadius.circular(4),
                             child: LinearProgressIndicator(value: p, backgroundColor: Colors.white10, color: Colors.greenAccent, minHeight: 6),
                           ),
                           const SizedBox(height: 8),
                           Row(
                             children: [
                               Text('$t Görev', style: GoogleFonts.outfit(color: Colors.white70, fontSize: 12)),
                               const SizedBox(width: 12),
                               Text('$d Tamamlanan', style: GoogleFonts.outfit(color: Colors.white70, fontSize: 12)),
                             ],
                           ),
                         ],
                       ),
                     );
                   }),
              ],
            );
          },
        );
      },
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final bool isAlert;
  const _StatItem({required this.label, required this.value, required this.icon, this.isAlert = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
        const SizedBox(height: 8),
        Text(value, style: GoogleFonts.outfit(color: isAlert && value != '0' ? Colors.orangeAccent : Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
        Text(label, style: GoogleFonts.outfit(color: Colors.white70, fontSize: 12)),
      ],
    );
  }
}
