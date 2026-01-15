import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../ui/td_scaffold.dart';
import '../manager/manager_tasks_tab.dart';
import '../manager/manager_employees_tab.dart';
import '../manager/manager_stats_tab.dart';

class ManagerHomePage extends StatefulWidget {
  const ManagerHomePage({super.key});

  @override
  State<ManagerHomePage> createState() => _ManagerHomePageState();
}

class _ManagerHomePageState extends State<ManagerHomePage> {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;

  bool _loading = true;
  String? _error;

  String? companyId;
  String? myDeptId;
  String? myUid;
  String? myName;

  int _tab = 0;

  @override
  void initState() {
    super.initState();
    _loadContext();
  }

  Future<void> _loadContext() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final u = _auth.currentUser;
      if (u == null) throw Exception('Oturum yok');

      final userSnap = await _db.collection('users').doc(u.uid).get();
      final cId = userSnap.data()?['activeCompanyId'] as String?;
      if (cId == null || cId.isEmpty) {
        throw Exception('users/${u.uid} activeCompanyId yok');
      }

      final memberSnap = await _db
          .collection('companies')
          .doc(cId)
          .collection('members')
          .doc(u.uid)
          .get();

      final role = memberSnap.data()?['role'] as String?;
      final dept = memberSnap.data()?['departmentId'] as String?;
      final name = memberSnap.data()?['displayName'] as String?;

      if (role != 'manager') throw Exception('Bu hesap manager değil. Rol: $role');
      if (dept == null || dept.isEmpty) throw Exception('Manager için departmentId atanmalı.');

      setState(() {
        myUid = u.uid;
        companyId = cId;
        myDeptId = dept;
        myName = name ?? 'Müdür';
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _signOut() async {
    await _auth.signOut();
    if (!mounted) return;
    context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const TDScaffold(
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    if (_error != null) {
      return TDScaffold(
        appBar: AppBar(
          backgroundColor: Colors.transparent,
           iconTheme: const IconThemeData(color: Colors.white),
           actions: [
             IconButton(onPressed: _signOut, icon: const Icon(Icons.logout))
           ],
        ),
        body: Center(
          child: Container(
            margin: const EdgeInsets.all(24),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white12),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline, size: 48, color: Colors.white70),
                const SizedBox(height: 16),
                Text('Hata Oluştu', style: GoogleFonts.outfit(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(_error!, style: GoogleFonts.outfit(color: Colors.white70), textAlign: TextAlign.center),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _loadContext,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: const Color(0xFF1A1A2E)),
                  child: const Text('Tekrar Dene'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final tabs = [
      ManagerTasksTab(companyId: companyId!, deptId: myDeptId!, myUid: myUid!),
      ManagerEmployeesTab(companyId: companyId!, deptId: myDeptId!),
      ManagerStatsTab(companyId: companyId!, deptId: myDeptId!, myUid: myUid!),
    ];

    return TDScaffold(
      extendBodyBehindAppBar: false,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Müdür Paneli', style: GoogleFonts.outfit(fontSize: 14, color: Colors.white70)),
            Text(myName ?? '', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
          ],
        ),
        centerTitle: false,
        backgroundColor: Colors.transparent,
        scrolledUnderElevation: 0,
        actions: [
          IconButton(
            onPressed: _loadContext, 
            icon: Tooltip(message: 'Yenile', child: Icon(Icons.refresh_rounded, color: Colors.white))
          ),
          IconButton(
            onPressed: _signOut, 
            icon: Tooltip(message: 'Çıkış', child: Icon(Icons.logout_rounded, color: Colors.white))
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: tabs[_tab],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF16213E).withOpacity(0.9),
          border: const Border(top: BorderSide(color: Colors.white10)),
        ),
        child: NavigationBarTheme(
          data: NavigationBarThemeData(
            backgroundColor: Colors.transparent,
            indicatorColor: const Color(0xFF4C51BF),
            labelTextStyle: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12);
              }
              return GoogleFonts.outfit(color: Colors.white60, fontSize: 12);
            }),
            iconTheme: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return const IconThemeData(color: Colors.white);
              }
              return const IconThemeData(color: Colors.white60);
            }),
          ),
          child: NavigationBar(
            height: 70,
            selectedIndex: _tab,
            onDestinationSelected: (i) => setState(() => _tab = i),
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.checklist_rtl_rounded), 
                selectedIcon: Icon(Icons.checklist_rounded),
                label: 'Görevler'
              ),
              NavigationDestination(
                icon: Icon(Icons.people_outline_rounded), 
                selectedIcon: Icon(Icons.people_rounded),
                label: 'Ekip'
              ),
              NavigationDestination(
                icon: Icon(Icons.analytics_outlined), 
                selectedIcon: Icon(Icons.analytics_rounded),
                label: 'Analiz'
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: _tab == 0
          ? FloatingActionButton.extended(
              onPressed: () => context.push('/manager/task/create'),
              backgroundColor: const Color(0xFF4C51BF),
              foregroundColor: Colors.white,
              elevation: 4,
              icon: const Icon(Icons.add_task_rounded),
              label: Text('Görev Ata', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
            )
          : null,
    );
  }
}
