import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

const Color _kGreen = Color(0xFF2C3A2B);

String _fmt(dynamic ts) {
  if (ts is! Timestamp) return '';
  final d = ts.toDate().toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${d.year}-${two(d.month)}-${two(d.day)}  ${two(d.hour)}:${two(d.minute)}';
}

// ==========================================
// 🧾 تبويب سجل النظام (حالياً: استرجاع كلمات مرور المعلمين)
// ==========================================
class SystemLogsTab extends StatelessWidget {
  const SystemLogsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('سجل النظام', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _kGreen)),
          const SizedBox(height: 4),
          const Text(
            'عمليات استرجاع كلمات مرور المعلمين عبر SMS (آخر 100 عملية). التكرار الكثير لنفس المعلم علامة تستحق الانتباه.',
            style: TextStyle(color: Colors.grey, fontSize: 13),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('password_resets')
                  .orderBy('createdAt', descending: true)
                  .limit(100)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('تعذر تحميل السجل: ${snapshot.error}'));
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snapshot.data!.docs;
                if (docs.isEmpty) return const Center(child: Text('لا توجد عمليات استرجاع بعد.'));

                // عدد مرات كل معلم خلال آخر 7 أيام
                final now = DateTime.now();
                final recent = <String, int>{};
                for (final d in docs) {
                  final m = d.data() as Map<String, dynamic>;
                  final ts = m['createdAt'];
                  if (ts is Timestamp && now.difference(ts.toDate()).inDays < 7) {
                    final id = (m['teacherId'] ?? '').toString();
                    recent[id] = (recent[id] ?? 0) + 1;
                  }
                }

                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final m = docs[index].data() as Map<String, dynamic>;
                    final teacherId = (m['teacherId'] ?? '').toString();
                    final times = recent[teacherId] ?? 0;
                    final email = (m['email'] ?? '').toString();

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: _kGreen,
                          child: Icon(Icons.lock_reset, color: Colors.white),
                        ),
                        title: _TeacherLabel(teacherId: teacherId, savedName: (m['teacherName'] ?? '').toString()),
                        subtitle: Text(
                          [if (email.isNotEmpty) email, _fmt(m['createdAt'])].where((e) => e.isNotEmpty).join('   •   '),
                          style: const TextStyle(fontSize: 12),
                        ),
                        trailing: Wrap(
                          spacing: 6,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            if (times >= 3)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(color: Colors.orange, borderRadius: BorderRadius.circular(12)),
                                child: Text('تكرر $times مرات خلال 7 أيام', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                              ),
                            const Chip(label: Text('SMS', style: TextStyle(fontSize: 11)), visualDensity: VisualDensity.compact),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _TeacherLabel extends StatelessWidget {
  final String teacherId;
  final String savedName;
  const _TeacherLabel({required this.teacherId, required this.savedName});

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(fontWeight: FontWeight.bold);
    if (savedName.isNotEmpty) return Text(savedName, style: style);
    // عمليات قديمة بدون اسم محفوظ: بنجيبه من وثيقة المعلم
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(teacherId).get(),
      builder: (context, snap) {
        final data = snap.data?.data() as Map<String, dynamic>?;
        final name = (data?['name'] ?? '').toString();
        return Text(name.isNotEmpty ? name : 'حساب محذوف ($teacherId)', style: style);
      },
    );
  }
}