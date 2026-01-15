import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ManagerTasksPage extends StatefulWidget {
  const ManagerTasksPage({super.key});

  @override
  State<ManagerTasksPage> createState() => _ManagerTasksPageState();
}

class _ManagerTasksPageState extends State<ManagerTasksPage> {
  Timer? _ticker;
  DateTime _now = DateTime.now();
  String _search = '';
  String _status = 'all'; // all | pending | done

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  String _fmtRemaining(DateTime due) {
    final diff = due.difference(_now);
    final neg = diff.isNegative;
    final d = diff.abs();

    String chunk(Duration x) {
      final days = x.inDays;
      final hours = x.inHours % 24;
      final mins = x.inMinutes % 60;
      if (days > 0) return '$days gün ${hours} sa';
      if (hours > 0) return '$hours sa ${mins} dk';
      return '${mins} dk';
    }

    return neg ? 'Gecikti: ${chunk(d)}' : 'Kalan: ${chunk(d)}';
  }

  @override
  Widget build(BuildContext context) {
    final u = FirebaseAuth.instance.currentUser;
    if (u == null) return const Scaffold(body: Center(child: Text('Oturum yok')));

    final db = FirebaseFirestore.instance;

    final userDocStream = db.collection('users').doc(u.uid).snapshots();

    return Scaffold(
      appBar: AppBar(title: const Text('Departman Görevleri')),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: userDocStream,
        builder: (context, userSnap) {
          final companyId = userSnap.data?.data()?['activeCompanyId'] as String?;
          if (companyId == null || companyId.isEmpty) {
            return const Center(child: Text('Aktif şirket bulunamadı.'));
          }

          final myMemberStream = db
              .collection('companies')
              .doc(companyId)
              .collection('members')
              .doc(u.uid)
              .snapshots();

          return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: myMemberStream,
            builder: (context, memSnap) {
              final myDept = memSnap.data?.data()?['departmentId'] as String?;
              if (myDept == null || myDept.isEmpty) {
                return const Center(child: Text('Müdür departmanı bulunamadı.'));
              }

              final membersStream = db
                  .collection('companies')
                  .doc(companyId)
                  .collection('members')
                  .where('departmentId', isEqualTo: myDept)
                  .snapshots();

              final tasksStream = db
                  .collection('companies')
                  .doc(companyId)
                  .collection('tasks')
                  .where('departmentId', isEqualTo: myDept)
                  .orderBy('createdAt', descending: true)
                  .snapshots();

              return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: membersStream,
                builder: (context, membersSnap) {
                  return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: tasksStream,
                    builder: (context, tasksSnap) {
                      if (membersSnap.hasError) {
                        return Center(child: Text('Üye hata: ${membersSnap.error}'));
                      }
                      if (tasksSnap.hasError) {
                        return Center(child: Text('Görev hata: ${tasksSnap.error}'));
                      }
                      if (!membersSnap.hasData || !tasksSnap.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      // memberNameByUid
                      final memberNameByUid = <String, String>{};
                      for (final m in membersSnap.data!.docs) {
                        memberNameByUid[m.id] = (m.data()['displayName'] ?? m.id) as String;
                      }

                      DateTime? tsToDate(dynamic v) => (v is Timestamp) ? v.toDate() : null;

                      var tasks = tasksSnap.data!.docs.map((d) {
                        final data = d.data();
                        return _TaskRow(
                          id: d.id,
                          title: (data['title'] ?? '-') as String,
                          assignedToUid: (data['assignedToUid'] ?? '') as String,
                          status: (data['status'] ?? 'pending') as String,
                          dueAt: tsToDate(data['dueAt']),
                          doneAt: tsToDate(data['doneAt']),
                        );
                      }).toList();

                      // status filter
                      if (_status == 'pending') {
                        tasks = tasks.where((t) => t.status != 'done').toList();
                      } else if (_status == 'done') {
                        tasks = tasks.where((t) => t.status == 'done').toList();
                      }

                      // search
                      final q = _search.trim().toLowerCase();
                      if (q.isNotEmpty) {
                        tasks = tasks.where((t) {
                          final who = memberNameByUid[t.assignedToUid] ?? '';
                          return t.title.toLowerCase().contains(q) || who.toLowerCase().contains(q);
                        }).toList();
                      }

                      return Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
                            child: Column(
                              children: [
                                TextField(
                                  decoration: const InputDecoration(
                                    prefixIcon: Icon(Icons.search),
                                    hintText: 'Görev / Çalışan ara...',
                                    border: OutlineInputBorder(),
                                  ),
                                  onChanged: (v) => setState(() => _search = v),
                                ),
                                const SizedBox(height: 10),
                                SizedBox(
                                  height: 44,
                                  child: ListView(
                                    scrollDirection: Axis.horizontal,
                                    children: [
                                      ChoiceChip(
                                        label: const Text('Hepsi'),
                                        selected: _status == 'all',
                                        onSelected: (_) => setState(() => _status = 'all'),
                                      ),
                                      const SizedBox(width: 8),
                                      ChoiceChip(
                                        label: const Text('Pending'),
                                        selected: _status == 'pending',
                                        onSelected: (_) => setState(() => _status = 'pending'),
                                      ),
                                      const SizedBox(width: 8),
                                      ChoiceChip(
                                        label: const Text('Done'),
                                        selected: _status == 'done',
                                        onSelected: (_) => setState(() => _status = 'done'),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: tasks.isEmpty
                                ? const Center(child: Text('Görev yok.'))
                                : ListView.separated(
                                    padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
                                    itemCount: tasks.length,
                                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                                    itemBuilder: (context, i) {
                                      final t = tasks[i];
                                      final who = memberNameByUid[t.assignedToUid] ?? t.assignedToUid;
                                      final isDone = t.status == 'done';

                                      final remaining = (!isDone && t.dueAt != null)
                                          ? _fmtRemaining(t.dueAt!)
                                          : null;

                                      return Card(
                                        child: ListTile(
                                          title: Text(t.title,
                                              style: const TextStyle(fontWeight: FontWeight.w800)),
                                          subtitle: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              const SizedBox(height: 4),
                                              Text('Kime: $who'),
                                              if (t.dueAt != null) Text('Bitiş: ${t.dueAt!.toLocal()}'),
                                              if (remaining != null) Text(remaining),
                                              if (isDone && t.doneAt != null) Text('Done: ${t.doneAt!.toLocal()}'),
                                            ],
                                          ),
                                          trailing: Chip(label: Text(isDone ? 'done' : 'pending')),
                                          onTap: () => context.push('/company/$companyId/task/${t.id}'),
                                        ),
                                      );
                                    },
                                  ),
                          ),
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

class _TaskRow {
  _TaskRow({
    required this.id,
    required this.title,
    required this.assignedToUid,
    required this.status,
    required this.dueAt,
    required this.doneAt,
  });

  final String id;
  final String title;
  final String assignedToUid;
  final String status;
  final DateTime? dueAt;
  final DateTime? doneAt;
}
