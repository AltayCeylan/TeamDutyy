import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:teamduty/ui/td_scaffold.dart';

class TaskDetailPage extends StatefulWidget {
  final String companyId;
  final String taskId;

  const TaskDetailPage({
    super.key,
    required this.companyId,
    required this.taskId,
  });

  @override
  State<TaskDetailPage> createState() => _TaskDetailPageState();
}

class _TaskDetailPageState extends State<TaskDetailPage> {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  Future<void> _markDone(DocumentSnapshot<Map<String, dynamic>> snap) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    final data = snap.data() ?? {};
    final assignedTo = data['assignedToUid'] as String?;
    final status = (data['status'] as String?) ?? 'pending';

    if (status == 'canceled') {
      _showSnack('İptal edilmiş görev değiştirilemez.', isError: true);
      return;
    }

    if (assignedTo != uid) {
      _showSnack('Bu görev sana atanmadı.', isError: true);
      return;
    }

    try {
      await snap.reference.update({
        'status': 'done',
        'doneAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (!mounted) return;
      _showSnack('Görev tamamlandı ✅');
    } catch (e) {
      if (!mounted) return;
      _showSnack('Hata: $e', isError: true);
    }
  }

  Future<void> _markPending(DocumentSnapshot<Map<String, dynamic>> snap) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    final data = snap.data() ?? {};
    final assignedTo = data['assignedToUid'] as String?;
    final status = (data['status'] as String?) ?? 'pending';

    if (status == 'canceled') {
      _showSnack('İptal edilmiş görev değiştirilemez.', isError: true);
      return;
    }

    if (assignedTo != uid) {
      _showSnack('Bu görev sana atanmadı.', isError: true);
      return;
    }

    try {
      await snap.reference.update({
        'status': 'pending',
        'doneAt': null,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (!mounted) return;
      _showSnack('Görev tekrar beklemeye alındı.');
    } catch (e) {
      if (!mounted) return;
      _showSnack('Hata: $e', isError: true);
    }
  }

  Future<void> _cancelTask({required DocumentReference<Map<String, dynamic>> ref}) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    final reasonCtrl = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: Text('Görevi İptal Et', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: reasonCtrl,
          style: GoogleFonts.outfit(color: Colors.white),
          decoration: InputDecoration(
            labelText: 'İptal Nedeni (Opsiyonel)',
            labelStyle: GoogleFonts.outfit(color: Colors.white54),
            enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
          ),
          maxLines: 2,
        ),
        actions: [
          TextButton(
             onPressed: () => Navigator.pop(context, false), 
             child: Text('Vazgeç', style: GoogleFonts.outfit(color: Colors.white60))
          ),
          TextButton(
             onPressed: () => Navigator.pop(context, true), 
             child: Text('İptal Et', style: GoogleFonts.outfit(color: Colors.redAccent, fontWeight: FontWeight.bold))
          ),
        ],
      ),
    );

    if (ok != true) return;

