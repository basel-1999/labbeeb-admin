import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'teacher_actions.dart' show adminStatusBadge;

// كل نقطة = 10 دقائق (6 نقاط = ساعة)
String formatPointsAsTime(num points) {
  final totalMinutes = (points * 10).round();
  if (totalMinutes <= 0) return '0 د';
  final h = totalMinutes ~/ 60;
  final m = totalMinutes % 60;
  if (h > 0 && m > 0) return '$h س $m د';
  if (h > 0) return '$h س';
  return '$m د';
}

String _endReasonText(Map<String, dynamic> data) {
  final reason = (data['endReason'] ?? '').toString();
  final by = (data['interruptedBy'] ?? '').toString();
  final parts = <String>[];
  if (reason == 'out_of_points') {
    parts.add('انتهى رصيد الطالب');
  } else if (reason.isNotEmpty) {
    parts.add(reason);
  }
  if (by == 'teacher') {
    parts.add('انقطاع من جهة المعلم');
  } else if (by == 'student') {
    parts.add('انقطاع من جهة الطالب');
  }
  if (data['autoCancelled'] == true) parts.add('أُلغي تلقائياً (لم يقبله معلم)');
  return parts.join(' • ');
}

// ==========================================
// 🗓️ تفاصيل إضافية بكرت الجلسة
// ==========================================
Widget buildSessionExtras(Map<String, dynamic> data) {
  final grade = (data['grade'] ?? '').toString();
  final notes = (data['notes'] ?? '').toString().trim();
  final preferred = (data['preferredTeacherName'] ?? '').toString().trim();
  final endText = _endReasonText(data);
  final deducted = data['pointsDeducted'];
  final isEn = data['language'] == 'en';

  final badges = <Widget>[
    if (data['isFreeTrial'] == true) adminStatusBadge('حصة تجريبية مجانية 🚀', Colors.green),
    adminStatusBadge(isEn ? 'انترناشونال (English)' : 'عربي', isEn ? Colors.indigo : Colors.blueGrey),
    if (preferred.isNotEmpty) adminStatusBadge('معلم مطلوب: $preferred', Colors.deepOrange),
  ];

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Wrap(spacing: 6, runSpacing: 4, children: badges),
      if (grade.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text('المرحلة: $grade', style: const TextStyle(fontSize: 12, color: Colors.black87)),
        ),
      if (deducted is num && deducted > 0)
        Text('النقاط المخصومة: $deducted', style: const TextStyle(fontSize: 12, color: Colors.black87)),
      if (endText.isNotEmpty)
        Text('سبب الانتهاء: $endText', style: const TextStyle(fontSize: 12, color: Colors.red)),
      if (notes.isNotEmpty)
        Container(
          width: double.infinity,
          margin: const EdgeInsets.only(top: 6),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.amber.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.amber.shade200),
          ),
          child: Text('📝 ملاحظات الطالب: $notes', maxLines: 4, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
        ),
    ],
  );
}

// ==========================================
// 🎓 بيانات الطالب بقسم إدارة الحسابات (رصيد، نجوم، حصة تجريبية)
// ==========================================
Future<bool> _confirm(BuildContext context, String title, String body, String yes) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      content: Text(body),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء', style: TextStyle(color: Colors.grey))),
        ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: Text(yes)),
      ],
    ),
  );
  return ok == true;
}

Future<void> _updateStudent(ScaffoldMessengerState messenger, String docId, Map<String, dynamic> update, String okMsg) async {
  try {
    await FirebaseFirestore.instance.collection('users').doc(docId).update(update);
    messenger.showSnackBar(SnackBar(content: Text('✅ $okMsg'), backgroundColor: Colors.green));
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text('❌ فشل التنفيذ: $e'), backgroundColor: Colors.red));
  }
}

Future<void> _editStars(BuildContext context, String docId, int current) async {
  final messenger = ScaffoldMessenger.of(context);
  final ctrl = TextEditingController(text: '$current');
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('تعديل نجوم الطالب', style: TextStyle(fontWeight: FontWeight.bold)),
      content: TextField(
        controller: ctrl,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(labelText: 'عدد النجوم الإجمالي', border: OutlineInputBorder()),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء', style: TextStyle(color: Colors.grey))),
        ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('حفظ')),
      ],
    ),
  );
  final value = int.tryParse(ctrl.text.trim());
  if (ok != true) return;
  if (value == null || value < 0 || value > 9999) {
    messenger.showSnackBar(const SnackBar(content: Text('أدخل رقماً صحيحاً بين 0 و 9999'), backgroundColor: Colors.orange));
    return;
  }
  await _updateStudent(messenger, docId, {'totalStars': value}, 'تم تحديث النجوم إلى $value');
}

Widget buildStudentAdminInfo(BuildContext context, String docId, Map<String, dynamic> data) {
  final num points = data['points'] is num ? data['points'] as num : 0;
  final int stars = data['totalStars'] is num ? (data['totalStars'] as num).toInt() : 0;
  final usedTrial = data['hasUsedFreeTrial'] == true;
  final langText = data['preferredLanguage'] == 'en' ? 'انترناشونال (English)' : 'عربي';
  const style = TextStyle(fontSize: 13);

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('المرحلة الدراسية: ${data['grade'] ?? 'غير محدد'}', style: style),
      Text('لغة الدراسة: $langText', style: style),
      Text('الرصيد: $points نقطة (${formatPointsAsTime(points)})', style: style),
      const SizedBox(height: 6),
      Wrap(
        spacing: 8,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text('⭐ النجوم: $stars  (كؤوس: ${stars ~/ 10} • نجوم الدورة الحالية: ${stars % 10} من 10)', style: style),
          OutlinedButton.icon(
            icon: const Icon(Icons.edit, size: 14),
            label: const Text('تعديل', style: TextStyle(fontSize: 12)),
            onPressed: () => _editStars(context, docId, stars),
          ),
          if (stars > 0)
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
              icon: const Icon(Icons.restart_alt, size: 14),
              label: const Text('تصفير النجوم', style: TextStyle(fontSize: 12)),
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                final ok = await _confirm(context, 'تصفير النجوم', 'سيتم تصفير كل نجوم وكؤوس هذا الطالب. متأكد؟', 'تصفير');
                if (!ok) return;
                await _updateStudent(messenger, docId, {'totalStars': 0}, 'تم تصفير النجوم');
              },
            ),
        ],
      ),
      const SizedBox(height: 6),
      Wrap(
        spacing: 8,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text('الحصة التجريبية المجانية: ${usedTrial ? 'مستخدمة' : 'غير مستخدمة'}', style: style),
          if (usedTrial)
            OutlinedButton.icon(
              icon: const Icon(Icons.refresh, size: 14),
              label: const Text('إعادة تفعيلها', style: TextStyle(fontSize: 12)),
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                final ok = await _confirm(context, 'إعادة الحصة التجريبية', 'سيقدر الطالب يطلب حصة تجريبية مجانية مرة ثانية. متأكد؟', 'إعادة التفعيل');
                if (!ok) return;
                await _updateStudent(messenger, docId, {'hasUsedFreeTrial': false}, 'تمت إعادة تفعيل الحصة التجريبية');
              },
            ),
        ],
      ),
    ],
  );
}