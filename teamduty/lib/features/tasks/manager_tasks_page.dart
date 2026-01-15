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

  // all | pending | done | canceled
  String _status = 'all';

  // assignedByUid == me
  bool _onlyMine = false;

  // dueAt < now AND status == pending
  bool _overdueOnly = false;

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

  DateTime? _tsToDate(dynamic v) => (v is Timestamp) ? v.toDate() : null;

  String _fmtRemaining(DateTime due) {
    final diff = due.difference(_now);
    final neg = diff.isNegative;
    final d = diff.abs();

    String chunk(Duration x) {
      final days = x.inDays;
      final hours = x.inHours % 24;
      final mins = x.inMinutes % 60;
      if (days > 0) return '$days gün ${hours}sa';
      if (hours > 0) return '$hours sa ${mins}dk';
      return '${mins}dk';
    }

    return neg ? 'Gecikti: ${chunk(d)}' : 'Kalan: ${chunk(d)}';
  }

  // premium arka plan (admin ile aynı hissiyat)
  Widget _bg() {
    return const _PremiumDarkBackground();
  }

  Color _badgeColor(String status) {
    switch (status) {
      case 'done':
        return const Color(0xFF1F7A3E); // yeşil
      case 'canceled':
        return const Color(0xFFB3261E); // kırmızı
      case 'pending':
      default:
        return const Color(0xFF3C3F55); // koyu gri-mor
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'done':
        return Icons.check_circle_rounded;
      case 'canceled':
        return Icons.cancel_rounded;
      case 'pending':
      default:
        return Icons.timelapse_rounded;
    }
  }

  String _statusText(String status) {
    switch (status) {
      case 'done':
        return 'DONE';
      case 'canceled':
        return 'İPTAL';
      case 'pending':
      default:
        return 'PENDING';
    }
  }

  @override
  Widget build(BuildContext context) {
    final u = FirebaseAuth.instance.currentUser;
    if (u == null) {
      return const Scaffold(body: Center(child: Text('Oturum yok')));
    }

    final db = FirebaseFirestore.instance;
    final userDocStream = db.collection('users').doc(u.uid).snapshots();

    return Stack(
      children: [
        Positioned.fill(child: _bg()),
        Scaffold(
          backgroundColor: Colors.transparent,
          extendBody: true,
          extendBodyBehindAppBar: true,
          appBar: AppBar(
            title: const Text('Departman Görevleri'),
            backgroundColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
          ),
          body: SafeArea(
            top: false,
            child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
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

                    // ✅ üyeler (isim çözmek için)
                    final membersStream = db
                        .collection('companies')
                        .doc(companyId)
                        .collection('members')
                        .where('departmentId', isEqualTo: myDept)
                        .snapshots();

                    // ✅ görev query (rules’a uyumlu: mutlaka departmentId filtresi var)
                    Query<Map<String, dynamic>> q = db
                        .collection('companies')
                        .doc(companyId)
                        .collection('tasks')
                        .where('departmentId', isEqualTo: myDept);

                    if (_onlyMine) {
                      q = q.where('assignedByUid', isEqualTo: u.uid);
                    }

                    if (_overdueOnly) {
                      q = q
                          .where('status', isEqualTo: 'pending')
                          .where('dueAt', isLessThan: Timestamp.fromDate(_now))
                          .orderBy('dueAt') // inequality olduğu için önce dueAt
                          .orderBy('createdAt', descending: true);
                    } else if (_status != 'all') {
                      q = q.where('status', isEqualTo: _status).orderBy('createdAt', descending: true);
                    } else {
                      q = q.orderBy('createdAt', descending: true);
                    }

                    final tasksStream = q.snapshots();

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

                            final memberNameByUid = <String, String>{};
                            for (final m in membersSnap.data!.docs) {
                              final d = m.data();
                              final name = (d['displayName'] ?? m.id).toString();
                              final no = (d['employeeNo'] ?? '').toString();
                              memberNameByUid[m.id] = no.isEmpty ? name : '$name ($no)';
                            }

                            // map tasks
                            final tasks = tasksSnap.data!.docs.map((d) {
                              final data = d.data();
                              return _TaskRow(
                                id: d.id,
                                title: (data['title'] ?? '-') as String,
                                assignedToUid: (data['assignedToUid'] ?? '') as String,
                                status: (data['status'] ?? 'pending') as String,
                                dueAt: _tsToDate(data['dueAt']),
                                doneAt: _tsToDate(data['doneAt']),
                                canceledAt: _tsToDate(data['canceledAt']),
                              );
                            }).toList();

                            // search (client-side)
                            final qq = _search.trim().toLowerCase();
                            final filtered = qq.isEmpty
                                ? tasks
                                : tasks.where((t) {
                                    final who = memberNameByUid[t.assignedToUid] ?? '';
                                    return t.title.toLowerCase().contains(qq) ||
                                        who.toLowerCase().contains(qq);
                                  }).toList();

                            return CustomScrollView(
                              slivers: [
                                const SliverToBoxAdapter(child: SizedBox(height: 86)), // AppBar üst boşluğu
                                SliverToBoxAdapter(
                                  child: Padding(
                                    padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
                                    child: Column(
                                      children: [
                                        TextField(
                                          decoration: InputDecoration(
                                            prefixIcon: const Icon(Icons.search),
                                            hintText: 'Görev / Çalışan ara...',
                                            filled: true,
                                            fillColor: Colors.white.withOpacity(0.06),
                                            border: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(18),
                                              borderSide: BorderSide(color: Colors.white.withOpacity(0.10)),
                                            ),
                                            enabledBorder: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(18),
                                              borderSide: BorderSide(color: Colors.white.withOpacity(0.10)),
                                            ),
                                          ),
                                          onChanged: (v) => setState(() => _search = v),
                                        ),
                                        const SizedBox(height: 10),

                                        // ✅ Status chips (yatay kaydırmalı)
                                        SizedBox(
                                          height: 44,
                                          child: ListView(
                                            scrollDirection: Axis.horizontal,
                                            children: [
                                              _choiceChip('Hepsi', 'all'),
                                              const SizedBox(width: 8),
                                              _choiceChip('Pending', 'pending'),
                                              const SizedBox(width: 8),
                                              _choiceChip('Done', 'done'),
                                              const SizedBox(width: 8),
                                              _choiceChip('İptal', 'canceled'),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 10),

                                        // ✅ Extra filters (yatay kaydırmalı)
                                        SizedBox(
                                          height: 44,
                                          child: ListView(
                                            scrollDirection: Axis.horizontal,
                                            children: [
                                              FilterChip(
                                                label: const Text('Geciken görevler'),
                                                selected: _overdueOnly,
                                                onSelected: (v) => setState(() => _overdueOnly = v),
                                              ),
                                              const SizedBox(width: 8),
                                              FilterChip(
                                                label: const Text('Sadece benim oluşturduğum'),
                                                selected: _onlyMine,
                                                onSelected: (v) => setState(() => _onlyMine = v),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),

                                if (filtered.isEmpty)
                                  const SliverFillRemaining(
                                    hasScrollBody: false,
                                    child: Center(child: Text('Görev yok.')),
                                  )
                                else
                                  SliverPadding(
                                    padding: const EdgeInsets.fromLTRB(14, 6, 14, 18),
                                    sliver: SliverList.separated(
  itemCount: filtered.length,
  separatorBuilder: (_, __) => const SizedBox(height: 10),
  itemBuilder: (context, i) {
                                        final t = filtered[i];
                                        final who = memberNameByUid[t.assignedToUid] ?? t.assignedToUid;

                                        final remaining = (t.status == 'pending' && t.dueAt != null)
                                            ? _fmtRemaining(t.dueAt!)
                                            : null;

                                        final badge = Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: _badgeColor(t.status).withOpacity(0.85),
                                            borderRadius: BorderRadius.circular(999),
                                            border: Border.all(color: Colors.white.withOpacity(0.10)),
                                          ),
                                          child: Text(
                                            _statusText(t.status),
                                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                                          ),
                                        );

                                        return Card(
                                          color: Colors.white.withOpacity(0.06),
                                          child: ListTile(
                                            title: Text(
                                              t.title,
                                              style: const TextStyle(fontWeight: FontWeight.w800),
                                            ),
                                            subtitle: Padding(
                                              padding: const EdgeInsets.only(top: 6),
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text('Atanan: $who'),
                                                  if (t.status == 'canceled') const Text('İptal edildi'),
                                                  if (t.dueAt != null && t.status != 'done' && t.status != 'canceled')
                                                    Text('Bitiş: ${t.dueAt!.toLocal()}'),
                                                  if (remaining != null) Text(remaining),
                                                  if (t.status == 'done' && t.doneAt != null)
                                                    Text('Tamamlandı: ${t.doneAt!.toLocal()}'),
                                                ],
                                              ),
                                            ),
                                            trailing: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                badge,
                                                const SizedBox(width: 10),
                                                Icon(_statusIcon(t.status)),
                                              ],
                                            ),
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
          ),
        ),
      ],
    );
  }

  Widget _choiceChip(String label, String value) {
    final selected = _status == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() {
        _status = value;
        // status değişince geciken modunu kapatmak daha anlaşılır
        if (_overdueOnly) _overdueOnly = false;
      }),
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
    required this.canceledAt,
  });

  final String id;
  final String title;
  final String assignedToUid;
  final String status;
  final DateTime? dueAt;
  final DateTime? doneAt;
  final DateTime? canceledAt;
}

class _PremiumDarkBackground extends StatelessWidget {
  const _PremiumDarkBackground();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF07070C),
            Color(0xFF0A0A14),
            Color(0xFF05050A),
          ],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            left: -140,
            top: 40,
            child: Container(
              width: 340,
              height: 340,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF7C4DFF).withOpacity(0.18),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            right: -170,
            bottom: -120,
            child: Container(
              width: 420,
              height: 420,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF00D1FF).withOpacity(0.12),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 40,
            bottom: -160,
            child: Container(
              width: 380,
              height: 380,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFFFF3D81).withOpacity(0.08),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
