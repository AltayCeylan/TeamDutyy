import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

class ManagerTasksTab extends StatefulWidget {
  final String companyId;
  final String deptId;
  final String myUid;

  const ManagerTasksTab({
    super.key,
    required this.companyId,
    required this.deptId,
    required this.myUid,
  });

  @override
  State<ManagerTasksTab> createState() => _ManagerTasksTabState();
}

class _ManagerTasksTabState extends State<ManagerTasksTab> {
  final _db = FirebaseFirestore.instance;

  String _statusFilter = 'all'; 
  bool _onlyMine = false; 
  bool _overdueOnly = false; 

  Stream<QuerySnapshot<Map<String, dynamic>>> _membersStream() {
    return _db.collection('companies').doc(widget.companyId).collection('members').where('departmentId', isEqualTo: widget.deptId).snapshots();
  }

  Query<Map<String, dynamic>> _tasksQuery() {
    Query<Map<String, dynamic>> q = _db
        .collection('companies')
        .doc(widget.companyId)
        .collection('tasks')
        .where('departmentId', isEqualTo: widget.deptId);

    if (_onlyMine) q = q.where('assignedByUid', isEqualTo: widget.myUid);

    if (_overdueOnly) {
      q = q.where('status', isEqualTo: 'pending');
      q = q.where('dueAt', isLessThan: Timestamp.fromDate(DateTime.now()));
    } else if (_statusFilter != 'all') {
      q = q.where('status', isEqualTo: _statusFilter);
    }

    return q.orderBy('createdAt', descending: true);
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _tasksStream() => _tasksQuery().snapshots();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _FiltersBar(
          statusFilter: _statusFilter,
          onlyMine: _onlyMine,
          overdueOnly: _overdueOnly,
          onChanged: (status, mine, overdue) {
            setState(() {
              _statusFilter = status;
              _onlyMine = mine;
              if (overdue) { 
                 _overdueOnly = true; 
                 // Overdue seçilince status pending olmalı ama zaten sorguda hallediliyor, status filter etkisizleşiyor sorguda ama UI için güncellemeyelim, karışabilir.
                 // Basitleştirmek için: overdue seçilince status all'a dönebilir veya olduğu gibi kalır.
              } else {
                 _overdueOnly = false;
              }
            });
          }
        ),
        
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _membersStream(),
            builder: (context, membersSnap) {
              final uidToName = <String, String>{};
              if (membersSnap.hasData) {
                for (final m in membersSnap.data!.docs) {
                  final d = m.data();
                  uidToName[m.id] = (d['displayName'] ?? '').toString();
                }
              }

              return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _tasksStream(),
                builder: (context, snap) {
                  if (snap.hasError) return Center(child: Text('Hata: ${snap.error}', style: GoogleFonts.outfit(color: Colors.white)));
                  if (!snap.hasData) return const Center(child: CircularProgressIndicator(color: Colors.white));

                  final docs = snap.data!.docs;
                  if (docs.isEmpty) return Center(child: Text('Görev bulunamadı.', style: GoogleFonts.outfit(color: Colors.white60)));

                  return ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: docs.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, i) {
                      final doc = docs[i];
                      return _TaskCard(
                        doc: doc,
                        assigneeName: uidToName[doc.data()['assignedToUid']] ?? 'Atanmamış',
                        myUid: widget.myUid,
                        companyId: widget.companyId,
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _FiltersBar extends StatelessWidget {
  final String statusFilter;
  final bool onlyMine;
  final bool overdueOnly;
  final Function(String, bool, bool) onChanged;

  const _FiltersBar({required this.statusFilter, required this.onlyMine, required this.overdueOnly, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: SingleChildScrollView(
         scrollDirection: Axis.horizontal,
         child: Row(
           children: [
             _FilterChip(label: 'Hepsi', isSelected: statusFilter == 'all' && !overdueOnly, onTap: () => onChanged('all', onlyMine, false)),
             const SizedBox(width: 8),
             _FilterChip(label: 'Bekleyen', isSelected: statusFilter == 'pending' && !overdueOnly, onTap: () => onChanged('pending', onlyMine, false)),
             const SizedBox(width: 8),
             _FilterChip(label: 'Biten', isSelected: statusFilter == 'done' && !overdueOnly, onTap: () => onChanged('done', onlyMine, false)),
             const SizedBox(width: 8),
             _FilterChip(label: 'Geciken', isSelected: overdueOnly, isAlert: true, onTap: () => onChanged('all', onlyMine, !overdueOnly)),
             const SizedBox(width: 8),
             _FilterChip(label: 'Oluşturduklarım', isSelected: onlyMine, onTap: () => onChanged(statusFilter, !onlyMine, overdueOnly)),
           ],
         ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isAlert;
  const _FilterChip({required this.label, required this.isSelected, required this.onTap, this.isAlert = false});

  @override
  Widget build(BuildContext context) {
    Color bg = isSelected ? (isAlert ? Colors.redAccent : const Color(0xFF4C51BF)) : Colors.white.withOpacity(0.05);
    Color fg = isSelected ? Colors.white : Colors.white70;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white10)),
        child: Text(label, style: GoogleFonts.outfit(color: fg, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
      ),
    );
  }
}

class _TaskCard extends StatelessWidget {
  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  final String assigneeName;
  final String myUid;
  final String companyId;

  const _TaskCard({required this.doc, required this.assigneeName, required this.myUid, required this.companyId});

  @override
  Widget build(BuildContext context) {
    final d = doc.data();
    final title = (d['title'] ?? '').toString();
    final status = (d['status'] ?? 'pending').toString();
    final assignedByUid = (d['assignedByUid'] ?? '').toString();
    final dueAt = d['dueAt'] is Timestamp ? (d['dueAt'] as Timestamp).toDate() : null;

    final isDone = status == 'done';
    final isCanceled = status == 'canceled';
    final isOverdue = (status == 'pending') && (dueAt != null) && dueAt.isBefore(DateTime.now());
    final isMine = assignedByUid == myUid;

    Color iconColor = isDone ? Colors.greenAccent : (isCanceled ? Colors.red : (isOverdue ? Colors.orangeAccent : Colors.blueAccent));
    IconData icon = isDone ? Icons.check_circle_outline : (isCanceled ? Icons.cancel_outlined : (isOverdue ? Icons.warning_amber_rounded : Icons.pending_outlined));
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => context.push('/company/$companyId/task/${doc.id}'),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: iconColor.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                  child: Icon(icon, color: iconColor, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title.isEmpty ? '(Başlıksız)' : title, style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.person_outline, size: 14, color: Colors.white54),
                          const SizedBox(width: 4),
                          Expanded(child: Text('Atanan: $assigneeName', style: GoogleFonts.outfit(color: Colors.white54, fontSize: 13), overflow: TextOverflow.ellipsis)),
                        ],
                      ),
                      if (isMine)
                         Padding(
                           padding: const EdgeInsets.only(top: 4),
                           child: Text('Oluşturan: Ben', style: GoogleFonts.outfit(color: const Color(0xFF4C51BF), fontSize: 12, fontWeight: FontWeight.bold)),
                         ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (dueAt != null)
                      Text('${dueAt.day}.${dueAt.month}', style: GoogleFonts.outfit(color: Colors.white70, fontWeight: FontWeight.bold)),
                    if (dueAt != null)
                      Text('${dueAt.hour.toString().padLeft(2,'0')}:${dueAt.minute.toString().padLeft(2,'0')}', style: GoogleFonts.outfit(color: Colors.white38, fontSize: 12)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
