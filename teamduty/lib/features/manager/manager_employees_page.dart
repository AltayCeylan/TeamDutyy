import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:teamduty/ui/td_scaffold.dart';

class ManagerEmployeesPage extends StatelessWidget {
  const ManagerEmployeesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final u = FirebaseAuth.instance.currentUser;
    if (u == null) return const TDScaffold(body: Center(child: Text('Oturum yok')));

    final db = FirebaseFirestore.instance;
    final userDocStream = db.collection('users').doc(u.uid).snapshots();

    return TDScaffold(
      appBar: AppBar(
        title: Text('Departman Çalışanları', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: userDocStream,
        builder: (context, userSnap) {
          final companyId = userSnap.data?.data()?['activeCompanyId'] as String?;
          if (companyId == null || companyId.isEmpty) return const Center(child: Text('Aktif şirket bulunamadı.'));

          final myMemberStream = db.collection('companies').doc(companyId).collection('members').doc(u.uid).snapshots();

          return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: myMemberStream,
            builder: (context, myMemSnap) {
              final myDept = myMemSnap.data?.data()?['departmentId'] as String?;
              if (myDept == null || myDept.isEmpty) return const Center(child: Text('Müdür departmanı bulunamadı.'));

              final employeesStream = db.collection('companies').doc(companyId).collection('members')
                  .where('departmentId', isEqualTo: myDept)
                  .where('role', whereIn: ['employee', 'manager'])
                  .snapshots();

              return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: employeesStream,
                builder: (context, empSnap) {
                  if (empSnap.hasError) return Center(child: Text('Hata: ${empSnap.error}', style: GoogleFonts.outfit(color: Colors.white)));
                  if (!empSnap.hasData) return const Center(child: CircularProgressIndicator(color: Colors.white));

                  final docs = empSnap.data!.docs.toList();
                  docs.sort((a, b) => ((a.data()['displayName'] ?? '') as String).toLowerCase().compareTo((b.data()['displayName'] ?? '') as String) as int);

                  if (docs.isEmpty) return Center(child: Text('Çalışan yok.', style: GoogleFonts.outfit(color: Colors.white60)));

                  return ListView.separated(
                    padding: const EdgeInsets.all(20),
                    itemCount: docs.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, i) {
                      final data = docs[i].data();
                      final name = (data['displayName'] ?? docs[i].id) as String;
                      final no = (data['employeeNo'] ?? '-') as String;
                      final role = (data['role'] ?? '-') as String;

                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 48, height: 48,
                              decoration: BoxDecoration(color: const Color(0xFF4C51BF).withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
                              child: const Icon(Icons.person, color: Color(0xFF4C51BF)),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(name, style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Text('Sicil: $no', style: GoogleFonts.outfit(color: Colors.white54, fontSize: 13)),
                                      const SizedBox(width: 12),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                                        child: Text(role.toUpperCase(), style: GoogleFonts.outfit(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold)),
                                      ),
                                    ],
                                  ),
                                ],
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
      ),
    );
  }
}
