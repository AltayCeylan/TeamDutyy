import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:teamduty/ui/td_scaffold.dart';

class AdminTasksPage extends StatefulWidget {
  final String? initialStatus;
  final bool initialOnlyMine;
  final bool initialOnlyOverdue;
  final String? initialDepartmentId;
  final String? initialQuery;

  const AdminTasksPage({
    super.key,
    this.initialStatus,
    this.initialOnlyMine = false,
    this.initialOnlyOverdue = false,
    this.initialDepartmentId,
    this.initialQuery,
  });

  @override
  State<AdminTasksPage> createState() => _AdminTasksPageState();
}

enum _StatusFilter { all, pending, done, canceled }

class _AdminTasksPageState extends State<AdminTasksPage> {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;

  _StatusFilter _status = _StatusFilter.all;
  bool _onlyMine = false;
  bool _onlyOverdue = false;
  String? _departmentId;
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _onlyMine = widget.initialOnlyMine;
    _onlyOverdue = widget.initialOnlyOverdue;
    _departmentId = (widget.initialDepartmentId?.isEmpty ?? true) ? null : widget.initialDepartmentId;

    if (widget.initialStatus == 'pending') _status = _StatusFilter.pending;
    else if (widget.initialStatus == 'done') _status = _StatusFilter.done;
    else if (widget.initialStatus == 'canceled') _status = _StatusFilter.canceled;
    else _status = _StatusFilter.all;

