import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:teamduty/ui/td_scaffold.dart';

import '../../services/task_service.dart';

class CreateTaskPage extends StatefulWidget {
  const CreateTaskPage({super.key});

  @override
  State<CreateTaskPage> createState() => _CreateTaskPageState();
}

class _CreateTaskPageState extends State<CreateTaskPage> {
  final _title = TextEditingController();
  final _desc = TextEditingController();

  String? _departmentId;
  String? _selectedEmployeeUid;
  DateTime? _dueAt;
  String _priority = 'normal';

  bool _saving = false;

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    super.dispose();
  }

  Future<void> _pickDueDate() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      firstDate: now.subtract(const Duration(days: 0)),
      lastDate: now.add(const Duration(days: 365)),
      initialDate: _dueAt ?? now,
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
    if (date == null) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_dueAt ?? now.add(const Duration(hours: 1))),
      builder: (context, child) { // Timepicker theme
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
    if (time == null) return;

    setState(() {
      _dueAt = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  String _fmtDue(DateTime? dt) {
    if (dt == null) return 'Zaman Seç';
    final d = dt.toLocal();
    return '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _save({
    required String companyId,
    required Map<String, String> deptNameById,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> members,
  }) async {
    final title = _title.text.trim();
    final desc = _desc.text.trim();

    final cid = companyId;
    final depId = _departmentId;
    final toUid = _selectedEmployeeUid;

    if (title.isEmpty) {
      _showSnack('Başlık boş olamaz', isError: true);
      return;
    }
    if (depId == null || depId.isEmpty) {
      _showSnack('Departman seçmelisin', isError: true);
      return;
    }
    if (toUid == null || toUid.isEmpty) {
      _showSnack('Çalışan seçmelisin', isError: true);
      return;
    }

    final exists = members.any((m) => m.id == toUid);
    if (!exists) {
      _showSnack('Seçilen çalışan bulunamadı.', isError: true);
      return;
    }

    setState(() => _saving = true);
    try {
      await TaskService().createTask(
        companyId: cid,
        title: title,
        description: desc,
        assignedToUid: toUid,
        departmentId: depId,
        dueAt: _dueAt,
        priority: _priority,
      );

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
    final u = FirebaseAuth.instance.currentUser;
    if (u == null) return const TDScaffold(body: Center(child: Text('Oturum yok')));

    final userStream = FirebaseFirestore.instance.collection('users').doc(u.uid).snapshots();

    return TDScaffold(
      appBar: AppBar(
        title: Text('Yeni Görev', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: userStream,
        builder: (context, userSnap) {
          if (userSnap.hasError) return Center(child: Text('Hata: ${userSnap.error}', style: const TextStyle(color: Colors.white)));
          if (!userSnap.hasData) return const Center(child: CircularProgressIndicator(color: Colors.white));

          final companyId = userSnap.data!.data()?['activeCompanyId'] as String?;
          if (companyId == null || companyId.isEmpty) return const Center(child: Text('Aktif şirket bulunamadı.', style: TextStyle(color: Colors.white)));

          final depsStream = FirebaseFirestore.instance.collection('companies').doc(companyId).collection('departments').snapshots();
          final membersStream = FirebaseFirestore.instance.collection('companies').doc(companyId).collection('members').where('role', whereIn: const ['employee', 'manager']).snapshots();

          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: depsStream,
            builder: (context, depSnap) {
              if (depSnap.hasError) return Center(child: Text('Departman hata: ${depSnap.error}'));
              if (!depSnap.hasData) return const Center(child: CircularProgressIndicator(color: Colors.white));

              final deptNameById = <String, String>{};
              for (final d in depSnap.data!.docs) {
                deptNameById[d.id] = (d.data()['name'] ?? '-') as String;
              }

              return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: membersStream,
                builder: (context, memSnap) {
                  if (memSnap.hasError) return Center(child: Text('Çalışan hata: ${memSnap.error}'));
                  if (!memSnap.hasData) return const Center(child: CircularProgressIndicator(color: Colors.white));

                  final membersAll = memSnap.data!.docs.toList();
                  final members = (_departmentId == null || _departmentId!.isEmpty)
                      ? membersAll
                      : membersAll.where((m) {
                          final dep = (m.data()['departmentId'] ?? '') as String;
                          return dep == _departmentId;
                        }).toList();

                  if (_selectedEmployeeUid != null && members.every((m) => m.id != _selectedEmployeeUid)) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) setState(() => _selectedEmployeeUid = null);
                    });
                  }

                  members.sort((a, b) {
                    final an = ((a.data()['displayName'] ?? '') as String).toLowerCase();
                    final bn = ((b.data()['displayName'] ?? '') as String).toLowerCase();
                    return an.compareTo(bn);
                  });

                  final deptItems = deptNameById.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value, style: GoogleFonts.outfit()))).toList();

                  final memberItems = members.map((m) {
                    final data = m.data();
                    final name = (data['displayName'] ?? m.id) as String;
                    final role = (data['role'] ?? '') as String;
                    return DropdownMenuItem(
                      value: m.id,
                      child: Text('$name ($role)', style: GoogleFonts.outfit(), overflow: TextOverflow.ellipsis),
                    );
                  }).toList();

                  return ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: _cardDecoration(),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Görev Detayları', style: GoogleFonts.outfit(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 16),
                            _buildInput(controller: _title, label: 'Başlık', icon: Icons.title),
                            const SizedBox(height: 12),
                            _buildInput(controller: _desc, label: 'Açıklama', icon: Icons.description, maxLines: 3),
                            const SizedBox(height: 12),
                            
                            InkWell(
                              onTap: _pickDueDate,
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
                                    Text(
                                      _dueAt == null ? 'Bitiş Tarihi Seç (Opsiyonel)' : _fmtDue(_dueAt),
                                      style: GoogleFonts.outfit(color: Colors.white70, fontSize: 16),
                                    ),
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
                             const SizedBox(height: 12),
                             _buildDropdown(
                               value: _priority,
                               items: const [
                                 DropdownMenuItem(value: 'low', child: Text('Düşük Öncelik')),
                                 DropdownMenuItem(value: 'normal', child: Text('Normal Öncelik')),
                                 DropdownMenuItem(value: 'high', child: Text('Yüksek Öncelik (Acil)')),
                               ],
                               label: 'Öncelik Seviyesi',
                               icon: Icons.flag_outlined,
                               onChanged: (v) => setState(() => _priority = v!),
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
                             Text('Atama Yapılacak Kişi', style: GoogleFonts.outfit(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                             const SizedBox(height: 16),
                             _buildDropdown(
                               value: _departmentId, 
                               items: deptItems, 
                               label: 'Departman', 
                               icon: Icons.apartment,
                               onChanged: (v) => setState(() { _departmentId = v; _selectedEmployeeUid = null; })
                             ),
                             const SizedBox(height: 12),
                             _buildDropdown(
                               value: _selectedEmployeeUid, 
                               items: memberItems, 
                               label: 'Çalışan', 
                               icon: Icons.person,
                               helperText: (_departmentId == null) ? 'Önce departman seçin' : null,
                               onChanged: (v) => setState(() => _selectedEmployeeUid = v)
                             ),
                           ],
                        ),
                      ),
                      
                      const SizedBox(height: 24),
                      
                      _GradientButton(
                        onPressed: (_saving) ? () {} : () => _save(companyId: companyId, deptNameById: deptNameById, members: membersAll),
                        text: _saving ? 'Kaydediliyor...' : 'Görevi Oluştur',
                      ),
                    ],
                  );
                },
              );
            },
          );
        },
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

  Widget _buildDropdown({required String? value, required List<DropdownMenuItem<String>> items, required String label, required IconData icon, required Function(String?) onChanged, String? helperText}) {
    return Container(
       decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: DropdownButtonFormField<String>(
        value: value,
        items: items,
        onChanged: onChanged,
        style: GoogleFonts.outfit(color: Colors.white),
        dropdownColor: const Color(0xFF1E293B),
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: Colors.blueGrey.shade200),
          labelText: label,
          labelStyle: GoogleFonts.outfit(color: Colors.white54),
          helperText: helperText,
          helperStyle: GoogleFonts.outfit(color: Colors.white38),
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
