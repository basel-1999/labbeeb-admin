import 'dart:html' as html;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'admin_api.dart';

// شارة صغيرة ملونة لحالة المعلم
Widget adminStatusBadge(String text, Color color) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)),
    child: Text(
      text,
      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
    ),
  );
}

Future<bool> _confirmAction(
    BuildContext context, {
      required String title,
      required String body,
      required String yes,
      Color yesColor = Colors.red,
    }) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: yesColor)),
      content: Text(body),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('إلغاء', style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: yesColor, foregroundColor: Colors.white),
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(yes),
        ),
      ],
    ),
  );
  return ok == true;
}

Future<void> _callAndNotify(ScaffoldMessengerState messenger, String path) async {
  try {
    final res = await callAdminApi(path);
    messenger.showSnackBar(
      SnackBar(content: Text('✅ ${res['message'] ?? 'تم'}'), backgroundColor: Colors.green),
    );
  } catch (e) {
    messenger.showSnackBar(
      SnackBar(content: Text('❌ ${cleanError(e)}'), backgroundColor: Colors.red),
    );
  }
}

/// قبول تسجيل معلم جديد: بيصير "معلم تجريبي" وبيعمل مقابلته
Future<void> approveTeacherRegistration(BuildContext context, String teacherId, String name) async {
  final messenger = ScaffoldMessenger.of(context);
  final ok = await _confirmAction(
    context,
    title: 'قبول تسجيل المعلم',
    body: 'سيصير "$name" معلماً تجريبياً، ويُفتح له زر مقابلة مدتها 15 دقيقة. '
        'لن يستقبل طلبات طلاب قبل توثيقك له بعد المقابلة.',
    yes: 'قبول التسجيل',
    yesColor: Colors.green,
  );
  if (!ok) return;
  await _callAndNotify(messenger, '/api/admin/teacher/$teacherId/approve-registration');
}

/// حذف المعلم نهائياً: كأنه ما سجّل (حساب الدخول، البيانات، المقابلة، الملفات)
Future<void> deleteTeacherAccount(BuildContext context, String teacherId, String name) async {
  final messenger = ScaffoldMessenger.of(context);
  final ok = await _confirmAction(
    context,
    title: 'حذف المعلم نهائياً',
    body: 'سيتم حذف حساب "$name" نهائياً: حساب الدخول وبياناته ومقابلته وكل ملفاته المرفوعة، وكأنه لم يسجّل. '
        'يستطيع التسجيل من جديد بنفس البريد. لا يمكن التراجع.',
    yes: 'حذف نهائي',
    yesColor: Colors.red,
  );
  if (!ok) return;
  await _callAndNotify(messenger, '/api/admin/teacher/$teacherId/delete');
}

/// توثيق المعلم بعد مراجعة المقابلة
Future<void> certifyTeacher(BuildContext context, String teacherId, String name) async {
  final messenger = ScaffoldMessenger.of(context);
  final ok = await _confirmAction(
    context,
    title: 'توثيق المعلم',
    body: 'هل راجعت فيديو المقابلة؟\nسيصبح "$name" معلماً معتمداً لدى منصة لبيب وتُفتح له كل الخيارات.',
    yes: 'توثيق المعلم',
    yesColor: Colors.green,
  );
  if (!ok) return;
  await _callAndNotify(messenger, '/api/admin/teacher/$teacherId/certify');
}

/// إعادة المقابلة: بيمسح الفيديو وبيرجع المعلم "تجريبي"
Future<void> resetTeacherInterview(BuildContext context, String teacherId, String name) async {
  final messenger = ScaffoldMessenger.of(context);
  final ok = await _confirmAction(
    context,
    title: 'إعادة المقابلة',
    body: 'سيتم حذف فيديو المقابلة الحالي وإعادة "$name" لوضع معلم تجريبي ليُعيد المقابلة من جديد.',
    yes: 'إعادة المقابلة',
    yesColor: Colors.orange.shade800,
  );
  if (!ok) return;
  await _callAndNotify(messenger, '/api/admin/teacher/$teacherId/reset-interview');
}

