import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart'; // Font kullanımı

import '../../ui/td_scaffold.dart';

class EmployeeHomePage extends StatefulWidget {
  const EmployeeHomePage({super.key});

  @override
  State<EmployeeHomePage> createState() => _EmployeeHomePageState();
}

enum _TaskFilter { all, pending, done, overdue }
enum _SortMode { newest, dueSoon }
enum _ViewMode { list, calendar }

class _EmployeeHomePageState extends State<EmployeeHomePage> {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;

  final _search = TextEditingController();

  _TaskFilter _filter = _TaskFilter.all;
  _SortMode _sort = _SortMode.newest;
  _ViewMode _view = _ViewMode.list;

  String? _lastError;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _signOut() async {
    await _auth.signOut();
    if (!mounted) return;
    context.go('/login');
  }

  Future<void> _toggleDone({
    required DocumentReference<Map<String, dynamic>> ref,
    required bool makeDone,
  }) async {
    try {
      await ref.update({
        'status': makeDone ? 'done' : 'pending',
        'doneAt': makeDone ? FieldValue.serverTimestamp() : null,
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _lastError = e.toString());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Güncellenemedi: $e')),
      );
    }
  }

  String _fmtDT(DateTime d) {
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    final hh = d.hour.toString().padLeft(2, '0');
    final mi = d.minute.toString().padLeft(2, '0');
    return '$dd.$mm.${d.year}  $hh:$mi';
  }

  String _fmtDay(DateTime d) {
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    return '$dd.$mm.${d.year}';
  }

  String _remainingLabel(DateTime due) {
    final diff = due.difference(DateTime.now());
    if (diff.isNegative) {
      final over = diff.abs();
      if (over.inDays >= 1) return '${over.inDays}g gecikmiş';
      if (over.inHours >= 1) return '${over.inHours}sa gecikmiş';
      return '${over.inMinutes}dk gecikmiş';
    } else {
      if (diff.inDays >= 1) return '${diff.inDays}g kaldı';
      if (diff.inHours >= 1) return '${diff.inHours}sa kaldı';
      return '${diff.inMinutes}dk kaldı';
    }
  }

  DateTime? _tsToDT(dynamic v) => v is Timestamp ? v.toDate() : null;

