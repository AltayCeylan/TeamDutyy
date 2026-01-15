import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

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

      if (role != 'manager') throw Exception('Bu hesap manager değil (role=$role)');
      if (dept == null || dept.isEmpty) throw Exception('Manager için departmentId atanmalı');

      setState(() {
        myUid = u.uid;
        companyId = cId;
        myDeptId = dept;
        myName = name ?? 'Müdür';
        _loading = false;
      });
    } catch (e) {
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

  AppBar _appBar(BuildContext context, {required String title}) {
    return AppBar(
      title: Text(title),
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      actions: [
        IconButton(
          tooltip: 'Yenile',
          onPressed: _loadContext,
          icon: const Icon(Icons.refresh_rounded),
        ),
        IconButton(
          tooltip: 'Çıkış',
          onPressed: _signOut,
          icon: const Icon(Icons.logout_rounded),
        ),
      ],
    );
  }

  Widget _loadingView() {
    return const Center(child: CircularProgressIndicator());
  }

  Widget _errorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Hata: $_error'),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _loadContext,
                    child: const Text('Tekrar Dene'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Tabs hazır değilse bile TDScaffold ile tema/arka plan aynı kalsın
    final title = _loading
        ? 'Müdür Paneli'
        : _error != null
            ? 'Müdür'
            : 'Müdür Paneli • ${myName ?? ''}';

    final content = _loading
        ? _loadingView()
        : (_error != null)
            ? _errorView()
            : _buildTabs();

    return TDScaffold(
      appBar: _appBar(context, title: title),
      body: content,
      bottomNavigationBar: _loading || _error != null ? null : _bottomBar(context),
      floatingActionButton: _loading || _error != null
          ? null
          : (_tab == 0
              ? FloatingActionButton.extended(
                  onPressed: () => context.push('/manager/task/create'),
                  icon: const Icon(Icons.add),
                  label: const Text('Görev Ata'),
                )
              : null),
    );
  }

  Widget _buildTabs() {
    final tabs = [
      ManagerTasksTab(companyId: companyId!, deptId: myDeptId!, myUid: myUid!),
      ManagerEmployeesTab(companyId: companyId!, deptId: myDeptId!),
      ManagerStatsTab(companyId: companyId!, deptId: myDeptId!, myUid: myUid!),
    ];
    return tabs[_tab];
  }

  Widget _bottomBar(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;

    // Premium arka planı kapatmasın diye saydam NavigationBar
    return NavigationBarTheme(
      data: NavigationBarThemeData(
        backgroundColor: Colors.white.withOpacity(0.06),
        indicatorColor: Colors.white.withOpacity(0.10),
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(color: onSurface.withOpacity(0.80)),
        ),
        iconTheme: WidgetStatePropertyAll(
          IconThemeData(color: onSurface.withOpacity(0.85)),
        ),
      ),
      child: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.checklist_rounded), label: 'Görevler'),
          NavigationDestination(icon: Icon(Icons.people_alt_rounded), label: 'Çalışanlar'),
          NavigationDestination(icon: Icon(Icons.analytics_rounded), label: 'İstatistik'),
        ],
      ),
    );
  }
}