void openInterviewVideo(BuildContext context, String? url) {
  if (url == null || url.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('لا يوجد فيديو لهذه المقابلة.'), backgroundColor: Colors.orange),
    );
    return;
  }
  html.window.open(url, '_blank');
}

// زر فيه مؤشر انتظار أثناء تنفيذ العملية
class TeacherActionButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final Color color;
  final Future<void> Function() onPressed;

  const TeacherActionButton({
    super.key,
    required this.label,
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  @override
  State<TeacherActionButton> createState() => _TeacherActionButtonState();
}

class _TeacherActionButtonState extends State<TeacherActionButton> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: widget.color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        minimumSize: const Size(0, 32),
        textStyle: const TextStyle(fontSize: 12),
      ),
      icon: _busy
          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
          : Icon(widget.icon, size: 16),
      label: Text(widget.label),
      onPressed: _busy
          ? null
          : () async {
        setState(() => _busy = true);
        try {
          await widget.onPressed();
        } finally {
          if (mounted) setState(() => _busy = false);
        }
      },
    );
  }
}

// الأزرار الأربعة بجانب اسم المعلم الذي أنهى مقابلته
class InterviewActionButtons extends StatelessWidget {
  final String teacherId;
  final String teacherName;
  final String? videoUrl;

  const InterviewActionButtons({
    super.key,
    required this.teacherId,
    required this.teacherName,
    required this.videoUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        TeacherActionButton(
          label: 'عرض الفيديو',
          icon: Icons.play_circle_fill,
          color: Colors.indigo,
          onPressed: () async {
            openInterviewVideo(context, videoUrl);
          },
        ),
        TeacherActionButton(
          label: 'توثيق المعلم',
          icon: Icons.verified,
          color: Colors.green,
          onPressed: () => certifyTeacher(context, teacherId, teacherName),
        ),
        TeacherActionButton(
          label: 'إعادة المقابلة',
          icon: Icons.replay,
          color: Colors.orange.shade800,
          onPressed: () => resetTeacherInterview(context, teacherId, teacherName),
        ),
        TeacherActionButton(
          label: 'حذف المعلم',
          icon: Icons.delete_forever,
          color: Colors.red,
          onPressed: () => deleteTeacherAccount(context, teacherId, teacherName),
        ),
      ],
    );
  }
}

/// تعديل رقم جوال المعلم (الرقم اللي بيوصله رمز استرجاع كلمة المرور)
Future<void> editTeacherPhone(BuildContext context, String teacherId, String currentPhone) async {
  final messenger = ScaffoldMessenger.of(context);
  final ctrl = TextEditingController(text: currentPhone);
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('تعديل رقم جوال المعلم', style: TextStyle(fontWeight: FontWeight.bold)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'هذا الرقم هو اللي بيوصله رمز استرجاع كلمة المرور. اكتبه بالصيغة الدولية الكاملة، مثال: +97455123456',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: ctrl,
            keyboardType: TextInputType.phone,
            textDirection: TextDirection.ltr,
            decoration: const InputDecoration(labelText: 'رقم الجوال', border: OutlineInputBorder()),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('إلغاء', style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('حفظ')),
      ],
    ),
  );
  if (ok != true) return;

  final phone = ctrl.text.trim().replaceAll(RegExp(r'[\s\-()]'), '');
  if (!RegExp(r'^\+[1-9]\d{7,14}$').hasMatch(phone)) {
    messenger.showSnackBar(
      const SnackBar(content: Text('الرقم غير صالح. اكتبه بصيغة دولية تبدأ بـ + (مثال: +97455123456).'), backgroundColor: Colors.orange),
    );
    return;
  }
  try {
    await FirebaseFirestore.instance.collection('users').doc(teacherId).update({'phone': phone});
    messenger.showSnackBar(SnackBar(content: Text('✅ تم تحديث الرقم إلى $phone'), backgroundColor: Colors.green));
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text('❌ فشل التحديث: $e'), backgroundColor: Colors.red));
  }
}