    if (widget.initialQuery?.isNotEmpty ?? false) _search.text = widget.initialQuery!;
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final u = _auth.currentUser;
    if (u == null) return const TDScaffold(body: Center(child: Text('Giriş yapılmadı.', style: TextStyle(color: Colors.white))));

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _db.collection('users').doc(u.uid).snapshots(),
      builder: (context, userSnap) {
        final companyId = userSnap.data?.data()?['activeCompanyId'] as String?;
        if (companyId == null || companyId.isEmpty) return const TDScaffold(body: Center(child: Text('Şirket seçilmedi.', style: TextStyle(color: Colors.white))));

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _db.collection('companies').doc(companyId).collection('departments').snapshots(),
          builder: (context, depSnap) {
            final deptNameById = <String, String>{};
            if (depSnap.hasData) {
              for (final d in depSnap.data!.docs) {
                deptNameById[d.id] = (d.data()['name'] ?? 'Departman') as String;
              }
            }

            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _db.collection('companies').doc(companyId).collection('members').snapshots(),
              builder: (context, memSnap) {
                final nameByUid = <String, String>{};
                if (memSnap.hasData) {
                  for (final d in memSnap.data!.docs) {
                     final dName = d.data()['displayName'] as String?;
                    nameByUid[d.id] = dName ?? 'Çalışan';
                  }
                }

                return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _db.collection('companies').doc(companyId).collection('tasks').snapshots(),
                  builder: (context, taskSnap) {
                    if (taskSnap.hasError) return TDScaffold(appBar: AppBar(backgroundColor: Colors.transparent), body: Center(child: Text('Hata: ${taskSnap.error}', style: TextStyle(color: Colors.white))));

                    final now = DateTime.now();
                    final q = _search.text.trim().toLowerCase();

                    List<QueryDocumentSnapshot<Map<String, dynamic>>> tasks = taskSnap.data?.docs.toList() ?? [];

                    tasks = tasks.where((doc) {
                      final m = doc.data();
                      final status = (m['status'] ?? 'pending') as String;
                      final depId = m['departmentId'] as String?;
                      final assignedByUid = m['assignedByUid'] as String?;
                      final title = ((m['title'] ?? '') as String).toLowerCase();
                      final desc = ((m['description'] ?? '') as String).toLowerCase();
                      
                      DateTime? dueAt;
                      if (m['dueAt'] is Timestamp) dueAt = (m['dueAt'] as Timestamp).toDate();

                      final isOverdue = (status == 'pending') && (dueAt != null) && dueAt.isBefore(now);

                      if (_status == _StatusFilter.pending && status != 'pending') return false;
                      if (_status == _StatusFilter.done && status != 'done') return false;
                      if (_status == _StatusFilter.canceled && status != 'canceled') return false;
                      if (_onlyOverdue && !isOverdue) return false;
                      if (_onlyMine && assignedByUid != u.uid) return false;
                      if (_departmentId != null && _departmentId!.isNotEmpty && depId != _departmentId) return false;

                      if (q.isNotEmpty) {
                        final assignedToUid = m['assignedToUid'] as String?;
                        final assignee = (assignedToUid != null ? (nameByUid[assignedToUid] ?? '') : '').toLowerCase();
                        final depName = (depId != null ? (deptNameById[depId] ?? '') : '').toLowerCase();
                        if (!title.contains(q) && !desc.contains(q) && !assignee.contains(q) && !depName.contains(q)) return false;
                      }
                      return true;
                    }).toList();

                    tasks.sort((a, b) {
                      final at = a.data()['createdAt'];
                      final bt = b.data()['createdAt'];
                      DateTime ad = (at is Timestamp) ? at.toDate() : DateTime(1970);
                      DateTime bd = (bt is Timestamp) ? bt.toDate() : DateTime(1970);
                      return bd.compareTo(ad);
                    });

                    final grouped = <String, List<QueryDocumentSnapshot<Map<String, dynamic>>>>{};
                    for (final doc in tasks) {
                      final depId = (doc.data()['departmentId'] as String?) ?? '__none__';
                      grouped.putIfAbsent(depId, () => []).add(doc);
                    }

                    final depKeys = grouped.keys.toList()..sort((a, b) {
                       final an = a == '__none__' ? 'Diğer' : (deptNameById[a] ?? a);
                       final bn = b == '__none__' ? 'Diğer' : (deptNameById[b] ?? b);
                       return an.toLowerCase().compareTo(bn.toLowerCase());
                    });

                    return TDScaffold(
                      appBar: AppBar(
                        title: Text('Görevler', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
                        backgroundColor: Colors.transparent,
                        iconTheme: const IconThemeData(color: Colors.white),
                        actions: [
                          IconButton(
                            tooltip: 'Filtreleri Temizle',
                            onPressed: () => setState(() {
                              _status = _StatusFilter.all;
                              _onlyMine = false;
                              _onlyOverdue = false;
                              _departmentId = null;
                              _search.clear();
                            }), 
                            icon: const Icon(Icons.refresh_rounded, color: Colors.white)
                          ),
                        ],
                      ),
                      body: Column(
                        children: [
                          _FiltersBar(
                            deptNameById: deptNameById,
                            status: _status,
                            onlyMine: _onlyMine,
                            onlyOverdue: _onlyOverdue,
                            departmentId: _departmentId,
                            search: _search,
                            onChanged: (s, mine, overdue, depId) {
                               setState(() {
                                 if (overdue) _status = _StatusFilter.all; else _status = s;
                                 if (s == _StatusFilter.done || s == _StatusFilter.canceled) _onlyOverdue = false; else _onlyOverdue = overdue;
                                 _onlyMine = mine;
                                 _departmentId = depId;
                               });
                            },
                            onSearchChanged: () => setState(() {}),
                          ),
                          Expanded(
                            child: tasks.isEmpty 
                                ? Center(child: Text('Görev bulunamadı', style: GoogleFonts.outfit(color: Colors.white60)))
                                : ListView.builder(
                                    padding: const EdgeInsets.all(16),
                                    itemCount: depKeys.length,
                                    itemBuilder: (context, i) {
                                      final depId = depKeys[i];
                                      final list = grouped[depId] ?? [];
                                      final depName = depId == '__none__' ? 'Departman Atanmamış' : (deptNameById[depId] ?? 'Bilinmeyen Departman');
                                      
                                      final pC = list.where((e) => (e.data()['status'] ?? '') == 'pending').length;
                                      final dC = list.where((e) => (e.data()['status'] ?? '') == 'done').length;

                                      return Container(
                                        margin: const EdgeInsets.only(bottom: 16),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.05),
                                          borderRadius: BorderRadius.circular(16),
                                          border: Border.all(color: Colors.white12),
                                        ),
                                        child: Theme( // Remove divider
                                          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                                          child: ExpansionTile(
                                            initiallyExpanded: true,
                                            iconColor: Colors.white70,
                                            collapsedIconColor: Colors.white54,
                                            title: Text(depName, style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
                                            subtitle: Text('$pC Bekleyen • $dC Tamamlanan', style: GoogleFonts.outfit(color: Colors.white54, fontSize: 12)),
                                            children: list.map((doc) {
                                               final m = doc.data();
                                               return _TaskRow(
                                                 doc: doc,
                                                 assignee: nameByUid[m['assignedToUid']] ?? 'Atanmamış',
                                                 onTap: () => context.push('/company/$companyId/task/${doc.id}'),
                                               );
                                            }).toList(),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}

class _FiltersBar extends StatelessWidget {
  final Map<String, String> deptNameById;
  final _StatusFilter status;
  final bool onlyMine;
  final bool onlyOverdue;
  final String? departmentId;
  final TextEditingController search;
  final Function(_StatusFilter, bool, bool, String?) onChanged;
  final VoidCallback onSearchChanged;

  const _FiltersBar({required this.deptNameById, required this.status, required this.onlyMine, required this.onlyOverdue, required this.departmentId, required this.search, required this.onChanged, required this.onSearchChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF16213E).withOpacity(0.8),
        border: const Border(bottom: BorderSide(color: Colors.white10)),
      ),
      child: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                 _FilterChip(label: 'Hepsi', isSelected: status == _StatusFilter.all && !onlyOverdue, onTap: () => onChanged(_StatusFilter.all, onlyMine, false, departmentId)),
                 const SizedBox(width: 8),
                 _FilterChip(label: 'Bekleyen', isSelected: status == _StatusFilter.pending, onTap: () => onChanged(_StatusFilter.pending, onlyMine, false, departmentId)),
                 const SizedBox(width: 8),
                 _FilterChip(label: 'Tamamlanan', isSelected: status == _StatusFilter.done, onTap: () => onChanged(_StatusFilter.done, onlyMine, false, departmentId)),
                 const SizedBox(width: 8),
                 _FilterChip(label: 'Geciken', isSelected: onlyOverdue, onTap: () => onChanged(_StatusFilter.all, onlyMine, !onlyOverdue, departmentId), isAlert: true),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(12)),
                  child: DropdownButtonHideUnderline(
                    child: ButtonTheme(
                      alignedDropdown: true,
                      child: DropdownButton<String?>(
                        value: departmentId,
                        icon: const Icon(Icons.arrow_drop_down, color: Colors.white54),
                        dropdownColor: const Color(0xFF1E293B),
                        style: GoogleFonts.outfit(color: Colors.white),
                        isExpanded: true,
                        hint: Text('Tüm Departmanlar', style: GoogleFonts.outfit(color: Colors.white54)),
                        items: [
                           DropdownMenuItem(value: null, child: Text('Tüm Departmanlar', style: GoogleFonts.outfit(color: Colors.white))),
                           ...deptNameById.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value, overflow: TextOverflow.ellipsis, style: GoogleFonts.outfit(color: Colors.white)))),
                        ],
                        onChanged: (v) => onChanged(status, onlyMine, onlyOverdue, v),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: () => onChanged(status, !onlyMine, onlyOverdue, departmentId),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: onlyMine ? const Color(0xFF4C51BF) : Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: onlyMine ? const Color(0xFF4C51BF) : Colors.white12),
                  ),
                  child: Center(child: Text('Bana Ait', style: GoogleFonts.outfit(color: Colors.white, fontWeight: onlyMine ? FontWeight.bold : FontWeight.normal))),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            height: 48,
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(12)),
            child: TextField(
              controller: search,
              onChanged: (_) => onSearchChanged(),
              style: GoogleFonts.outfit(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Ara...',
                hintStyle: GoogleFonts.outfit(color: Colors.white38),
                prefixIcon: const Icon(Icons.search, color: Colors.white38),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],
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

class _TaskRow extends StatelessWidget {
  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  final String assignee;
  final VoidCallback onTap;
  const _TaskRow({required this.doc, required this.assignee, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final m = doc.data();
    final title = (m['title'] ?? 'Görev') as String;
    final status = (m['status'] ?? 'pending') as String;
    DateTime? dueAt;
    if (m['dueAt'] is Timestamp) dueAt = (m['dueAt'] as Timestamp).toDate();
    
    final isDone = status == 'done';
    final isCanceled = status == 'canceled';
    final isOverdue = (status == 'pending') && (dueAt != null) && dueAt.isBefore(DateTime.now());

    Color iconColor = isDone ? Colors.greenAccent : (isCanceled ? Colors.red : (isOverdue ? Colors.orangeAccent : Colors.blueAccent));
    IconData icon = isDone ? Icons.check_circle_outline : (isCanceled ? Icons.cancel_outlined : (isOverdue ? Icons.warning_amber_rounded : Icons.pending_outlined));

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(border: Border(top: BorderSide(color: Colors.white.withOpacity(0.05)))),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: iconColor.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.person_outline, size: 14, color: Colors.white54),
                      const SizedBox(width: 4),
                      Expanded(child: Text(assignee, style: GoogleFonts.outfit(color: Colors.white54, fontSize: 13), overflow: TextOverflow.ellipsis)),
                    ],
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (dueAt != null)
                   Text('${dueAt.day}.${dueAt.month}', style: GoogleFonts.outfit(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                if (dueAt != null)
                   Text('${dueAt.hour.toString().padLeft(2,'0')}:${dueAt.minute.toString().padLeft(2,'0')}', style: GoogleFonts.outfit(color: Colors.white38, fontSize: 11)),
              ],
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right, color: Colors.white30, size: 20),
          ],
        ),
      ),
    );
  }
}
