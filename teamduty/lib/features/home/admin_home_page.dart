import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:teamduty/ui/td_scaffold.dart';

class AdminHomePage extends StatefulWidget {
  const AdminHomePage({super.key});

  @override
  State<AdminHomePage> createState() => _AdminHomePageState();
}

class _AdminHomePageState extends State<AdminHomePage> {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;

  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    context.go('/login');
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> _userDocStream(String uid) {
    return _db.collection('users').doc(uid).snapshots();
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> _companyDocStream(String companyId) {
    return _db.collection('companies').doc(companyId).snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _tasksStream(String companyId) {
    return _db.collection('companies').doc(companyId).collection('tasks').snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _membersStream(String companyId) {
    return _db.collection('companies').doc(companyId).collection('members').snapshots();
  }

  @override
  Widget build(BuildContext context) {
    final u = _auth.currentUser;

    if (u == null) {
      return const TDScaffold(
        appBar: null,
        body: Center(child: Text('Giriş yapılmadı.', style: TextStyle(color: Colors.white))),
      );
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _userDocStream(u.uid),
      builder: (context, userSnap) {
        final userData = userSnap.data?.data();
        final companyId = userData?['activeCompanyId'] as String?;

        if (companyId == null || companyId.isEmpty) {
          return TDScaffold(
            appBar: AppBar(
              backgroundColor: Colors.transparent, 
              iconTheme: const IconThemeData(color: Colors.white)
            ),
            body: Center(
              child: Container(
                margin: const EdgeInsets.all(24),
                padding: const EdgeInsets.all(24),
                decoration: _cardDecoration(),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.business_rounded, size: 64, color: Colors.white70),
                    const SizedBox(height: 16),
                    Text(
                      'TeamDuty Yönetim',
                      style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 24, color: Colors.white),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Önce bir şirket oluşturmalısın.',
                      style: GoogleFonts.outfit(color: Colors.white70),
                    ),
                    const SizedBox(height: 24),
                    _GradientButton(
                      onPressed: () => context.push('/company/create'),
                      text: 'Şirket Oluştur',
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: _companyDocStream(companyId),
          builder: (context, compSnap) {
            final comp = compSnap.data?.data();
            final companyName = (comp?['name'] as String?) ?? 'Şirket';
            final companyCode = (comp?['code'] as String?) ?? '';

            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _tasksStream(companyId),
              builder: (context, tasksSnap) {
                return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _membersStream(companyId),
                  builder: (context, membersSnap) {
                    final now = DateTime.now();
                    int pending = 0, done = 0, overdue = 0, employees = 0;

                    if (tasksSnap.hasData) {
                      for (final d in tasksSnap.data!.docs) {
                        final m = d.data();
                        final status = (m['status'] ?? 'pending') as String;
                        DateTime? dueAt;
                        final due = m['dueAt'];
                        if (due is Timestamp) dueAt = due.toDate();

                        if (status == 'done') {
                          done++;
                        } else {
                          pending++;
                          if (dueAt != null && dueAt.isBefore(now)) overdue++;
                        }
                      }
                    }

                    if (membersSnap.hasData) {
                      for (final d in membersSnap.data!.docs) {
                        final role = (d.data()['role'] ?? '') as String;
                        if (role != 'admin') employees++;
                      }
                    }

                    return TDScaffold(
                      appBar: AppBar(
                        title: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Yönetim Paneli', style: GoogleFonts.outfit(fontSize: 14, color: Colors.white70)),
                            Text(companyName, style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                          ],
                        ),
                        centerTitle: false,
                        backgroundColor: Colors.transparent,
                        actions: [
                          IconButton(
                            tooltip: 'Yenile',
                            onPressed: () => setState(() {}),
                            icon: Container(
                               padding: const EdgeInsets.all(8),
                               decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(12)),
                               child: const Icon(Icons.refresh_rounded, color: Colors.white)
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            tooltip: 'Çıkış',
                            onPressed: _signOut,
                            icon: Container(
                               padding: const EdgeInsets.all(8),
                               decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(12)),
                               child: const Icon(Icons.logout_rounded, color: Colors.white)
                            ),
                          ),
                          const SizedBox(width: 16),
                        ],
                      ),
                      body: ListView(
                        padding: const EdgeInsets.all(20),
                        children: [
                          _HeaderCard(
                            subtitle: 'Şirket Kodu: $companyCode', 
                          ),
                          const SizedBox(height: 24),

                          Row(
                            children: [
                              Expanded(child: _KpiCard(title: 'Bekleyen', value: tasksSnap.hasData ? '$pending' : '...', icon: Icons.pending_actions_rounded, color: Colors.orangeAccent, onTap: () => context.push('/admin/tasks?status=pending'))),
                              const SizedBox(width: 12),
                              Expanded(child: _KpiCard(title: 'Tamamlanan', value: tasksSnap.hasData ? '$done' : '...', icon: Icons.verified_rounded, color: Colors.greenAccent, onTap: () => context.push('/admin/tasks?status=done'))),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                               Expanded(child: _KpiCard(title: 'Geciken', value: tasksSnap.hasData ? '$overdue' : '...', icon: Icons.timer_off_rounded, color: Colors.redAccent, onTap: () => context.push('/admin/tasks?overdue=1'))),
                               const SizedBox(width: 12),
                               Expanded(child: _KpiCard(title: 'Çalışan', value: membersSnap.hasData ? '$employees' : '...', icon: Icons.people_alt_rounded, color: Colors.blueAccent, onTap: () => context.push('/admin/employees'))),
                            ],
                          ),

                          const SizedBox(height: 24),
                          Text('Hızlı İşlemler', style: GoogleFonts.outfit(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 12),

                          _ActionGrid(items: [
                            _ActionItem(title: 'Görev Ata', subtitle: 'Yeni görev oluştur', icon: Icons.add_task_rounded, onTap: () => context.push('/admin/task/create')),
                            _ActionItem(title: 'Görevler', subtitle: 'Tüm görevleri yönet', icon: Icons.list_alt_rounded, onTap: () => context.push('/admin/tasks')),
                            _ActionItem(title: 'Müdürler', subtitle: 'Yönetici kadrosu', icon: Icons.supervisor_account_rounded, onTap: () => context.push('/admin/managers')),
                            _ActionItem(title: 'Çalışanlar', subtitle: 'Personel listesi', icon: Icons.badge_rounded, onTap: () => context.push('/admin/employees')),
                            _ActionItem(title: 'Departmanlar', subtitle: 'Birimleri düzenle', icon: Icons.apartment_rounded, onTap: () => context.push('/admin/departments')),
                          ]),

                          const SizedBox(height: 24),
                          Text('Yönetim', style: GoogleFonts.outfit(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 12),

                          _BigTile(
                            icon: Icons.person_add_alt_1_rounded,
                            title: 'Çalışan Daveti',
                            subtitle: 'Davet kodu oluştur',
                            onTap: () => context.push('/admin/invite'),
                          ),
                          const SizedBox(height: 12),
                          _BigTile(
                            icon: Icons.business_rounded,
                            title: 'Şirket Bilgileri',
                            subtitle: 'Şirket ayarlarını güncelle',
                            onTap: () => context.push('/company/create'), // Create page edits if exists
                          ),
                          
                          const SizedBox(height: 32),
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

// --- Modern Components Helpers ---

BoxDecoration _cardDecoration() {
  return BoxDecoration(
    color: Colors.white.withOpacity(0.08),
    borderRadius: BorderRadius.circular(20),
    border: Border.all(color: Colors.white.withOpacity(0.1)),
    boxShadow: [
       BoxShadow(color: Colors.black12, blurRadius: 10, offset: const Offset(0, 4)),
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
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: const Color(0xFF4C51BF).withOpacity(0.4), blurRadius: 12, offset: const Offset(0, 4))],
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

class _HeaderCard extends StatelessWidget {
  final String subtitle;
  const _HeaderCard({required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [Color(0xFF4C51BF).withOpacity(0.8), Color(0xFF6B46C1).withOpacity(0.8)]),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(16)),
            child: const Icon(Icons.dashboard_rounded, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Admin Paneli', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                const SizedBox(height: 4),
                Text(subtitle, style: GoogleFonts.outfit(color: Colors.white70, fontSize: 14)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const _KpiCard({required this.title, required this.value, required this.icon, required this.color, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _cardDecoration(),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: color.withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
                  child: Icon(icon, color: color, size: 24),
                ),
                const SizedBox(height: 16),
                Text(value, style: GoogleFonts.outfit(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                Text(title, style: GoogleFonts.outfit(color: Colors.white60, fontSize: 13)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionGrid extends StatelessWidget {
  final List<_ActionItem> items;
  const _ActionGrid({required this.items});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: items.map((i) {
        return LayoutBuilder(
           builder: (context, constraints) {
             // Basitçe ekran genişliğine göre 2'li grid
             final w = (MediaQuery.of(context).size.width - 40 - 12) / 2; 
             return SizedBox(width: w, child: _ActionCard(item: i));
           }
        );
      }).toList(),
    );
  }
}

class _ActionItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  _ActionItem({required this.title, required this.subtitle, required this.icon, required this.onTap});
}

class _ActionCard extends StatelessWidget {
  final _ActionItem item;
  const _ActionCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _cardDecoration(),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: item.onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(item.icon, color: Colors.white, size: 28),
                const SizedBox(height: 12),
                Text(item.title, style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 4),
                Text(item.subtitle, style: GoogleFonts.outfit(color: Colors.white54, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BigTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _BigTile({required this.icon, required this.title, required this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _cardDecoration(),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(12)),
                  child: Icon(icon, color: Colors.white),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                      Text(subtitle, style: GoogleFonts.outfit(color: Colors.white54, fontSize: 13)),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: Colors.white24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
