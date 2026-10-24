import 'dart:html' as html;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'admin_api.dart';

const Color _kGreen = Color(0xFF2C3A2B);

String _fmtDate(dynamic ts) {
  if (ts is! Timestamp) return '';
  final d = ts.toDate().toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${d.year}-${two(d.month)}-${two(d.day)}  ${two(d.hour)}:${two(d.minute)}';
}

// ==========================================
// 💰 لوحة طلبات شحن الرصيد (للأدمن وللمسؤول المالي)
// القبول والرفض بيتم عبر السيرفر، مش كتابة مباشرة على Firestore
// ==========================================
class RechargeRequestsPanel extends StatefulWidget {
  const RechargeRequestsPanel({super.key});

  @override
  State<RechargeRequestsPanel> createState() => _RechargeRequestsPanelState();
}

class _RechargeRequestsPanelState extends State<RechargeRequestsPanel> {
  String _filter = 'pending';
  final Set<String> _busy = {};

  Future<void> _approve(String id, String studentName, dynamic points) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تأكيد قبول الشحن', style: TextStyle(fontWeight: FontWeight.bold, color: _kGreen)),
        content: Text('هل تأكدت من وصول المبلغ؟\nسيتم إضافة $points نقطة إلى رصيد الطالب "$studentName".'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('قبول وإضافة النقاط'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _busy.add(id));
    try {
      final res = await callAdminApi('/api/admin/recharge/$id/approve');
      messenger.showSnackBar(
        SnackBar(content: Text('✅ ${res['message'] ?? 'تم القبول'}'), backgroundColor: Colors.green),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('❌ ${cleanError(e)}'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _busy.remove(id));
    }
  }

  Future<void> _reject(String id, String studentName) async {
    final messenger = ScaffoldMessenger.of(context);
    final reasonCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('رفض طلب الشحن', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('سيصل الطالب "$studentName" إشعار برفض الطلب.'),
            const SizedBox(height: 12),
            TextField(
              controller: reasonCtrl,
              maxLength: 300,
              decoration: const InputDecoration(
                labelText: 'سبب الرفض (اختياري)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('تأكيد الرفض'),
          ),
        ],
      ),
    );
    final reason = reasonCtrl.text.trim();
    if (ok != true || !mounted) return;

    setState(() => _busy.add(id));
    try {
      final res = await callAdminApi('/api/admin/recharge/$id/reject', body: {'reason': reason});
      messenger.showSnackBar(
        SnackBar(content: Text('✅ ${res['message'] ?? 'تم الرفض'}'), backgroundColor: Colors.green),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('❌ ${cleanError(e)}'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _busy.remove(id));
    }
  }

  String get _emptyText {
    switch (_filter) {
      case 'approved':
        return 'لا يوجد رصيد معبأ مسبقاً.';
      case 'rejected':
        return 'لا توجد طلبات مرفوضة.';
      default:
        return 'لا توجد طلبات شحن معلقة حالياً.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'طلبات شحن الرصيد (Recharge Requests)',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _kGreen),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            children: [
              FilterChip(label: const Text('معلقة'), selected: _filter == 'pending', onSelected: (_) => setState(() => _filter = 'pending')),
              FilterChip(label: const Text('الرصيد المعبأ'), selected: _filter == 'approved', onSelected: (_) => setState(() => _filter = 'approved')),
              FilterChip(label: const Text('مرفوضة'), selected: _filter == 'rejected', onSelected: (_) => setState(() => _filter = 'rejected')),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('recharge_requests')
                  .where('status', isEqualTo: _filter)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('تعذر تحميل الطلبات: ${snapshot.error}'));
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snapshot.data!.docs.toList();
                if (docs.isEmpty) return Center(child: Text(_emptyText));

                docs.sort((a, b) {
                  final aTime = (a.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
                  final bTime = (b.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
                  if (aTime == null && bTime == null) return 0;
                  if (aTime == null) return 1;
                  if (bTime == null) return -1;
                  return bTime.compareTo(aTime);
                });
                final shown = docs.take(100).toList();

                return ListView.builder(
                  itemCount: shown.length,
                  itemBuilder: (context, index) => _buildCard(shown[index]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final id = doc.id;
    final studentName = (data['studentName'] ?? 'طالب').toString();
    final packageTitle = (data['packageTitle'] ?? 'باقة').toString();
    final pointsCount = data['pointsCount'] ?? 0;
    final referenceNumber = (data['referenceNumber'] ?? 'لا يوجد').toString();
    final receiptImageUrl = (data['receiptImageUrl'] ?? '').toString();
    final method = (data['paymentMethod'] ?? '').toString();
    final created = _fmtDate(data['createdAt']);
    final rejectReason = (data['rejectReason'] ?? '').toString();
    final busy = _busy.contains(id);

    final Widget thumb = receiptImageUrl.isNotEmpty
        ? InkWell(
      onTap: () => html.window.open(receiptImageUrl, '_blank'),
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
          image: DecorationImage(image: NetworkImage(receiptImageUrl), fit: BoxFit.cover),
        ),
        child: const Align(
          alignment: Alignment.bottomRight,
          child: Padding(
            padding: EdgeInsets.all(4.0),
            child: Icon(Icons.open_in_new, size: 16, color: Colors.white),
          ),
        ),
      ),
    )
        : Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(8)),
      child: Icon(method.isNotEmpty ? Icons.credit_card : Icons.receipt_long, color: Colors.grey),
    );

    Widget trailing;
    if (_filter == 'pending') {
      trailing = busy
          ? const SizedBox(width: 30, height: 30, child: CircularProgressIndicator(strokeWidth: 3))
          : Column(
        children: [
          IconButton(
            icon: const Icon(Icons.check_circle, color: Colors.green, size: 30),
            tooltip: 'قبول الشحن وإضافة النقاط للطالب',
            onPressed: () => _approve(id, studentName, pointsCount),
          ),
          IconButton(
            icon: const Icon(Icons.cancel, color: Colors.red, size: 30),
            tooltip: 'رفض الطلب',
            onPressed: () => _reject(id, studentName),
          ),
        ],
      );
    } else if (_filter == 'approved') {
      trailing = const Icon(Icons.check_circle, color: Colors.green, size: 30);
    } else {
      trailing = const Icon(Icons.cancel, color: Colors.red, size: 30);
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            thumb,
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('الطالب: $studentName', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Text('الباقة: $packageTitle ($pointsCount نقطة)'),
                  Text('مرجع التحويل: $referenceNumber', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  if (method.isNotEmpty)
                    Text(
                      'طريقة الدفع: ${method == 'Tap Gateway' ? 'دفع آلي بالبطاقة (Tap)' : method}',
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  if (created.isNotEmpty)
                    Text('التاريخ: $created', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  if (_filter == 'rejected' && rejectReason.isNotEmpty)
                    Text('سبب الرفض: $rejectReason', style: const TextStyle(color: Colors.red, fontSize: 12)),
                ],
              ),
            ),
            trailing,
          ],
        ),
      ),
    );
  }
}

// ==========================================
// 🧾 شاشة المسؤول المالي: طلبات الشحن فقط
// ==========================================
class FinanceDashboardScreen extends StatelessWidget {
  const FinanceDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: _kGreen,
        title: const Text(
          'طلبات شحن الرصيد | لبيب',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(user?.email ?? '', style: const TextStyle(color: Colors.white70, fontSize: 12)),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            tooltip: 'تسجيل الخروج',
            onPressed: () => FirebaseAuth.instance.signOut(),
          ),
        ],
      ),
      body: const RechargeRequestsPanel(),
    );
  }
}