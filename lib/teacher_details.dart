import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

// ===== إعدادات الحسبة (غيّرها من هون فقط) =====
const double kPointsPerHour = 6; // كل ساعة = 6 نقاط
const double kRegularHourRate = 25; // مستحق المعلم عن كل ساعة طالب عادي (عربي)
const double kIntlHourRate = 40; // مستحق المعلم عن كل ساعة طالب انترناشونال
const String kPayCurrency = 'ر.ق';

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
  late Future<List<Map<String, dynamic>>> _future;
  String _period = 'all'; // all | thisMonth | lastMonth

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  // بنجيب كل حصص المعلم، وبنفلتر المنتهية (completed) عندنا بالجهاز
  Future<List<Map<String, dynamic>>> _load() async {
    final snap = await FirebaseFirestore.instance
        .collection('sessions')
        .where('teacherId', isEqualTo: widget.teacherId)
        .get();
    final list = <Map<String, dynamic>>[];
    for (final d in snap.docs) {
      final m = Map<String, dynamic>.from(d.data());
      if (m['status'] == 'completed') {
        m['_id'] = d.id;
        list.add(m);
      }
    }
    return list;
  }

  // ---------- دوال مساعدة ----------
  bool _isTrial(Map<String, dynamic> s) => s['isFreeTrial'] == true;
  bool _isIntl(Map<String, dynamic> s) => (s['language'] ?? 'ar').toString() == 'en';

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

  bool _inPeriod(Map<String, dynamic> s) {
    if (_period == 'all') return true;
    final ts = s['completedAt'];
    if (ts is! Timestamp) return false;
    final d = ts.toDate();
    final now = DateTime.now();
    final startThis = DateTime(now.year, now.month, 1);
    final startLast = DateTime(now.year, now.month - 1, 1);
    if (_period == 'thisMonth') return !d.isBefore(startThis);
    return !d.isBefore(startLast) && d.isBefore(startThis);
  }

  String _two(int n) => n.toString().padLeft(2, '0');

  String _fmtDate(dynamic ts) {
    if (ts is! Timestamp) return '-';
    final d = ts.toDate();
    return '${d.year}-${_two(d.month)}-${_two(d.day)}  ${_two(d.hour)}:${_two(d.minute)}';
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
            onPressed: () => setState(() => _future = _load()),
          ),
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF2C3A2B)));
          }
          if (snap.hasError) {
            return Center(child: Text('تعذر تحميل البيانات: ${snap.error}'));
          }

          final all = snap.data ?? <Map<String, dynamic>>[];
          final sessions = all.where(_inPeriod).toList();

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

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(label: const Text('الكل'), selected: _period == 'all', onSelected: (_) => setState(() => _period = 'all')),
                  ChoiceChip(label: const Text('هذا الشهر'), selected: _period == 'thisMonth', onSelected: (_) => setState(() => _period = 'thisMonth')),
                  ChoiceChip(label: const Text('الشهر الماضي'), selected: _period == 'lastMonth', onSelected: (_) => setState(() => _period = 'lastMonth')),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _statCard(
                    title: 'إجمالي ساعات التدريس (مدفوعة)',
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
                  title: 'إجمالي المستحق للمعلم',
                  main: _fmtMoney(totalDue),
                  sub: 'عادي: ${regHours.toStringAsFixed(2)} ساعة × ${kRegularHourRate.toStringAsFixed(0)} = ${_fmtMoney(regDue)}\n'
                      'انترناشونال: ${intlHours.toStringAsFixed(2)} ساعة × ${kIntlHourRate.toStringAsFixed(0)} = ${_fmtMoney(intlDue)}',
                  color: Colors.green.shade800,
                  wide: true,
                ),
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
                  child: Center(child: Text('لا يوجد حصص منتهية ضمن هذه الفترة', style: TextStyle(color: Colors.grey))),
                ),
              ...shown.map((s) {
                final trial = _isTrial(s);
                final intl = _isIntl(s);
                final pts = _points(s);
                final type = trial ? 'تجريبية' : (intl ? 'انترناشونال' : 'عادي');
                final typeColor = trial ? Colors.blueGrey : (intl ? Colors.blue.shade700 : const Color(0xFF4E6B45));
                final rate = intl ? kIntlHourRate : kRegularHourRate;
                final due = trial ? 0.0 : (pts / kPointsPerHour) * rate;
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: typeColor.withOpacity(0.15),
                      child: Icon(trial ? Icons.hourglass_bottom : Icons.school, color: typeColor, size: 20),
                    ),
                    title: Text('${(s['studentName'] ?? 'طالب').toString()}  •  $type'),
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
            ],
          );
        },
      ),
    );
  }
}