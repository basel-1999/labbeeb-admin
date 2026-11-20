import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

// ===== إعدادات الحسبة (غيّرها من هون فقط) =====
const double kPointsPerHour = 6; // كل ساعة = 6 نقاط
const double kRegularHourRate = 25; // مستحق المعلم عن كل ساعة طالب عادي (عربي)
const double kIntlHourRate = 40; // مستحق المعلم عن كل ساعة طالب انترناشونال
const String kPayCurrency = 'ر.ق';

class _TeacherData {
  final List<Map<String, dynamic>> sessions; // الحصص المنتهية
  final List<Map<String, dynamic>> payments; // سجل الدفعات (الأحدث أولاً)
  final bool paymentsOk; // هل قدرنا نقرأ سجل الدفعات؟
  final String paymentsError;
  _TeacherData(this.sessions, this.payments, this.paymentsOk, this.paymentsError);
}

class TeacherDetailsScreen extends StatefulWidget {
  final String teacherId;
  final String teacherName;
  final bool isSuperAdmin;

  const TeacherDetailsScreen({
    super.key,
    required this.teacherId,
    required this.teacherName,
    required this.isSuperAdmin,
  });

  @override
  State<TeacherDetailsScreen> createState() => _TeacherDetailsScreenState();
}

class _TeacherDetailsScreenState extends State<TeacherDetailsScreen> {
  late Future<_TeacherData> _future;
  late String _period; // unpaid | all | thisMonth | lastMonth | custom
  DateTimeRange? _range;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _period = widget.isSuperAdmin ? 'unpaid' : 'all';
    _future = _load();
  }

  // ---------- تحميل البيانات ----------
  Future<List<Map<String, dynamic>>> _fetchPayments() async {
    final snap = await FirebaseFirestore.instance
        .collection('teacher_payments')
        .where('teacherId', isEqualTo: widget.teacherId)
        .get();
    final list = <Map<String, dynamic>>[];
    for (final d in snap.docs) {
      final m = Map<String, dynamic>.from(d.data());
      m['_id'] = d.id;
      list.add(m);
    }
    list.sort((a, b) {
      final x = a['paidAt'];
      final y = b['paidAt'];
      if (x is Timestamp && y is Timestamp) return y.compareTo(x);
      return 0;
    });
    return list;
  }

  Future<_TeacherData> _load() async {
    final snap = await FirebaseFirestore.instance
        .collection('sessions')
        .where('teacherId', isEqualTo: widget.teacherId)
        .get();
    final sessions = <Map<String, dynamic>>[];
    for (final d in snap.docs) {
      final m = Map<String, dynamic>.from(d.data());
      if (m['status'] == 'completed') {
        m['_id'] = d.id;
        sessions.add(m);
      }
    }

    var payments = <Map<String, dynamic>>[];
    var ok = true;
    var err = '';
    if (widget.isSuperAdmin) {
      try {
        payments = await _fetchPayments();
      } catch (e) {
        ok = false;
        err = e.toString();
      }
    }
    return _TeacherData(sessions, payments, ok, err);
  }

  void _reload() {
    setState(() {
      _future = _load();
    });
  }

  // ---------- دوال مساعدة ----------
  bool _isTrial(Map<String, dynamic> s) => s['isFreeTrial'] == true;
  bool _isIntl(Map<String, dynamic> s) => (s['language'] ?? 'ar').toString() == 'en';
  double _num(dynamic v) => v is num ? v.toDouble() : 0.0;

  int _durationMinutes(Map<String, dynamic> s) {
    final a = s['timerStartedAt'];
    final b = s['completedAt'];
    if (a is Timestamp && b is Timestamp) {
      final secs = b.toDate().difference(a.toDate()).inSeconds;
      if (secs <= 0) return 0;
      return (secs ~/ 300) * 5; // فترات مكتملة كل 5 دقائق (نفس حسبة الخصم)
    }
    return 0;
  }

  // النقاط اللي انخصمت من الطالب فعلاً؛ وللحصص القديمة بدون الحقل منحسبها من المدة
  double _points(Map<String, dynamic> s) {
    if (_isTrial(s)) return 0;
    final v = s['pointsDeducted'];
    if (v is num) return v.toDouble();
    return (_durationMinutes(s) / 5) * 0.5;
  }

  Set<String> _paidIds(List<Map<String, dynamic>> payments) {
    final ids = <String>{};
    for (final p in payments) {
      if (p['voided'] == true) continue;
      final l = p['sessionIds'];
      if (l is List) {
        for (final x in l) {
          ids.add(x.toString());
        }
      }
    }
    return ids;
  }

  bool _inView(Map<String, dynamic> s, Set<String> paid) {
    final id = (s['_id'] ?? '').toString();
    if (_period == 'unpaid') return !paid.contains(id);
    if (_period == 'all') return true;
    final ts = s['completedAt'];
    if (ts is! Timestamp) return false;
    final d = ts.toDate();
    final now = DateTime.now();
    final startThis = DateTime(now.year, now.month, 1);
    if (_period == 'thisMonth') return !d.isBefore(startThis);
    if (_period == 'lastMonth') {
      final startLast = DateTime(now.year, now.month - 1, 1);
      return !d.isBefore(startLast) && d.isBefore(startThis);
    }
    if (_period == 'custom') {
      final r = _range;
      if (r == null) return true;
      final start = DateTime(r.start.year, r.start.month, r.start.day);
      final end = DateTime(r.end.year, r.end.month, r.end.day).add(const Duration(days: 1));
      return !d.isBefore(start) && d.isBefore(end);
    }
    return true;
  }

  String _two(int n) => n.toString().padLeft(2, '0');
  String _fmtDay(DateTime d) => '${d.year}-${_two(d.month)}-${_two(d.day)}';

  String _fmtDate(dynamic ts) {
    if (ts is! Timestamp) return '-';
    final d = ts.toDate();
    return '${_fmtDay(d)}  ${_two(d.hour)}:${_two(d.minute)}';
  }

  // نقاط -> "س د" (كل نقطة = 10 دقائق)
  String _fmtHM(double points) {
    final totalMins = (points / kPointsPerHour * 60).round();
    final h = totalMins ~/ 60;
    final m = totalMins % 60;
    if (h > 0 && m > 0) return '$h س $m د';
    if (h > 0) return '$h س';
    return '$m د';
  }

  String _fmtPoints(double p) => p == p.roundToDouble() ? p.toInt().toString() : p.toStringAsFixed(1);
  String _fmtMoney(double v) => '${v.toStringAsFixed(2)} $kPayCurrency';

  void _toast(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024, 1, 1),
      lastDate: DateTime(now.year, now.month, now.day).add(const Duration(days: 1)),
      initialDateRange: _range,
      helpText: 'اختر الفترة (من - إلى)',
      saveText: 'تطبيق',
    );
    if (picked != null) {
      setState(() {
        _range = picked;
        _period = 'custom';
      });
    }
  }

  // ---------- تسجيل دفعة ----------
  Future<void> _recordPayment({
    required List<Map<String, dynamic>> unpaid,
    required double regPoints,
    required double intlPoints,
    required double totalDue,
  }) async {
    final noteC = TextEditingController();
    final regH = regPoints / kPointsPerHour;
    final intlH = intlPoints / kPointsPerHour;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تأكيد تسجيل دفعة'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('المعلم: ${widget.teacherName}', style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('عدد الحصص: ${unpaid.length}'),
              Text('عادي: ${regH.toStringAsFixed(2)} ساعة × ${kRegularHourRate.toStringAsFixed(0)}'),
              Text('انترناشونال: ${intlH.toStringAsFixed(2)} ساعة × ${kIntlHourRate.toStringAsFixed(0)}'),
              const SizedBox(height: 8),
              Text('المبلغ: ${_fmtMoney(totalDue)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
              const SizedBox(height: 12),
              const Text(
                'بعد التأكيد بتنحسب هالحصص مدفوعة، ويبدأ العدّ من جديد للحصص الجاية.',
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: noteC,
                decoration: const InputDecoration(labelText: 'ملاحظة (اختياري) — بيشوفها المعلم بصفحته', border: OutlineInputBorder()),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2C3A2B), foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('تأكيد الدفع'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() {
      _saving = true;
    });
    try {
      // تحقق أخير: ما يكون في دفعة جديدة غطّت نفس الحصص
      final fresh = await _fetchPayments();
      final paidNow = _paidIds(fresh);
      final ids = <String>[];
      for (final s in unpaid) {
        final id = (s['_id'] ?? '').toString();
        if (id.isNotEmpty) ids.add(id);
      }
      if (ids.any((id) => paidNow.contains(id))) {
        _toast('تم تسجيل دفعة لهذا المعلم قبل قليل. حدّث الصفحة وراجع الأرقام.', Colors.orange);
        _reload();
        return;
      }

      Timestamp? coveredUntil;
      for (final s in unpaid) {
        final t = s['completedAt'];
        if (t is Timestamp) {
          final cu = coveredUntil;
          if (cu == null || t.compareTo(cu) > 0) coveredUntil = t;
        }
      }

      final user = FirebaseAuth.instance.currentUser;
      await FirebaseFirestore.instance.collection('teacher_payments').add({
        'teacherId': widget.teacherId,
        'teacherName': widget.teacherName,
        'paidAt': FieldValue.serverTimestamp(),
        'paidBy': user?.uid,
        'sessionIds': ids,
        'sessionsCount': ids.length,
        'regularPoints': regPoints,
        'intlPoints': intlPoints,
        'regularHours': double.parse(regH.toStringAsFixed(4)),
        'intlHours': double.parse(intlH.toStringAsFixed(4)),
        'regularRate': kRegularHourRate,
        'intlRate': kIntlHourRate,
        'currency': kPayCurrency,
        'amount': double.parse(totalDue.toStringAsFixed(2)),
        'coveredUntil': coveredUntil,
        'note': noteC.text.trim(),
        'voided': false,
      });
      _toast('تم تسجيل الدفعة', Colors.green);
      _reload();
    } catch (e) {
      _toast('فشل تسجيل الدفعة: $e', Colors.red);
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  Future<void> _voidPayment(Map<String, dynamic> p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إلغاء الدفعة؟'),
        content: const Text('بترجع الحصص التابعة لهذه الدفعة "غير مدفوعة" وبتنحسب من جديد بالمستحقات. الدفعة نفسها بتضل ظاهرة بالسجل كـ "ملغاة".'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('رجوع')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('نعم، إلغاء الدفعة'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await FirebaseFirestore.instance.collection('teacher_payments').doc(p['_id'].toString()).update({
        'voided': true,
        'voidedAt': FieldValue.serverTimestamp(),
        'voidedBy': FirebaseAuth.instance.currentUser?.uid,
      });
      _toast('تم إلغاء الدفعة', Colors.green);
      _reload();
    } catch (e) {
      _toast('فشل الإلغاء: $e', Colors.red);
    }
  }

  // ---------- واجهة ----------
  Widget _statCard({
    required String title,
    required String main,
    required String sub,
    required Color color,
    bool wide = false,
  }) {
    return Container(
      width: wide ? double.infinity : 260,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black54)),
          const SizedBox(height: 6),
          Text(main, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: color)),
          if (sub.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(sub, style: const TextStyle(fontSize: 12, color: Colors.black54)),
          ],
        ],
      ),
    );
  }

  Widget _banner(String text, Color color) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(text, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4EFE6),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2C3A2B),
        foregroundColor: Colors.white,
        title: Text('تفاصيل المعلم: ${widget.teacherName}'),
        actions: [
          IconButton(
            tooltip: 'تحديث',
            icon: const Icon(Icons.refresh),
            onPressed: _reload,
          ),
        ],
      ),
      body: FutureBuilder<_TeacherData>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF2C3A2B)));
          }
          if (snap.hasError) {
            return Center(child: Text('تعذر تحميل البيانات: ${snap.error}'));
          }
          final data = snap.data;
          if (data == null) return const SizedBox();

          final paid = _paidIds(data.payments);
          final sessions = data.sessions.where((s) => _inView(s, paid)).toList();
          final isUnpaidView = _period == 'unpaid';

          double regPoints = 0;
          double intlPoints = 0;
          int trialCount = 0;
          int trialMins = 0;
          for (final s in sessions) {
            if (_isTrial(s)) {
              trialCount++;
              trialMins += _durationMinutes(s);
            } else if (_isIntl(s)) {
              intlPoints += _points(s);
            } else {
              regPoints += _points(s);
            }
          }
          final totalPoints = regPoints + intlPoints;
          final regHours = regPoints / kPointsPerHour;
          final intlHours = intlPoints / kPointsPerHour;
          final regDue = regHours * kRegularHourRate;
          final intlDue = intlHours * kIntlHourRate;
          final totalDue = regDue + intlDue;

          // أحدث الحصص أولاً
          sessions.sort((a, b) {
            final x = a['completedAt'];
            final y = b['completedAt'];
            if (x is Timestamp && y is Timestamp) return y.compareTo(x);
            return 0;
          });
          final shown = sessions.take(100).toList();

          // آخر دفعة غير ملغاة
          final lastPayment = data.payments.firstWhere(
                (p) => p['voided'] != true,
            orElse: () => <String, dynamic>{},
          );

          final canPay = widget.isSuperAdmin && isUnpaidView && data.paymentsOk && totalPoints > 0;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (widget.isSuperAdmin && !data.paymentsOk)
                _banner(
                  'تعذر قراءة سجل الدفعات (تأكد من نشر قواعد Firestore الجديدة). تسجيل الدفعات متوقف لحد ما تنحل المشكلة.\n${data.paymentsError}',
                  Colors.red,
                ),
              if (widget.isSuperAdmin && isUnpaidView && data.paymentsOk)
                _banner(
                  lastPayment.isEmpty
                      ? 'ما في دفعات مسجّلة لهذا المعلم بعد، فالأرقام تحت هي كل حصصه المنتهية.'
                      : 'آخر دفعة: ${_fmtDate(lastPayment['paidAt'])}  •  ${_fmtMoney(_num(lastPayment['amount']))}. الأرقام تحت هي بعدها فقط.',
                  const Color(0xFF2C3A2B),
                ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (widget.isSuperAdmin)
                    ChoiceChip(
                      label: const Text('غير المدفوع'),
                      selected: _period == 'unpaid',
                      onSelected: (_) => setState(() {
                        _period = 'unpaid';
                      }),
                    ),
                  ChoiceChip(
                    label: const Text('الكل'),
                    selected: _period == 'all',
                    onSelected: (_) => setState(() {
                      _period = 'all';
                    }),
                  ),
                  ChoiceChip(
                    label: const Text('هذا الشهر'),
                    selected: _period == 'thisMonth',
                    onSelected: (_) => setState(() {
                      _period = 'thisMonth';
                    }),
                  ),
                  ChoiceChip(
                    label: const Text('الشهر الماضي'),
                    selected: _period == 'lastMonth',
                    onSelected: (_) => setState(() {
                      _period = 'lastMonth';
                    }),
                  ),
                  ChoiceChip(
                    avatar: const Icon(Icons.date_range, size: 16),
                    label: Text(
                      (_period == 'custom' && _range != null)
                          ? 'من ${_fmtDay(_range!.start)} إلى ${_fmtDay(_range!.end)}'
                          : 'من - إلى',
                    ),
                    selected: _period == 'custom',
                    onSelected: (_) => _pickRange(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _statCard(
                    title: 'إجمالي ساعات التدريس (مدفوعة الثمن)',
                    main: _fmtHM(totalPoints),
                    sub: '${(totalPoints / kPointsPerHour).toStringAsFixed(2)} ساعة  •  ${sessions.length - trialCount} حصة',
                    color: const Color(0xFF2C3A2B),
                  ),
                  _statCard(
                    title: 'طلاب عاديين (عرب)',
                    main: _fmtHM(regPoints),
                    sub: '${_fmtPoints(regPoints)} نقطة'
                        '${widget.isSuperAdmin ? '  •  ${_fmtMoney(regDue)}' : ''}',
                    color: const Color(0xFF4E6B45),
                  ),
                  _statCard(
                    title: 'طلاب انترناشونال',
                    main: _fmtHM(intlPoints),
                    sub: '${_fmtPoints(intlPoints)} نقطة'
                        '${widget.isSuperAdmin ? '  •  ${_fmtMoney(intlDue)}' : ''}',
                    color: Colors.blue.shade700,
                  ),
                  _statCard(
                    title: 'النقاط المحصّلة من الطلاب',
                    main: _fmtPoints(totalPoints),
                    sub: 'كل ${kPointsPerHour.toInt()} نقاط = ساعة',
                    color: const Color(0xFFD97706),
                  ),
                  _statCard(
                    title: 'حصص تجريبية (غير مشمولة بالحساب)',
                    main: '$trialCount حصة',
                    sub: 'مدتها $trialMins دقيقة',
                    color: Colors.blueGrey,
                  ),
                ],
              ),
              if (widget.isSuperAdmin) ...[
                const SizedBox(height: 16),
                _statCard(
                  title: isUnpaidView ? 'المستحق للمعلم حالياً (غير مدفوع)' : 'قيمة الحصص ضمن الفترة المحددة (مدفوعة وغير مدفوعة)',
                  main: _fmtMoney(totalDue),
                  sub: 'عادي: ${regHours.toStringAsFixed(2)} ساعة × ${kRegularHourRate.toStringAsFixed(0)} = ${_fmtMoney(regDue)}\n'
                      'انترناشونال: ${intlHours.toStringAsFixed(2)} ساعة × ${kIntlHourRate.toStringAsFixed(0)} = ${_fmtMoney(intlDue)}',
                  color: Colors.green.shade800,
                  wide: true,
                ),
                if (isUnpaidView) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade800, foregroundColor: Colors.white),
                      icon: const Icon(Icons.payments),
                      label: Text(_saving ? 'جاري الحفظ...' : 'تسجيل دفعة للمعلم (${_fmtMoney(totalDue)})'),
                      onPressed: (canPay && !_saving)
                          ? () => _recordPayment(
                        unpaid: sessions,
                        regPoints: regPoints,
                        intlPoints: intlPoints,
                        totalDue: totalDue,
                      )
                          : null,
                    ),
                  ),
                ],
              ],
              const SizedBox(height: 24),
              Text(
                'سجل الحصص${sessions.length > 100 ? ' (أحدث 100 من ${sessions.length})' : ' (${sessions.length})'}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              if (shown.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: Text('لا يوجد حصص ضمن هذه الفترة', style: TextStyle(color: Colors.grey))),
                ),
              ...shown.map((s) {
                final trial = _isTrial(s);
                final intl = _isIntl(s);
                final pts = _points(s);
                final type = trial ? 'تجريبية' : (intl ? 'انترناشونال' : 'عادي');
                final typeColor = trial ? Colors.blueGrey : (intl ? Colors.blue.shade700 : const Color(0xFF4E6B45));
                final rate = intl ? kIntlHourRate : kRegularHourRate;
                final due = trial ? 0.0 : (pts / kPointsPerHour) * rate;
                final isPaid = widget.isSuperAdmin && paid.contains((s['_id'] ?? '').toString());
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: typeColor.withOpacity(0.15),
                      child: Icon(trial ? Icons.hourglass_bottom : Icons.school, color: typeColor, size: 20),
                    ),
                    title: Text('${(s['studentName'] ?? 'طالب').toString()}  •  $type${isPaid ? '  •  مدفوعة ✓' : ''}'),
                    subtitle: Text('${_fmtDate(s['completedAt'])}  •  ${_durationMinutes(s)} دقيقة'),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('${_fmtPoints(pts)} نقطة', style: const TextStyle(fontWeight: FontWeight.bold)),
                        if (widget.isSuperAdmin && !trial)
                          Text(_fmtMoney(due), style: TextStyle(fontSize: 12, color: Colors.green.shade800)),
                      ],
                    ),
                  ),
                );
              }),
              if (widget.isSuperAdmin && data.paymentsOk) ...[
                const SizedBox(height: 28),
                Text(
                  'سجل الدفعات (${data.payments.length})',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                if (data.payments.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: Text('ما في دفعات مسجّلة بعد', style: TextStyle(color: Colors.grey))),
                  ),
                ...data.payments.map((p) {
                  final voided = p['voided'] == true;
                  final note = (p['note'] ?? '').toString();
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    color: voided ? Colors.grey.shade200 : Colors.white,
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: (voided ? Colors.grey : Colors.green.shade800).withOpacity(0.15),
                        child: Icon(voided ? Icons.block : Icons.payments, color: voided ? Colors.grey : Colors.green.shade800, size: 20),
                      ),
                      title: Text(
                        '${_fmtMoney(_num(p['amount']))}  •  ${_fmtDate(p['paidAt'])}${voided ? '  •  ملغاة' : ''}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          decoration: voided ? TextDecoration.lineThrough : TextDecoration.none,
                        ),
                      ),
                      subtitle: Text(
                        'عادي ${_num(p['regularHours']).toStringAsFixed(2)} س  •  انترناشونال ${_num(p['intlHours']).toStringAsFixed(2)} س  •  ${(p['sessionsCount'] ?? 0)} حصة'
                            '${note.isEmpty ? '' : '\nملاحظة: $note'}',
                      ),
                      isThreeLine: note.isNotEmpty,
                      trailing: voided
                          ? null
                          : TextButton(
                        onPressed: _saving ? null : () => _voidPayment(p),
                        child: const Text('إلغاء', style: TextStyle(color: Colors.red)),
                      ),
                    ),
                  );
                }),
              ],
            ],
          );
        },
      ),
    );
  }
}