    try {
      await ref.update({
        'status': 'canceled',
        'canceledAt': FieldValue.serverTimestamp(),
        'canceledByUid': uid,
        'cancelReason': reasonCtrl.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      _showSnack('Görev iptal edildi');
    } catch (e) {
      if (!mounted) return;
      _showSnack('Hata: $e', isError: true);
    }
  }

  Future<void> _uncancelTask({required DocumentReference<Map<String, dynamic>> ref}) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: Text('İptali Geri Al', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text('Bu görevi tekrar aktif yapmak istiyor musun?', style: GoogleFonts.outfit(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Vazgeç', style: GoogleFonts.outfit(color: Colors.white60))),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text('Geri Al', style: GoogleFonts.outfit(color: Colors.greenAccent, fontWeight: FontWeight.bold))),
        ],
      ),
    );

    if (ok != true) return;

    try {
      await ref.update({
        'status': 'pending',
        'canceledAt': null,
        'canceledByUid': null,
        'cancelReason': null,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      _showSnack('İptal geri alındı');
    } catch (e) {
      if (!mounted) return;
      _showSnack('Hata: $e', isError: true);
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

  String _fmtDateTime(DateTime d) {
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    final hh = d.hour.toString().padLeft(2, '0');
    final mi = d.minute.toString().padLeft(2, '0');
    return '$dd.$mm.${d.year} $hh:$mi';
  }

  String _remainingLabel(DateTime due) {
    final diff = due.difference(DateTime.now());
    if (diff.isNegative) {
      final over = diff.abs();
      if (over.inDays >= 1) return '${over.inDays}g gecikmiş';
      if (over.inHours >= 1) return '${over.inHours}s gecikmiş';
      return '${over.inMinutes}dk gecikmiş';
    } else {
      if (diff.inDays >= 1) return '${diff.inDays}g kaldı';
      if (diff.inHours >= 1) return '${diff.inHours}s kaldı';
      return '${diff.inMinutes}dk kaldı';
    }
  }

  @override
  Widget build(BuildContext context) {
    final taskRef = _db.collection('companies').doc(widget.companyId).collection('tasks').doc(widget.taskId);
    final me = _auth.currentUser?.uid;

    final memberStream = (me == null)
        ? const Stream.empty()
        : _db.collection('companies').doc(widget.companyId).collection('members').doc(me).snapshots();

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: taskRef.snapshots(),
      builder: (context, snap) {
         if (snap.hasError) return TDScaffold(body: Center(child: Text('Hata: ${snap.error}', style: const TextStyle(color: Colors.white))));
         if (!snap.hasData) return const TDScaffold(body: Center(child: CircularProgressIndicator(color: Colors.white)));

         final doc = snap.data!;
         final data = doc.data() ?? {};

         final title = (data['title'] as String?) ?? 'Görev';
         final desc = (data['description'] as String?) ?? '';
         final status = (data['status'] as String?) ?? 'pending';

         final dueRaw = data['dueAt'];
         DateTime? dueAt;
         if (dueRaw is Timestamp) dueAt = dueRaw.toDate();

         final createdRaw = data['createdAt'];
         DateTime? createdAt;
         if (createdRaw is Timestamp) createdAt = createdRaw.toDate();

         final doneRaw = data['doneAt'];
         DateTime? doneAt;
         if (doneRaw is Timestamp) doneAt = doneRaw.toDate();

         final canceledRaw = data['canceledAt'];
         DateTime? canceledAt;
         if (canceledRaw is Timestamp) canceledAt = canceledRaw.toDate();

         final cancelReason = (data['cancelReason'] as String?) ?? '';

         final assignedTo = data['assignedToUid'] as String?;
         final isMine = (me != null && assignedTo == me);

         final isDone = status == 'done';
         final isCanceled = status == 'canceled';
         final isOverdue = dueAt != null && dueAt!.isBefore(DateTime.now()) && !isDone && !isCanceled;

         return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
           stream: memberStream as Stream<DocumentSnapshot<Map<String, dynamic>>>,
           builder: (context, memberSnap) {
             final role = memberSnap.data?.data()?['role'] as String?;
             final canAdminCancel = role == 'admin' || role == 'manager';

             return TDScaffold(
               appBar: AppBar(
                 title: Text('Görev Detayı', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
                 centerTitle: true,
                 backgroundColor: Colors.transparent,
                 iconTheme: const IconThemeData(color: Colors.white),
                 actions: [
                   if (canAdminCancel && !isCanceled)
                     IconButton(
                       tooltip: 'Görevi İptal Et',
                       icon: const Icon(Icons.cancel_outlined, color: Colors.white70),
                       onPressed: () => _cancelTask(ref: doc.reference),
                     ),
                   if (canAdminCancel && isCanceled)
                     IconButton(
                       tooltip: 'İptali Geri Al',
                       icon: const Icon(Icons.restore_page_outlined, color: Colors.white70),
                       onPressed: () => _uncancelTask(ref: doc.reference),
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
                         Row(
                           crossAxisAlignment: CrossAxisAlignment.start,
                           children: [
                             Container(
                               padding: const EdgeInsets.all(12),
                               decoration: BoxDecoration(
                                 color: Colors.white.withOpacity(0.1),
                                 borderRadius: BorderRadius.circular(12),
                               ),
                               child: Icon(
                                 isDone ? Icons.check_circle_outline : (isCanceled ? Icons.cancel_outlined : Icons.pending_outlined), 
                                 size: 32, 
                                 color: isDone ? Colors.greenAccent : (isCanceled ? Colors.redAccent : Colors.orangeAccent)
                               ),
                             ),
                             const SizedBox(width: 16),
                             Expanded(
                               child: Column(
                                 crossAxisAlignment: CrossAxisAlignment.start,
                                 children: [
                                   Text(title, style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                                   const SizedBox(height: 8),
                                   Wrap(
                                      spacing: 8, runSpacing: 8,
                                      children: [
                                        _StatusChip(
                                          label: isCanceled ? 'İPTAL' : (isDone ? 'TAMAMLANDI' : 'BEKLEMEDE'),
                                          color: isCanceled ? Colors.redAccent : (isDone ? Colors.greenAccent : Colors.orangeAccent),
                                        ),
                                        if (isOverdue) _StatusChip(label: 'GECİKMİŞ', color: Colors.red),
                                        if (dueAt != null && !isCanceled && !isDone) 
                                          _StatusChip(label: _remainingLabel(dueAt!), color: Colors.blueAccent),
                                      ],
                                   ),
                                 ],
                               ),
                             ),
                           ],
                         ),
                         const SizedBox(height: 16),
                         Divider(color: Colors.white.withOpacity(0.1)),
                         const SizedBox(height: 16),
                         if (desc.isNotEmpty) ...[
                           Text('Açıklama', style: GoogleFonts.outfit(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                           const SizedBox(height: 4),
                           Text(desc, style: GoogleFonts.outfit(color: Colors.white, fontSize: 15, height: 1.5)),
                           const SizedBox(height: 16),
                         ],
                         if (isCanceled && cancelReason.isNotEmpty) ...[
                           Container(
                             width: double.infinity,
                             padding: const EdgeInsets.all(12),
                             decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                             child: Column(
                               crossAxisAlignment: CrossAxisAlignment.start,
                               children: [
                                 Text('İptal Nedeni:', style: GoogleFonts.outfit(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                                 Text(cancelReason, style: GoogleFonts.outfit(color: Colors.white)),
                               ],
                             ),
                           ),
                           const SizedBox(height: 16),
                         ],
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
                         Text('Zaman Çizelgesi', style: GoogleFonts.outfit(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                         const SizedBox(height: 16),
                         _TimeRow(label: 'Oluşturulma', time: createdAt != null ? _fmtDateTime(createdAt!) : '-'),
                         _TimeRow(label: 'Son Tarih', time: dueAt != null ? _fmtDateTime(dueAt!) : '-', isHighlight: true),
                         if (isDone) _TimeRow(label: 'Tamamlanma', time: doneAt != null ? _fmtDateTime(doneAt!) : '-', color: Colors.greenAccent),
                         if (isCanceled) _TimeRow(label: 'İptal Tarihi', time: canceledAt != null ? _fmtDateTime(canceledAt!) : '-', color: Colors.redAccent),
                       ],
                     ),
                   ),

                    const SizedBox(height: 24),
                    
                    if (isMine && !isCanceled)
                      Row(
                        children: [
                          if (!isDone)
                            Expanded(
                              child: _GradientButton(
                                text: 'Tamamla',
                                onPressed: () => _markDone(doc),
                                color: const Color(0xFF4C51BF),
                              ),
                            ),
                          if (isDone)
                            Expanded(
                               child: OutlinedButton(
                                 onPressed: () => _markPending(doc),
                                 style: OutlinedButton.styleFrom(
                                   foregroundColor: Colors.white,
                                   side: const BorderSide(color: Colors.white54),
                                   padding: const EdgeInsets.symmetric(vertical: 16),
                                   shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                 ),
                                 child: Text('Geri Al', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                               ),
                            ),
                        ],
                      ),
                    
                    const SizedBox(height: 16),
                    if (!isMine && !isCanceled)
                      Center(child: Text('Bu görev size atanmadığı için işlem yapamazsınız.', style: GoogleFonts.outfit(color: Colors.white38, fontSize: 12))),
                 ],
               ),
             );
           },
         );
      },
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

class _StatusChip extends StatelessWidget {
  final String label;
  final Color color;
  const _StatusChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(label, style: GoogleFonts.outfit(color: color, fontWeight: FontWeight.bold, fontSize: 11)),
    );
  }
}

class _TimeRow extends StatelessWidget {
  final String label;
  final String time;
  final bool isHighlight;
  final Color? color;

  const _TimeRow({required this.label, required this.time, this.isHighlight = false, this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.outfit(color: Colors.white60)),
          Text(time, style: GoogleFonts.outfit(
            color: color ?? (isHighlight ? Colors.white : Colors.white70), 
            fontWeight: isHighlight ? FontWeight.bold : FontWeight.w500
          )),
        ],
      ),
    );
  }
}

class _GradientButton extends StatelessWidget {
  final VoidCallback onPressed;
  final String text;
  final Color color;
  const _GradientButton({required this.onPressed, required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 54,
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [color, color.withOpacity(0.6)]),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: color.withOpacity(0.4), blurRadius: 10, offset: const Offset(0, 4))],
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