  @override
  Widget build(BuildContext context) {
    final u = _auth.currentUser;

    if (u == null) {
      return const TDScaffold(
        body: Center(child: Text('Giriş yapılmadı.', style: TextStyle(color: Colors.white))),
      );
    }

    final userRef = _db.collection('users').doc(u.uid);

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: userRef.snapshots(),
      builder: (context, userSnap) {
        final userData = userSnap.data?.data();
        final companyId = userData?['activeCompanyId'] as String?;

        if (!userSnap.hasData) {
          return const TDScaffold(
            body: Center(child: CircularProgressIndicator(color: Colors.white)),
          );
        }

        if (companyId == null || companyId.isEmpty) {
          return TDScaffold(
            appBar: AppBar(
              title: Text('Çalışan', style: GoogleFonts.outfit(color: Colors.white)),
              backgroundColor: Colors.transparent,
              iconTheme: const IconThemeData(color: Colors.white),
              actions: [
                IconButton(onPressed: _signOut, icon: const Icon(Icons.logout, color: Colors.white)),
              ],
            ),
            body: Center(
              child: Container(
                margin: const EdgeInsets.all(24),
                padding: const EdgeInsets.all(24),
                decoration: _cardDecoration(),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.business_outlined, size: 48, color: Colors.white70),
                    const SizedBox(height: 16),
                    Text(
                      'Şirket bulunamadı',
                      style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 20, color: Colors.white),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Hesabında aktif şirket kaydı yok. Lütfen yöneticinle iletişime geç.',
                      style: GoogleFonts.outfit(color: Colors.white70),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    _GradientButton(
                      onPressed: () => context.go('/login'),
                      text: 'Giriş Ekranına Dön',
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        final memberRef = _db.collection('companies').doc(companyId).collection('members').doc(u.uid);

        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: memberRef.snapshots(),
          builder: (context, memSnap) {
            final mem = memSnap.data?.data();
            final displayName = (mem?['displayName'] as String?) ?? 'Çalışan';

            final tasksQuery = _db
                .collection('companies')
                .doc(companyId)
                .collection('tasks')
                .where('assignedToUid', isEqualTo: u.uid)
                .orderBy('createdAt', descending: true);

            return TDScaffold(
              appBar: AppBar(
                title: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Merhaba,', style: GoogleFonts.outfit(fontSize: 14, color: Colors.white70)),
                    InkWell(
                      onTap: () => context.push('/profile'),
                      child: Text(displayName, style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                    ),
                  ],
                ),
                centerTitle: false,
                backgroundColor: Colors.transparent,
                surfaceTintColor: Colors.transparent,
                actions: [
                  IconButton(
                    onPressed: () => setState(() {}),
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(12)),
                      child: const Icon(Icons.refresh_rounded, color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _signOut,
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(12)),
                      child: const Icon(Icons.logout, color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 16),
                ],
              ),
              body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: tasksQuery.snapshots(),
                builder: (context, snap) {
                  if (snap.hasError) return Center(child: Text('Hata: ${snap.error}', style: const TextStyle(color: Colors.white)));
                  if (!snap.hasData) return const Center(child: CircularProgressIndicator(color: Colors.white));

                  final now = DateTime.now();
                  final allDocs = snap.data!.docs;

                  // KPI Logic
                  int pending = 0, done = 0, overdue = 0, canceled = 0;
                  for (final d in allDocs) {
                    final m = d.data();
                    final status = (m['status'] as String?) ?? 'pending';
                    final dueAt = _tsToDT(m['dueAt']);
                    final isDone = status == 'done';
                    final isCanceled = status == 'canceled';

                    if (isCanceled) { canceled++; continue; }
                    if (isDone) {
                      done++;
                    } else {
                      pending++;
                      if (dueAt != null && dueAt.isBefore(now)) overdue++;
                    }
                  }

                  // Activities
                  final activities = <_Activity>[];
                  for (final d in allDocs) {
                    final m = d.data();
                    final title = (m['title'] as String?) ?? 'Görev';
                    final createdAt = _tsToDT(m['createdAt']);
                    final doneAt = _tsToDT(m['doneAt']);
                    final status = (m['status'] as String?) ?? 'pending';

                    if (createdAt != null) activities.add(_Activity(time: createdAt, title: 'Atandı', subtitle: title, icon: Icons.assignment_add));
                    if (status == 'done' && doneAt != null) activities.add(_Activity(time: doneAt, title: 'Tamamlandı', subtitle: title, icon: Icons.check_circle));
                  }
                  activities.sort((a, b) => b.time.compareTo(a.time));
                  final topActivities = activities.take(5).toList();

                  // Filter & Sort
                  final q = _search.text.trim().toLowerCase();
                  List<QueryDocumentSnapshot<Map<String, dynamic>>> list = allDocs.where((d) {
                    final m = d.data();
                    final title = ((m['title'] ?? '') as String).toLowerCase();
                    final status = (m['status'] as String?) ?? 'pending';
                    final isDone = status == 'done';
                    final isCanceled = status == 'canceled';
                    final dueAt = _tsToDT(m['dueAt']);
                    final isOverdue = (!isDone && !isCanceled) && dueAt != null && dueAt.isBefore(now);

                    if (_filter == _TaskFilter.pending && status != 'pending') return false;
                    if (_filter == _TaskFilter.done && status != 'done') return false;
                    if (_filter == _TaskFilter.overdue && !isOverdue) return false;
                    if (q.isNotEmpty && !title.contains(q)) return false;
                    return true;
                  }).toList();

                  // Sort
                  list.sort((a, b) {
                    if (_sort == _SortMode.newest) {
                      final aDt = _tsToDT(a.data()['createdAt']) ?? DateTime(0);
                      final bDt = _tsToDT(b.data()['createdAt']) ?? DateTime(0);
                      return bDt.compareTo(aDt);
                    } else {
                      final aDue = _tsToDT(a.data()['dueAt']);
                      final bDue = _tsToDT(b.data()['dueAt']);
                      if (aDue == null && bDue == null) return 0;
                      if (aDue == null) return 1;
                      if (bDue == null) return -1;
                      return aDue.compareTo(bDue);
                    }
                  });

                  // Calendar Grouping
                  final dayMap = <String, List<QueryDocumentSnapshot<Map<String, dynamic>>>>{};
                   if (_view == _ViewMode.calendar) {
                    for (final d in list) {
                      final dueAt = _tsToDT(d.data()['dueAt']);
                      if (dueAt != null) {
                         final key = '${dueAt.year}-${dueAt.month.toString().padLeft(2, '0')}-${dueAt.day.toString().padLeft(2, '0')}';
                         (dayMap[key] ??= []).add(d);
                      }
                    }
                   }
                  final dayKeys = dayMap.keys.toList()..sort();

                  return RefreshIndicator(
                    onRefresh: () async => setState(() {}),
                    child: ListView(
                      padding: const EdgeInsets.all(20),
                      children: [
                        // KPI Cards
                        Row(
                          children: [
                            Expanded(child: _KpiCard(title: 'Bekleyen', value: '$pending', icon: Icons.pending_actions, color: Colors.orangeAccent)),
                            const SizedBox(width: 12),
                            Expanded(child: _KpiCard(title: 'Tamamlanan', value: '$done', icon: Icons.task_alt, color: Colors.greenAccent)),
                            const SizedBox(width: 12),
                            Expanded(child: _KpiCard(title: 'Geciken', value: '$overdue', icon: Icons.warning_amber_rounded, color: Colors.redAccent)),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // Filter & Search Section
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: _cardDecoration(),
                          child: TextField(
                            controller: _search,
                            onChanged: (_) => setState(() {}),
                            style: GoogleFonts.outfit(color: Colors.white),
                            decoration: InputDecoration(
                              hintText: 'Görev ara...',
                              hintStyle: GoogleFonts.outfit(color: Colors.white54),
                              prefixIcon: const Icon(Icons.search, color: Colors.white54),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        SizedBox(
                          height: 40,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            children: [
                              _FilterChip(label: 'Hepsi', isSelected: _filter == _TaskFilter.all, onTap: () => setState(() => _filter = _TaskFilter.all)),
                              _FilterChip(label: 'Bekleyen', isSelected: _filter == _TaskFilter.pending, onTap: () => setState(() => _filter = _TaskFilter.pending)),
                              _FilterChip(label: 'Tamamlanan', isSelected: _filter == _TaskFilter.done, onTap: () => setState(() => _filter = _TaskFilter.done)),
                              _FilterChip(label: 'Geciken', isSelected: _filter == _TaskFilter.overdue, onTap: () => setState(() => _filter = _TaskFilter.overdue)),
                            ],
                          ),
                        ),
                         const SizedBox(height: 16),

                        // Content
                        if (list.isEmpty)
                          Container(
                             padding: const EdgeInsets.all(32),
                             alignment: Alignment.center,
                             child: Column(
                               children: [
                                 Icon(Icons.filter_list_off, size: 64, color: Colors.white24),
                                 const SizedBox(height: 16),
                                 Text('Görev bulunamadı', style: GoogleFonts.outfit(color: Colors.white60, fontSize: 16)),
                               ],
                             ),
                          )
                        else if (_view == _ViewMode.list)
                          ...list.map((d) => _TaskCard(
                            companyId: companyId,
                            doc: d,
                            now: now,
                            remainingLabel: _remainingLabel,
                            fmtDT: _fmtDT,
                            toggleDone: _toggleDone,
                          ))
                        else
                         ...dayKeys.map((k) {
                            final items = dayMap[k]!;
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  child: Text(k, style: GoogleFonts.outfit(color: Colors.white70, fontWeight: FontWeight.bold)),
                                ),
                                ...items.map((d) => _TaskCard(
                                  companyId: companyId,
                                  doc: d,
                                  now: now,
                                  remainingLabel: _remainingLabel,
                                  fmtDT: _fmtDT,
                                  toggleDone: _toggleDone,
                                )),
                              ],
                            );
                         }),
                      ],
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}

// --- Modern Components ---

BoxDecoration _cardDecoration() {
  return BoxDecoration(
    color: Colors.white.withOpacity(0.08),
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: Colors.white.withOpacity(0.1)),
    boxShadow: [
       BoxShadow(color: Colors.black12, blurRadius: 8, offset: const Offset(0, 4)),
    ],
  );
}

class _GradientButton extends StatelessWidget {
  final VoidCallback onPressed;
  final String text;
  const _GradientButton({required this.onPressed, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 50,
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF4C51BF), Color(0xFF6B46C1)]),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: const Color(0xFF4C51BF).withOpacity(0.4), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(12),
          child: Center(
             child: Text(text, style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          ),
        ),
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _KpiCard({required this.title, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 12),
          Text(value, style: GoogleFonts.outfit(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(title, style: GoogleFonts.outfit(color: Colors.white60, fontSize: 12)),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({required this.label, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
         margin: const EdgeInsets.only(right: 8),
         padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
         decoration: BoxDecoration(
           color: isSelected ? const Color(0xFF4C51BF) : Colors.white.withOpacity(0.05),
           borderRadius: BorderRadius.circular(20),
           border: Border.all(color: isSelected ? const Color(0xFF4C51BF) : Colors.white12),
         ),
         child: Text(label, style: GoogleFonts.outfit(color: isSelected ? Colors.white : Colors.white70)),
      ),
    );
  }
}

class _TaskCard extends StatelessWidget {
  final String companyId;
  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  final DateTime now;
  final String Function(DateTime due) remainingLabel;
  final String Function(DateTime d) fmtDT;
  final Future<void> Function({required DocumentReference<Map<String, dynamic>> ref, required bool makeDone}) toggleDone;

  const _TaskCard({
    required this.companyId,
    required this.doc,
    required this.now,
    required this.remainingLabel,
    required this.fmtDT,
    required this.toggleDone,
  });

  @override
  Widget build(BuildContext context) {
    final m = doc.data();
    final title = (m['title'] as String?) ?? 'Görev';
    // final desc = (m['description'] as String?) ?? '';
    final status = (m['status'] as String?) ?? 'pending';
    final dueAt = (m['dueAt'] is Timestamp) ? (m['dueAt'] as Timestamp).toDate() : null;
    
    final isDone = status == 'done';
    final isCanceled = status == 'canceled';
    final isOverdue = dueAt != null && dueAt.isBefore(now) && !isDone && !isCanceled;
    final priority = (m['priority'] as String?) ?? 'normal';

    Color statusColor = Colors.blueGrey;
    IconData statusIcon = Icons.circle_outlined;
    
    if (isDone) {
      statusColor = Colors.greenAccent;
      statusIcon = Icons.check_circle;
    } else if (isCanceled) {
      statusColor = Colors.redAccent;
      statusIcon = Icons.cancel;
    } else if (isOverdue) {
      statusColor = Colors.orangeAccent;
      statusIcon = Icons.warning_rounded;
    }

    Color priorityColor = Colors.transparent;
    if (priority == 'high') priorityColor = Colors.redAccent;
    if (priority == 'low') priorityColor = Colors.blueAccent;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: _cardDecoration(),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => context.push('/company/$companyId/task/${doc.id}'),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () {
                    if (!isCanceled) toggleDone(ref: doc.reference, makeDone: !isDone);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: statusColor, width: 2)),
                    child: isDone 
                      ? Icon(Icons.check, size: 16, color: statusColor) 
                      : Container(width: 16, height: 16, decoration: const BoxDecoration(shape: BoxShape.circle)),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (priority == 'high')
                             Padding(
                               padding: const EdgeInsets.only(right: 6),
                               child: Icon(Icons.priority_high_rounded, size: 16, color: Colors.redAccent),
                             ),
                           if (priority == 'low')
                             Padding(
                               padding: const EdgeInsets.only(right: 6),
                               child: Icon(Icons.arrow_downward_rounded, size: 16, color: Colors.blueAccent),
                             ),
                          Expanded(
                            child: Text(
                              title, 
                              style: GoogleFonts.outfit(
                                color: Colors.white, 
                                fontWeight: FontWeight.bold, 
                                fontSize: 16,
                                decoration: isDone ? TextDecoration.lineThrough : null,
                                decorationColor: Colors.white54,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      if (dueAt != null)
                        Row(
                          children: [
                            Icon(Icons.access_time, size: 14, color: isOverdue ? Colors.redAccent : Colors.white54),
                            const SizedBox(width: 4),
                            Text(
                              remainingLabel(dueAt), 
                              style: GoogleFonts.outfit(
                                color: isOverdue ? Colors.redAccent : Colors.white54, 
                                fontSize: 12
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
                if (!isDone && !isCanceled)
                  Icon(Icons.chevron_right, color: Colors.white24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Activity {
  final DateTime time;
  final String title;
  final String subtitle;
  final IconData icon;
  _Activity({required this.time, required this.title, required this.subtitle, required this.icon});
}
