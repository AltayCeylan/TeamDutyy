import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

class ManagerCreateTaskPage extends StatefulWidget {
  const ManagerCreateTaskPage({super.key});

  @override
  State<ManagerCreateTaskPage> createState() => _ManagerCreateTaskPageState();
}

class _ManagerCreateTaskPageState extends State<ManagerCreateTaskPage> {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;

  bool _loading = true;
  bool _saving = false;
  String? _error;

  String? companyId;
  String? myDeptId;
  String? myUid;

  String? _selectedEmployeeUid;

  final _title = TextEditingController();
  final _desc = TextEditingController();
  DateTime? _dueAt;

  @override
  void initState() {
    super.initState();
    _loadContext();
  }

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    super.dispose();
  }

  Future<void> _loadContext() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final u = _auth.currentUser;
      if (u == null) throw Exception('Oturum yok');

      myUid = u.uid;

      final userSnap = await _db.collection('users').doc(u.uid).get();
      final cId = userSnap.data()?['activeCompanyId'] as String?;
      if (cId == null || cId.isEmpty) throw Exception('activeCompanyId yok');

      final memSnap = await _db.collection('companies').doc(cId).collection('members').doc(u.uid).get();
      final role = memSnap.data()?['role'] as String?;
      final dept = memSnap.data()?['departmentId'] as String?;

      if (role != 'manager') throw Exception('Bu hesap manager değil. Rol: $role');
      if (dept == null || dept.isEmpty) throw Exception('Manager için departmentId atanmalı.');

      setState(() {
        companyId = cId;
        myDeptId = dept;
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

  Future<void> _pickDue() async {
    final now = DateTime.now();
    final pickedDate = await showDatePicker(
      context: context,
      firstDate: now.subtract(const Duration(days: 0)),
      lastDate: now.add(const Duration(days: 365)),
      initialDate: _dueAt ?? now.add(const Duration(days: 1)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
             colorScheme: const ColorScheme.dark(
               primary: Color(0xFF4C51BF),
               onPrimary: Colors.white,
               surface: Color(0xFF1E293B),
               onSurface: Colors.white,
             ),
             textButtonTheme: TextButtonThemeData(
               style: TextButton.styleFrom(foregroundColor: const Color(0xFF4C51BF)),
             ),
          ),
          child: child!,
        );
      },
    );
    if (pickedDate == null) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_dueAt ?? now.add(const Duration(hours: 2))),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            timePickerTheme: TimePickerThemeData(
               backgroundColor: const Color(0xFF1E293B),
               hourMinuteTextColor: Colors.white,
               dayPeriodTextColor: Colors.white70,
               dialHandColor: const Color(0xFF4C51BF),
               dialBackgroundColor: Colors.white10,
               hourMinuteColor: WidgetStateColor.resolveWith((states) => states.contains(WidgetState.selected) ? const Color(0xFF4C51BF) : Colors.white10),
            ),
             textButtonTheme: TextButtonThemeData(
               style: TextButton.styleFrom(foregroundColor: const Color(0xFF4C51BF)),
             ),
          ),
          child: child!,
        );
      }
    );
    if (pickedTime == null) return;

    setState(() {
      _dueAt = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime.hour,
        pickedTime.minute,
      );
    });
  }

  String _dueLabel() {
    final d = _dueAt;
    if (d == null) return 'Bitiş Tarihi Seç (Opsiyonel)';
    final hh = d.hour.toString().padLeft(2, '0');
    final mm = d.minute.toString().padLeft(2, '0');
    return '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}  $hh:$mm';
  }

  Future<void> _createTask() async {
    if (_saving) return;

    final cId = companyId;
    final dept = myDeptId;
    final uid = myUid;

    if (cId == null || dept == null || uid == null) return;

    final title = _title.text.trim();
    final desc = _desc.text.trim();

    if (title.isEmpty) {
      _showSnack('Başlık boş olamaz', isError: true);
      return;
    }
    if (_selectedEmployeeUid == null) {
      _showSnack('Çalışan seçmelisin', isError: true);
      return;
    }

    setState(() => _saving = true);

    try {
      await _db.collection('companies').doc(cId).collection('tasks').add({
        'title': title,
        'description': desc,
        'departmentId': dept,
        'assignedToUid': _selectedEmployeeUid,
        'assignedByUid': uid,
        'status': 'pending',
        'dueAt': _dueAt == null ? null : Timestamp.fromDate(_dueAt!),
        'createdAt': FieldValue.serverTimestamp(),
        'doneAt': null,
      });

      if (!mounted) return;
      _showSnack('Görev başarıyla oluşturuldu');
      context.pop();
    } catch (e) {
      if (!mounted) return;
      _showSnack('Hata: $e', isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.outfit(color: Colors.white)),
        backgroundColor: isError ? Colors.redAccent : Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(backgroundColor: Colors.transparent, body: Center(child: CircularProgressIndicator()));

    if (_error != null) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(title: const Text('Hata'), backgroundColor: Colors.transparent, iconTheme: const IconThemeData(color: Colors.white)),
        body: Center(child: Text('Hata: $_error', style: GoogleFonts.outfit(color: Colors.white))),
      );
    }

    final cId = companyId!;
    final dept = myDeptId!;
    final employeesQuery = _db
        .collection('companies')
        .doc(cId)
        .collection('members')
        .where('departmentId', isEqualTo: dept)
        .where('role', whereIn: ['employee', 'manager']);

    return Scaffold(
      backgroundColor: Colors.transparent, // TDScaffold background parent
      appBar: AppBar(
        title: Text('Görev Ata', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            tooltip: 'Yenile',
            onPressed: _loadContext,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: _cardDecoration(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Yeni Görev', style: GoogleFonts.outfit(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                _buildInput(controller: _title, label: 'Başlık', icon: Icons.title),
                const SizedBox(height: 12),
                _buildInput(controller: _desc, label: 'Açıklama', icon: Icons.description, maxLines: 3),
                const SizedBox(height: 12),
                InkWell(
                   onTap: _pickDue,
                   borderRadius: BorderRadius.circular(12),
                   child: Container(
                     padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                     decoration: BoxDecoration(
                       color: Colors.white.withOpacity(0.05),
                       borderRadius: BorderRadius.circular(12),
                       border: Border.all(color: Colors.white12),
                     ),
                     child: Row(
                       children: [
                         Icon(Icons.event_outlined, color: Colors.blueGrey.shade200),
                         const SizedBox(width: 12),
                         Text(_dueLabel(), style: GoogleFonts.outfit(color: Colors.white70, fontSize: 16)),
                         const Spacer(),
                         if (_dueAt != null)
                           GestureDetector(
                             onTap: () => setState(() => _dueAt = null),
                             child: const Icon(Icons.close, color: Colors.white54),
                           )
                       ],
                     ),
                   ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          Container(
             padding: const EdgeInsets.all(20),
             decoration: _cardDecoration(),
             child: Column(
               crossAxisAlignment: CrossAxisAlignment.start,
               children: [
                 Text('Atanacak Kişi (Departmanım)', style: GoogleFonts.outfit(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                 const SizedBox(height: 16),
                 StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                   stream: employeesQuery.snapshots(),
                   builder: (context, snap) {
                     if (snap.hasError) return Text('Hata: ${snap.error}', style: GoogleFonts.outfit(color: Colors.redAccent));
                     if (!snap.hasData) return const LinearProgressIndicator();

                     final docs = snap.data!.docs.where((d) => d.id != myUid).toList();
                     if (docs.isEmpty) return Text('Departmanında atanabilecek çalışan yok.', style: GoogleFonts.outfit(color: Colors.white70));

                     final ids = docs.map((d) => d.id).toSet();
                     final safeValue = ids.contains(_selectedEmployeeUid) ? _selectedEmployeeUid : null;

                     return Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white12),
                        ),
                       child: DropdownButtonFormField<String>(
                         value: safeValue,
                         isExpanded: true,
                         dropdownColor: const Color(0xFF1E293B),
                         decoration: InputDecoration(
                           prefixIcon: Icon(Icons.person_outline, color: Colors.blueGrey.shade200),
                           border: InputBorder.none,
                           contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                         ),
                         items: docs.map((d) {
                           final data = d.data();
                           final name = (data['displayName'] as String?) ?? d.id;
                           final role = (data['role'] as String?) ?? '';
                           return DropdownMenuItem(
                             value: d.id,
                             child: Text('$name${role == "manager" ? " (Müdür)" : ""}', style: GoogleFonts.outfit(color: Colors.white)),
                           );
                         }).toList(),
                         onChanged: (v) => setState(() => _selectedEmployeeUid = v),
                         hint: Text('Çalışan Seç', style: GoogleFonts.outfit(color: Colors.white54)),
                       ),
                     );
                   },
                 ),
               ],
             ),
          ),

          const SizedBox(height: 12),
          Opacity(
             opacity: 0.7,
             child: Row(
               children: [
                 Icon(Icons.info_outline, color: Colors.white70, size: 20),
                 const SizedBox(width: 8),
                 Expanded(child: Text('Sadece kendi departmanındaki kişilere görev atayabilirsin.', style: GoogleFonts.outfit(color: Colors.white70, fontSize: 12))),
               ],
             ),
          ),

          const SizedBox(height: 24),

          _GradientButton(
             onPressed: (_saving) ? () {} : _createTask,
             text: _saving ? 'Kaydediliyor...' : 'Görevi Oluştur',
          ),
        ],
      ),
    );
  }

  Widget _buildInput({required TextEditingController controller, required String label, required IconData icon, int maxLines = 1}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        style: GoogleFonts.outfit(color: Colors.white),
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: Colors.blueGrey.shade200),
          labelText: label,
          labelStyle: GoogleFonts.outfit(color: Colors.white54),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }
}

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
      height: 54,
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
