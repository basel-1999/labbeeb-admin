import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'teacher_actions.dart';
import 'session_details.dart';
import 'system_logs.dart';
import 'recharge_panel.dart';

// رسالة بتظهر بشاشة الدخول (مثلاً: الحساب ما إله صلاحية)
final ValueNotifier<String?> adminLoginNotice = ValueNotifier<String?>(null);

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const LabibAdminApp());
}

final GoRouter _router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const AdminAuthWrapper(),
    ),
  ],
);

class LabibAdminApp extends StatelessWidget {
  const LabibAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'لوحة تحكم المدير | منصة لبيب',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'Cairo',
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF9F6EE),
      ),
      routerConfig: _router,
    );
  }
}

// 🔐 ويدجت للتحقق من حالة تسجيل دخول المدير تلقائياً
class AdminAuthWrapper extends StatefulWidget {
  const AdminAuthWrapper({super.key});

  @override
  State<AdminAuthWrapper> createState() => _AdminAuthWrapperState();
}

class _AdminAuthWrapperState extends State<AdminAuthWrapper> {
  bool _isFirebaseInitialized = false;

  @override
  void initState() {
    super.initState();
    _initFirebase();
  }

  Future<void> _initFirebase() async {
    try {
      await Firebase.initializeApp(
        options: const FirebaseOptions(
          apiKey: "AIzaSyAO-ziORrLtFb5bgS_byXNzLyDB5VIeLLI",
          authDomain: "labeeb-app-2026.firebaseapp.com",
          projectId: "labeeb-app-2026",
          storageBucket: "labeeb-app-2026.firebasestorage.app",
          messagingSenderId: "201953565667",
          appId: "1:201953565667:web:4cee64be63f85e19a99ed6",
        ),
      );
      if (mounted) {
        setState(() {
          _isFirebaseInitialized = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isFirebaseInitialized = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isFirebaseInitialized) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Color(0xFF2C3A2B)),
              SizedBox(height: 16),
              Text('جاري الاتصال بخوادم الفايربيز...', style: TextStyle(fontFamily: 'Cairo')),
            ],
          ),
        ),
      );
    }
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        if (snapshot.hasData && snapshot.data != null) {
          return RoleGate(key: ValueKey(snapshot.data!.uid), user: snapshot.data!);
        }

        return const AdminLoginScreen();
      },
    );
  }
}

// 🚦 بعد تسجيل الدخول: بنقرأ دور المستخدم ونوجّهه (أدمن أو مسؤول مالي)، وغيرهم بنطلّعهم
class RoleGate extends StatefulWidget {
  final User user;
  const RoleGate({super.key, required this.user});

  @override
  State<RoleGate> createState() => _RoleGateState();
}

class _RoleGateState extends State<RoleGate> {
  late final Future<String?> _roleFuture = _loadRole();

  Future<String?> _loadRole() async {
    final doc = await FirebaseFirestore.instance.collection('users').doc(widget.user.uid).get();
    final data = doc.data();
    return data == null ? null : data['role'] as String?;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: _roleFuture,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator(color: Color(0xFF2C3A2B))),
          );
        }
        if (snap.hasError) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('تعذر التحقق من صلاحياتك: ${snap.error}'),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () => FirebaseAuth.instance.signOut(),
                    child: const Text('تسجيل الخروج'),
                  ),
                ],
              ),
            ),
          );
        }

        final role = snap.data;
        if (role == 'admin') return const AdminDashboardScreen();
        if (role == 'finance') return const FinanceDashboardScreen();

        // دور غير مسموح: تسجيل خروج مع رسالة بشاشة الدخول
        WidgetsBinding.instance.addPostFrameCallback((_) {
          adminLoginNotice.value = 'عذراً، هذا الحساب لا يملك صلاحية دخول لوحة الإدارة.';
          FirebaseAuth.instance.signOut();
        });
        return const Scaffold(
          body: Center(child: CircularProgressIndicator(color: Color(0xFF2C3A2B))),
        );
      },
    );
  }
}

// 🔑 شاشة تسجيل دخول الإدارة (الأدمن والمسؤول المالي)
class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscure = true;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String _authErrorText(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'صيغة البريد الإلكتروني غير صحيحة.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'البريد الإلكتروني أو كلمة المرور غير صحيحة.';
      case 'user-disabled':
        return 'تم تعطيل هذا الحساب.';
      case 'too-many-requests':
        return 'محاولات كثيرة. انتظر قليلاً ثم حاول مرة أخرى.';
      case 'network-request-failed':
        return 'تعذر الاتصال بالإنترنت.';
      default:
        return 'فشل تسجيل الدخول (${e.code}).';
    }
  }

  Future<void> _loginAdmin() async {
    if (_isLoading) return;
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = 'يرجى إدخال البريد الإلكتروني وكلمة المرور.');
      return;
    }

    adminLoginNotice.value = null;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(email: email, password: password);
      // التحقق من الدور (أدمن أو مسؤول مالي) بيصير بـ RoleGate
    } on FirebaseAuthException catch (e) {
      if (mounted) setState(() => _errorMessage = _authErrorText(e));
    } catch (e) {
      if (mounted) setState(() => _errorMessage = 'حدث خطأ غير متوقع: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF2C3A2B),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Container(
            width: 420,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 12)],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.admin_panel_settings, size: 64, color: Color(0xFF2C3A2B)),
                const SizedBox(height: 12),
                const Text(
                  'لوحة الإدارة | لبيب',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF2C3A2B)),
                ),
                const Text('تسجيل الدخول للإدارة والمسؤول المالي', style: TextStyle(color: Colors.grey, fontSize: 13)),
                const SizedBox(height: 24),
                ValueListenableBuilder<String?>(
                  valueListenable: adminLoginNotice,
                  builder: (context, notice, _) {
                    if (notice == null) return const SizedBox.shrink();
                    return Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(8)),
                      child: Text(notice, style: TextStyle(color: Colors.orange.shade900, fontSize: 12)),
                    );
                  },
                ),
                if (_errorMessage != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)),
                    child: Text(_errorMessage!, style: const TextStyle(color: Colors.red, fontSize: 12)),
                  ),
                  const SizedBox(height: 16),
                ],
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'البريد الإلكتروني',
                    prefixIcon: Icon(Icons.email),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _passwordController,
                  obscureText: _obscure,
                  onSubmitted: (_) => _loginAdmin(),
                  decoration: InputDecoration(
                    labelText: 'كلمة المرور',
                    prefixIcon: const Icon(Icons.lock),
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                      tooltip: _obscure ? 'إظهار كلمة المرور' : 'إخفاء كلمة المرور',
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2C3A2B),
                      foregroundColor: Colors.white,
                    ),
                    onPressed: _isLoading ? null : _loginAdmin,
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('تسجيل الدخول', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// 🖥️ شاشة لوحة التحكم الرئيسية بعد تسجيل الدخول
class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _userFilter = 'all'; // فلتر الحسابات
  String _sessionFilter = 'pending'; // فلتر الجلسات (4 أقسام)
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this); // 6 تبويبات
  }

  void _logoutAdmin() async {
    await FirebaseAuth.instance.signOut();
  }

  // 🚀 دالة مراقبة الحصة
  Future<void> _monitorSession(String sessionId) async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('جاري فتح غرفة المراقبة في تبويب جديد...')),
    );

    try {
      final sessionRef = FirebaseFirestore.instance.collection('sessions').doc(sessionId);
      await sessionRef.update({
        'adminJoinedAt': FieldValue.serverTimestamp(),
      });

      final roomUrl = 'https://labbeeb-wep.onrender.com/live-session?sessionId=$sessionId&role=admin';
      html.window.open(roomUrl, '_blank');

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ أثناء محاولة مراقبة الحصة: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // 1. إضافة أو تعديل مستخدم
  void _showUserFormDialog({String? docId, Map<String, dynamic>? initialData}) {
    final nameController = TextEditingController(text: initialData?['name'] ?? '');
    final phoneController = TextEditingController(text: initialData?['phone'] ?? '');
    final infoController = TextEditingController(
      text: initialData != null
          ? (initialData['role'] == 'teacher'
          ? (initialData['subjects'] as List<dynamic>?)?.join(', ') ?? ''
          : initialData['grade'] ?? '')
          : '',
    );
    String selectedRole = initialData?['role'] ?? 'student';
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(
                docId == null ? 'إضافة مستخدم جديد' : 'تعديل بيانات المستخدم',
                style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2C3A2B)),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: 'الاسم الكامل', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: phoneController,
                      decoration: const InputDecoration(labelText: 'رقم الهاتف', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: selectedRole,
                      decoration: const InputDecoration(labelText: 'الدور (User Role)', border: OutlineInputBorder()),
                      items: const [
                        DropdownMenuItem(value: 'student', child: Text('طالب (Student)')),
                        DropdownMenuItem(value: 'teacher', child: Text('معلم (Teacher)')),
                        DropdownMenuItem(value: 'admin', child: Text('مدير (Admin)')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() {
                            selectedRole = val;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: infoController,
                      decoration: InputDecoration(
                        labelText: selectedRole == 'teacher'
                            ? 'التخصصات (افصل بينها بفاصلة)'
                            : (selectedRole == 'student' ? 'المرحلة الدراسية' : 'الوصف الوظيفي'),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    if (selectedRole == 'teacher' && initialData != null) ...[
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 8),
                      const Text('🎓 الشهادات والمستندات الأكاديمية:', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2C3A2B))),
                      const SizedBox(height: 8),
                      Builder(
                        builder: (context) {
                          final List<dynamic> certs = initialData['certificates'] ?? [];
                          final String certName = initialData['certificateName'] ?? 'شهادة المعلم المرفقة';

                          if (certs.isEmpty) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 4.0),
                              child: Text('لم يقم المعلم برفع شهادة أكاديمية بعد.', style: TextStyle(color: Colors.grey, fontSize: 13)),
                            );
                          }

                          return Column(
                            children: certs.map((cert) {
                              String title = certName;
                              String fullUrl = '';

                              if (cert is Map<String, dynamic>) {
                                title = cert['title'] ?? certName;
                                fullUrl = cert['fileUrl'] ?? cert['url'] ?? '';
                              } else if (cert is String) {
                                fullUrl = cert;
                              }
                              final bool isUrl = fullUrl.startsWith('http://') || fullUrl.startsWith('https://');

                              return Container(
                                margin: const EdgeInsets.only(bottom: 6),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  border: Border.all(color: Colors.grey.shade300),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: ListTile(
                                  dense: true,
                                  leading: Icon(isUrl ? Icons.picture_as_pdf : Icons.verified, color: isUrl ? Colors.redAccent : Colors.green),
                                  title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                  subtitle: Text(fullUrl, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, color: isUrl ? Colors.blue : Colors.grey)),
                                  trailing: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2C3A2B), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4)),
                                    icon: const Icon(Icons.open_in_new, size: 12),
                                    label: const Text('معاينة', style: TextStyle(fontSize: 11)),
                                    onPressed: () {
                                      if (isUrl) {
                                        html.window.open(fullUrl, '_blank');
                                      } else {
                                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('الشهادة متوفرة ومحفوظة بنجاح: $title')));
                                      }
                                    },
                                  ),
                                ),
                              );
                            }).toList(),
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      const Text('🪪 الهوية الشخصية أو جواز السفر:', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2C3A2B))),
                      const SizedBox(height: 8),
                      Builder(
                        builder: (context) {
                          final String idUrl = initialData['identityUrl'] ?? '';
                          final String idFileName = initialData['identityFileName'] ?? 'ملف الهوية أو جواز السفر';

                          if (idUrl.isEmpty) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 4.0),
                              child: Text('لم يقم المعلم برفع الهوية الشخصية بعد.', style: TextStyle(color: Colors.grey, fontSize: 13)),
                            );
                          }

                          final bool isIdUrl = idUrl.startsWith('http://') || idUrl.startsWith('https://');

                          return Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: ListTile(
                              dense: true,
                              leading: const Icon(Icons.badge_rounded, color: Colors.indigo),
                              title: Text(idFileName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                              subtitle: Text(idUrl, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: Colors.blue)),
                              trailing: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4)),
                                icon: const Icon(Icons.open_in_new, size: 12),
                                label: const Text('معاينة الهوية', style: TextStyle(fontSize: 11)),
                                onPressed: () {
                                  if (isIdUrl) html.window.open(idUrl, '_blank');
                                },
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      const Text('🏅 أقوى شهادة خبرة:', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2C3A2B))),
                      const SizedBox(height: 8),
                      Builder(
                        builder: (context) {
                          final String expUrl = initialData['experienceCertificateUrl'] ?? '';
                          final String expFileName = initialData['experienceCertificateName'] ?? 'شهادة الخبرة المرفقة';

                          if (expUrl.isEmpty) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 4.0),
                              child: Text('لم يقم المعلم برفع شهادة خبرة بعد.', style: TextStyle(color: Colors.grey, fontSize: 13)),
                            );
                          }

                          final bool isExpUrl = expUrl.startsWith('http://') || expUrl.startsWith('https://');

                          return Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: ListTile(
                              dense: true,
                              leading: const Icon(Icons.workspace_premium, color: Colors.amber),
                              title: Text(expFileName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                              subtitle: Text(expUrl, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: Colors.blue)),
                              trailing: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.amber.shade800, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4)),
                                icon: const Icon(Icons.open_in_new, size: 12),
                                label: const Text('معاينة شهادة الخبرة', style: TextStyle(fontSize: 11)),
                                onPressed: () {
                                  if (isExpUrl) html.window.open(expUrl, '_blank');
                                },
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      const Text('🧑‍🏫 شهادة الدرجة العلمية العليا (إن وجدت):', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2C3A2B))),
                      const SizedBox(height: 8),
                      Builder(
                        builder: (context) {
                          final String advDegUrl = initialData['advancedDegreeCertificateUrl'] ?? '';

                          if (advDegUrl.isEmpty) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 4.0),
                              child: Text('لا توجد شهادة درجة عليا مرفقة.', style: TextStyle(color: Colors.grey, fontSize: 13)),
                            );
                          }

                          final bool isAdvDegUrl = advDegUrl.startsWith('http://') || advDegUrl.startsWith('https://');

                          return Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: ListTile(
                              dense: true,
                              leading: const Icon(Icons.school, color: Colors.purple),
                              title: const Text('شهادة (الماجستير/الدكتوراه)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                              subtitle: Text(advDegUrl, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: Colors.blue)),
                              trailing: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.purple, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4)),
                                icon: const Icon(Icons.open_in_new, size: 12),
                                label: const Text('معاينة الشهادة', style: TextStyle(fontSize: 11)),
                                onPressed: () {
                                  if (isAdvDegUrl) html.window.open(advDegUrl, '_blank');
                                },
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('إلغاء', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2C3A2B), foregroundColor: Colors.white),
                  onPressed: () async {
                    if (nameController.text.trim().isEmpty) return;

                    final userData = <String, dynamic>{
                      'name': nameController.text.trim(),
                      'phone': phoneController.text.trim(),
                      'role': selectedRole,
                      'updatedAt': FieldValue.serverTimestamp(),
                    };

                    if (selectedRole == 'teacher') {
                      userData['subjects'] = infoController.text.split(',').map((e) => e.trim()).toList();
                    } else if (selectedRole == 'student') {
                      userData['grade'] = infoController.text.trim();
                    }

                    if (docId == null) {
                      // مستخدم جديد: الحالة بتنحط عند الإنشاء فقط
                      userData['status'] = selectedRole == 'student' ? 'active' : 'approved';
                      userData['accountStatus'] = 'approved';
                      if (selectedRole == 'teacher') userData['isAvailable'] = true;
                      userData['createdAt'] = FieldValue.serverTimestamp();
                      await FirebaseFirestore.instance.collection('users').add(userData);
                    } else {
                      // تعديل: ما منلمس الحالة (عشان ما يتخطى المعلم المقابلة)
                      await FirebaseFirestore.instance.collection('users').doc(docId).update(userData);
                    }

                    if (mounted) Navigator.pop(context);
                  },
                  child: Text(docId == null ? 'حفظ في Firestore' : 'تحديث البيانات'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // 2. إنشاء طلب/جلسة جديدة
  void _showAddSessionDialog() {
    final studentNameController = TextEditingController();
    final studentPhoneController = TextEditingController();
    final subjectController = TextEditingController();
    final timeController = TextEditingController(text: 'اليوم - 05:00 مساءً');

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('إنشاء طلب حصة جديد', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2C3A2B))),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: studentNameController,
                  decoration: const InputDecoration(labelText: 'اسم الطالب', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: studentPhoneController,
                  decoration: const InputDecoration(labelText: 'رقم هاتف الطالب (إجباري)', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: subjectController,
                  decoration: const InputDecoration(labelText: 'المادة المطلوبة', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: timeController,
                  decoration: const InputDecoration(labelText: 'الوقت المحدد', border: OutlineInputBorder()),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2C3A2B), foregroundColor: Colors.white),
              onPressed: () async {
                if (studentNameController.text.trim().isEmpty || subjectController.text.trim().isEmpty || studentPhoneController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('يرجى إدخال اسم الطالب ورقم هاتفه والمادة.')),
                  );
                  return;
                }

                String studentId = 'ADMIN_CREATED_NO_UID';
                try {
                  final studentQuery = await FirebaseFirestore.instance
                      .collection('users')
                      .where('phone', isEqualTo: studentPhoneController.text.trim())
                      .where('role', isEqualTo: 'student')
                      .limit(1)
                      .get();

                  if (studentQuery.docs.isEmpty) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('❌ خطأ: رقم الهاتف لا ينتمي لطالب مسجل في المنصة. يرجى التأكد من الرقم.'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                    return;
                  }
                  studentId = studentQuery.docs.first.id;
                } catch(e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('حدث خطأ أثناء البحث عن الطالب: $e'), backgroundColor: Colors.red),
                    );
                  }
                  return;
                }

                final sessionData = {
                  'studentId': studentId,
                  'studentName': studentNameController.text.trim(),
                  'subject': subjectController.text.trim(),
                  'scheduledTime': timeController.text.trim(),
                  'status': 'pending',
                  'teacherId': null,
                  'assignedTeacherId': null,
                  'assignedTeacherName': 'في انتظار قبول معلم...',
                  'attachedFiles': [],
                  'audioRecordingUrl': null,
                  'createdAt': FieldValue.serverTimestamp(),
                };

                await FirebaseFirestore.instance.collection('sessions').add(sessionData);
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('تم إنشاء الطلب بنجاح وإرساله للنظام.'), backgroundColor: Colors.green),
                  );
                }
              },
              child: const Text('إرسال الطلب للنظام'),
            )
          ],
        );
      },
    );
  }

  // 3. إعادة إسناد الجلسة يدوياً
  void _showReassignTeacherDialog(String sessionId) {
    final phoneController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('إسناد يدوي لمعلم (برقم الجوال)', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2C3A2B))),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('أدخل رقم جوال المعلم المراد إسناد الحصة إليه لتجنب أخطاء كتابة الأسماء:', style: TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 12),
              TextField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'رقم جوال المعلم',
                  prefixIcon: Icon(Icons.phone),
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE07A5F), foregroundColor: Colors.white),
              onPressed: () async {
                final phone = phoneController.text.trim();
                if (phone.isEmpty) return;

                Navigator.pop(context);

                try {
                  final querySnapshot = await FirebaseFirestore.instance
                      .collection('users')
                      .where('phone', isEqualTo: phone)
                      .where('role', isEqualTo: 'teacher')
                      .limit(1)
                      .get();

                  if (querySnapshot.docs.isEmpty) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('❌ لم يتم العثور على معلم مسجل بهذا الرقم أو أن الدور ليس معلماً!'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                    return;
                  }

                  final teacherDoc = querySnapshot.docs.first;
                  final teacherData = teacherDoc.data();
                  final teacherName = teacherData['name'] ?? 'معلم بدون اسم';
                  final teacherId = teacherDoc.id;

                  await FirebaseFirestore.instance.collection('sessions').doc(sessionId).update({
                    'teacherId': teacherId,
                    'teacherName': teacherName,
                    'assignedTeacherId': teacherId,
                    'assignedTeacherName': teacherName,
                    'instructorName': teacherName,
                    'status': 'accepted',
                  });

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('✅ تم إسناد الحصة بنجاح إلى المعلم: $teacherName'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('❌ حدث خطأ أثناء البحث عن المعلم: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              child: const Text('بحث وإسناد'),
            )
          ],
        );
      },
    );
  }

  // 4. نافذة تفاصيل الملفات والتسجيلات
  void _showSessionDetailsDialog(String sessionId, Map<String, dynamic> sessionData) {
    final fileUrlController = TextEditingController();
    final fileNameController = TextEditingController();
    final audioUrlController = TextEditingController(text: sessionData['audioRecordingUrl'] ?? '');

    showDialog(
      context: context,
      builder: (context) {
        final List<dynamic> files = sessionData['attachedFiles'] ?? [];

        return AlertDialog(
          title: Text('ملفات وتسجيلات حصة ${sessionData['subject']}', style: const TextStyle(fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('📁 الملفات والملخصات المرفقة:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                if (files.isEmpty) const Text('لا توجد ملفات مرفقة بعد.', style: TextStyle(color: Colors.grey)),
                ...files.map((f) => ListTile(
                  dense: true,
                  leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
                  title: Text(f['fileName'] ?? 'ملف'),
                  subtitle: Text(f['fileUrl'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis),
                )),
                const Divider(),
                const Text('إضافة رابط ملف جديد (من Storage):', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                TextField(
                  controller: fileNameController,
                  decoration: const InputDecoration(labelText: 'اسم الملف/الملخص', isDense: true, border: OutlineInputBorder()),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: fileUrlController,
                  decoration: const InputDecoration(labelText: 'رابط الملف (Storage URL)', isDense: true, border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2C3A2B), foregroundColor: Colors.white),
                  icon: const Icon(Icons.upload_file, size: 16),
                  label: const Text('إرفاق الملف بالحصة'),
                  onPressed: () async {
                    if (fileNameController.text.isNotEmpty && fileUrlController.text.isNotEmpty) {
                      final newFile = {
                        'fileName': fileNameController.text.trim(),
                        'fileUrl': fileUrlController.text.trim(),
                        'uploadedAt': DateTime.now().toIso8601String(),
                      };
                      await FirebaseFirestore.instance.collection('sessions').doc(sessionId).update({
                        'attachedFiles': FieldValue.arrayUnion([newFile])
                      });
                      if (mounted) Navigator.pop(context);
                    }
                  },
                ),
                const SizedBox(height: 16),
                const Divider(),
                const Text('🎙️ تسجيل الصوت المرفوع بعد الحصة:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                TextField(
                  controller: audioUrlController,
                  decoration: const InputDecoration(labelText: 'رابط التسجيل الصوتي (Cloud Storage)', isDense: true, border: OutlineInputBorder()),
                ),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey, foregroundColor: Colors.white),
                  icon: const Icon(Icons.mic, size: 16),
                  label: const Text('حفظ رابط التسجيل الصوتي'),
                  onPressed: () async {
                    if (audioUrlController.text.isNotEmpty) {
                      await FirebaseFirestore.instance.collection('sessions').doc(sessionId).update({
                        'audioRecordingUrl': audioUrlController.text.trim(),
                        'status': 'completed',
                      });
                      if (mounted) Navigator.pop(context);
                    }
                  },
                )
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إغلاق'),
            )
          ],
        );
      },
    );
  }

  // 5. تأكيد الحذف النهائي
  void _confirmDelete({required String docId, required String collection, required String title}) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('تأكيد الحذف النهائي', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          content: Text('هل أنت متأكد من حذف "$title" نهائياً من قاعدة البيانات؟'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
              onPressed: () async {
                await FirebaseFirestore.instance.collection(collection).doc(docId).delete();
                if (mounted) Navigator.pop(context);
              },
              child: const Text('تأكيد الحذف'),
            ),
          ],
        );
      },
    );
  }

  // 6. إلغاء الطلب (يغير الحالة ويرجع الرصيد للطالب)
  Future<void> _cancelSession(String sessionId, String? studentId) async {
    try {
      await FirebaseFirestore.instance.collection('sessions').doc(sessionId).update({
        'status': 'cancelled',
        'cancelledAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ تم إلغاء الجلسة'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل الإلغاء: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF2C3A2B),
        title: Row(
          children: [
            const Text('لوحة تحكم المدير (Admin Control Panel) | لبيب', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: Colors.green, borderRadius: BorderRadius.circular(12)),
              child: Text('أدمن مسجل: ${user?.email ?? ""}', style: const TextStyle(color: Colors.white, fontSize: 11)),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            tooltip: 'تسجيل الخروج',
            onPressed: _logoutAdmin,
          )
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFFE07A5F),
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          isScrollable: false,
          tabs: [
            // تبويب 1: مراقبة الجودة
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('sessions').where('status', whereIn: ['accepted', 'active', 'in_progress']).snapshots(),
              builder: (context, snapshot) {
                int count = snapshot.data?.docs.where((d) => (d.data() as Map<String, dynamic>)['isTrialInterview'] != true).length ?? 0;
                return Tab(
                  icon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.analytics),
                      if (count > 0)
                        Container(
                          padding: const EdgeInsets.all(4),
                          margin: const EdgeInsets.only(left: 4),
                          decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                          child: Text('$count', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
                    ],
                  ),
                  text: 'مراقبة الجودة Live',
                );
              },
            ),
            // تبويب 2: إدارة الحسابات
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('users').where('status', whereIn: ['pending_approval', 'pending_profile_update', 'interviewed']).snapshots(),
              builder: (context, snapshot) {
                int count = snapshot.data?.docs.length ?? 0;
                return Tab(
                  icon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.people),
                      if (count > 0)
                        Container(
                          padding: const EdgeInsets.all(4),
                          margin: const EdgeInsets.only(left: 4),
                          decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                          child: Text('$count', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
                    ],
                  ),
                  text: 'إدارة الحسابات',
                );
              },
            ),
            // تبويب 3: الجلسات
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('sessions').where('status', isEqualTo: 'pending').snapshots(),
              builder: (context, snapshot) {
                int count = snapshot.data?.docs.length ?? 0;
                return Tab(
                  icon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.event_note),
                      if (count > 0)
                        Container(
                          padding: const EdgeInsets.all(4),
                          margin: const EdgeInsets.only(left: 4),
                          decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                          child: Text('$count', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
                    ],
                  ),
                  text: 'طلبات الأسبقية والجلسات',
                );
              },
            ),
            // تبويب 4: شحن الرصيد
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('recharge_requests').where('status', isEqualTo: 'pending').snapshots(),
              builder: (context, snapshot) {
                int count = snapshot.data?.docs.length ?? 0;
                return Tab(
                  icon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.account_balance_wallet),
                      if (count > 0)
                        Container(
                          padding: const EdgeInsets.all(4),
                          margin: const EdgeInsets.only(left: 4),
                          decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                          child: Text('$count', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
                    ],
                  ),
                  text: 'طلبات شحن الرصيد',
                );
              },
            ),
            // تبويب 5: الدعم الفني
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('support_chats').snapshots(),
              builder: (context, snapshot) {
                int unreadCount = 0;
                if (snapshot.hasData) {
                  for (var doc in snapshot.data!.docs) {
                    final data = doc.data() as Map<String, dynamic>?;
                    if (data != null && data['unreadByAdminCount'] != null) {
                      unreadCount += (data['unreadByAdminCount'] as num).toInt();
                    }
                  }
                }
                return Tab(
                  icon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.support_agent),
                      if (unreadCount > 0)
                        Container(
                          padding: const EdgeInsets.all(4),
                          margin: const EdgeInsets.only(left: 4),
                          decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                          child: Text('$unreadCount', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
                    ],
                  ),
                  text: 'الدعم الفني',
                );
              },
            ),
            // تبويب 6: سجل النظام
            const Tab(icon: Icon(Icons.history), text: 'سجل النظام'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildQualityAndStatsTab(),
          _buildUserManagementTab(),
          _buildSessionManagementTab(),
          const RechargeRequestsPanel(),
          const AdminSupportTab(),
          const SystemLogsTab(),
        ],
      ),
    );
  }

  // 1. تبويب مراقبة الجودة والإحصائيات (تم الإصلاح: فلترة الحصص الشغالة فقط)
  Widget _buildQualityAndStatsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').snapshots(),
      builder: (context, usersSnapshot) {
        final usersDocs = usersSnapshot.data?.docs ?? [];
        final teachersCount = usersDocs.where((d) => (d.data() as Map<String, dynamic>)['role'] == 'teacher').length;
        final studentsCount = usersDocs.where((d) => (d.data() as Map<String, dynamic>)['role'] == 'student').length;

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('sessions').snapshots(),
          builder: (context, sessionsSnapshot) {
            final allSessionDocs = sessionsSnapshot.data?.docs ?? [];

            // ✨ فلترة الجلسات الشغالة فعلياً فقط (التي بدأ العداد فيها) لعرضها في هذا القسم
            final liveSessionDocs = allSessionDocs.where((d) {
              final data = d.data() as Map<String, dynamic>;
              final status = data['status'] ?? 'pending';
              final timerStartedAt = data['timerStartedAt'] as Timestamp?;

              if (data['isTrialInterview'] == true) return false; // مقابلات المعلمين ما بتنعرض هون
              bool isCurrentlyLive = false;
              if ((status == 'active' || status == 'in_progress' || status == 'accepted') && timerStartedAt != null) {
                // ✨ التحقق من أن العداد بدأ ولم تمضِ عليه أكثر من 65 دقيقة
                final startMs = timerStartedAt.toDate().millisecondsSinceEpoch;
                final nowMs = DateTime.now().millisecondsSinceEpoch;
                final diffMins = (nowMs - startMs) / 60000;
                isCurrentlyLive = diffMins <= 65;
              }
              return isCurrentlyLive;
            }).toList();

            final pendingRequests = allSessionDocs.where((d) => (d.data() as Map<String, dynamic>)['status'] == 'pending').length;
            final activeSessions = liveSessionDocs.length;

            return Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('مؤشرات الأداء المباشرة (Firestore Live Monitor)', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF2C3A2B))),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _buildStatCard('طلبات الأسبقية المتاحة', '$pendingRequests طلب', const Color(0xFFE07A5F), Icons.add_alert),
                      const SizedBox(width: 16),
                      _buildStatCard('الحصص المقبولة/الجارية', '$activeSessions حصة', Colors.green, Icons.live_tv),
                      const SizedBox(width: 16),
                      _buildStatCard('إجمالي المعلمين', '$teachersCount معلم', const Color(0xFF2C3A2B), Icons.person_pin),
                      const SizedBox(width: 16),
                      _buildStatCard('إجمالي الطلاب', '$studentsCount طالب', Colors.blueGrey, Icons.school),
                    ],
                  ),
                  const SizedBox(height: 32),
                  const Text('الحصص الجارية والطلبات المباشرة', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2C3A2B))),
                  const SizedBox(height: 12),
                  Expanded(
                    child: liveSessionDocs.isEmpty
                        ? const Center(child: Text('لا توجد حصص جارية حالياً.'))
                        : ListView.builder(
                      itemCount: liveSessionDocs.length,
                      itemBuilder: (context, index) {
                        final data = liveSessionDocs[index].data() as Map<String, dynamic>;
                        final docId = liveSessionDocs[index].id;
                        final status = data['status'] ?? 'pending';

                        return Card(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.green,
                              child: const Icon(Icons.video_call, color: Colors.white),
                            ),
                            title: Text('مادة: ${data['subject']} - الطالب: ${data['studentName']}'),
                            subtitle: Text('المعلم: ${data['teacherName'] ?? data['assignedTeacherName'] ?? "لم يقبل بعد"} | الحالة: $status'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                                  icon: const Icon(Icons.visibility, size: 16),
                                  label: const Text('مراقبة الحصة'),
                                  onPressed: () => _monitorSession(docId),
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: const Icon(Icons.cancel, color: Colors.red),
                                  tooltip: 'إلغاء الطلب (إرجاع الرصيد)',
                                  onPressed: () => _cancelSession(docId, data['studentId']),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  )
                ],
              ),
            );
          },
        );
      },
    );
  }

  // 2. إدارة المستخدمين والأدوار (تم الإصلاح: إظهار الشهادة دائماً بجانب الهوية)
  // 2. إدارة المستخدمين والأدوار (تم الإصلاح: تقسيم المعلمين لثلاثة أقسام مع شارات التنبيه)
  // 2. إدارة المستخدمين والأدوار (تم التحديث: بحث + أقسام اللغة والشهادات)
  Widget _buildUserManagementTab() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('إدارة المستخدمين والأدوار (Users Collection)', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF2C3A2B))),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2C3A2B), foregroundColor: Colors.white),
                icon: const Icon(Icons.person_add),
                label: const Text('إضافة مستخدم جديد'),
                onPressed: () => _showUserFormDialog(),
              )
            ],
          ),
          const SizedBox(height: 16),
          // ✨ حقل البحث الجديد
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              labelText: 'بحث بالاسم، رقم الهاتف، أو التخصص...',
              prefixIcon: const Icon(Icons.search, color: Color(0xFF2C3A2B)),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  _searchController.clear();
                  setState(() => _searchQuery = '');
                },
              )
                  : null,
            ),
            onChanged: (value) {
              setState(() {
                _searchQuery = value.trim().toLowerCase();
              });
            },
          ),
          const SizedBox(height: 16),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('users').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('حدث خطأ أثناء جلب البيانات: ${snapshot.error}'));
                }

                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                int updatesCount = 0;
                int pendingTeachersCount = 0;
                int interviewedCount = 0;

                for (var doc in snapshot.data!.docs) {
                  final data = doc.data() as Map<String, dynamic>;
                  if (data['status'] == 'pending_profile_update') {
                    updatesCount++;
                  } else if (data['role'] == 'teacher' && (data['status'] == 'pending_approval' || data['status'] == 'pending_review')) {
                    pendingTeachersCount++;
                  } else if (data['role'] == 'teacher' && data['status'] == 'interviewed') {
                    interviewedCount++;
                  }
                }

                return Column(
                  children: [
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        FilterChip(label: const Text('الكل'), selected: _userFilter == 'all', onSelected: (v) => setState(() => _userFilter = 'all')),
                        FilterChip(label: const Text('طلاب'), selected: _userFilter == 'students', onSelected: (v) => setState(() => _userFilter = 'students')),
                        FilterChip(label: const Text('معلمون عرب'), selected: _userFilter == 'teachers_ar', onSelected: (v) => setState(() => _userFilter = 'teachers_ar')),
                        FilterChip(label: const Text('معلمون انترناشونال'), selected: _userFilter == 'teachers_en', onSelected: (v) => setState(() => _userFilter = 'teachers_en')),
                        FilterChip(label: const Text('معلمون (كلاهما)'), selected: _userFilter == 'teachers_both', onSelected: (v) => setState(() => _userFilter = 'teachers_both')),
                        FilterChip(label: const Text('معلمون شهادات عليا'), selected: _userFilter == 'teachers_adv', onSelected: (v) => setState(() => _userFilter = 'teachers_adv')),
                        Badge(
                          label: Text('$pendingTeachersCount', style: const TextStyle(color: Colors.white, fontSize: 10)),
                          isLabelVisible: pendingTeachersCount > 0,
                          backgroundColor: Colors.red,
                          child: FilterChip(
                            label: const Text('معلمين قيد المراجعة'),
                            selected: _userFilter == 'teachers_pending',
                            onSelected: (v) => setState(() => _userFilter = 'teachers_pending'),
                          ),
                        ),
                        FilterChip(
                          label: const Text('معلمون تجريبيون (بانتظار المقابلة)'),
                          selected: _userFilter == 'teachers_trial',
                          onSelected: (v) => setState(() => _userFilter = 'teachers_trial'),
                        ),
                        Badge(
                          label: Text('$interviewedCount', style: const TextStyle(color: Colors.white, fontSize: 10)),
                          isLabelVisible: interviewedCount > 0,
                          backgroundColor: Colors.teal,
                          child: FilterChip(
                            label: const Text('معلمون تمت مقابلتهم'),
                            selected: _userFilter == 'teachers_interviewed',
                            onSelected: (v) => setState(() => _userFilter = 'teachers_interviewed'),
                          ),
                        ),
                        Badge(
                          label: Text('$updatesCount', style: const TextStyle(color: Colors.white, fontSize: 10)),
                          isLabelVisible: updatesCount > 0,
                          backgroundColor: Colors.purple,
                          child: FilterChip(
                            label: const Text('طلبات تعديل المعلمين'),
                            selected: _userFilter == 'teachers_updates',
                            onSelected: (v) => setState(() => _userFilter = 'teachers_updates'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: Builder(
                        builder: (context) {
                          if (snapshot.data!.docs.isEmpty) {
                            return const Center(child: Text('لا يوجد مستخدمون حالياً في قاعدة البيانات.'));
                          }

                          var docs = snapshot.data!.docs.where((doc) {
                            final data = doc.data() as Map<String, dynamic>;
                            final role = data['role'] ?? 'student';
                            final status = data['status'] ?? 'approved';
                            final teachingLang = data['teachingLanguage'] ?? 'العربية';
                            final academicDeg = data['academicDegree'] ?? 'لا أملك';
                            final isApprovedTeacher = role == 'teacher' && status == 'approved';
                            final hasAdvDegree = academicDeg == 'ماجستير' || academicDeg == 'دكتوراه';

                            // 1. فلترة البحث
                            if (_searchQuery.isNotEmpty) {
                              final name = (data['name'] ?? '').toString().toLowerCase();
                              final phone = (data['phone'] ?? '').toString().toLowerCase();
                              final subjectsList = data['subjects'] as List<dynamic>? ?? [];
                              final subjects = subjectsList.map((e) => e.toString().toLowerCase()).join(' ');

                              if (!name.contains(_searchQuery) &&
                                  !phone.contains(_searchQuery) &&
                                  !subjects.contains(_searchQuery)) {
                                return false;
                              }
                            }

                            // 2. فلترة الأقسام
                            if (_userFilter == 'all') return true;
                            if (_userFilter == 'students') return role == 'student';
                            if (_userFilter == 'teachers_ar') return isApprovedTeacher && teachingLang == 'العربية';
                            if (_userFilter == 'teachers_en') return isApprovedTeacher && teachingLang == 'الإنجليزية (انترناشونال)';
                            if (_userFilter == 'teachers_both') return isApprovedTeacher && teachingLang == 'كلاهما';
                            if (_userFilter == 'teachers_adv') return isApprovedTeacher && hasAdvDegree;
                            if (_userFilter == 'teachers_pending') return role == 'teacher' && (status == 'pending_approval' || status == 'pending_review');
                            if (_userFilter == 'teachers_trial') return role == 'teacher' && status == 'trial';
                            if (_userFilter == 'teachers_interviewed') return role == 'teacher' && status == 'interviewed';
                            if (_userFilter == 'teachers_updates') return status == 'pending_profile_update';

                            return false;
                          }).toList();

                          docs.sort((a, b) {
                            final aData = a.data() as Map<String, dynamic>;
                            final bData = b.data() as Map<String, dynamic>;
                            final aTime = aData['createdAt'] as Timestamp?;
                            final bTime = bData['createdAt'] as Timestamp?;
                            if (aTime == null && bTime == null) return 0;
                            if (aTime == null) return 1;
                            if (bTime == null) return -1;
                            return bTime.compareTo(aTime);
                          });

                          if (docs.isEmpty) {
                            return const Center(child: Text('لا توجد نتائج مطابقة للبحث أو القسم المختار.'));
                          }

                          return ListView.builder(
                            itemCount: docs.length,
                            itemBuilder: (context, index) {
                              final data = docs[index].data() as Map<String, dynamic>;
                              final docId = docs[index].id;
                              final role = data['role'] ?? 'student';
                              final status = data['status'] ?? data['accountStatus'] ?? 'approved';
                              final isPendingTeacher = role == 'teacher' &&
                                  (status == 'pending_approval' || status == 'pending' || status == 'pending_review');
                              final isTrialTeacher = role == 'teacher' && status == 'trial';
                              final isInterviewedTeacher = role == 'teacher' && status == 'interviewed';

                              final pendingUpdates = data['pendingProfileUpdates'] as Map<String, dynamic>?;
                              final isPendingUpdate = status == 'pending_profile_update' && pendingUpdates != null;

                              String? certUrl = data['certificateUrl'];
                              if (certUrl == null && data['certificates'] != null && (data['certificates'] as List).isNotEmpty) {
                                var cert = (data['certificates'] as List).first;
                                if (cert is Map) {
                                  certUrl = cert['fileUrl'] ?? cert['url'];
                                } else if (cert is String) {
                                  certUrl = cert;
                                }
                              }

                              return Card(
                                color: isPendingUpdate
                                    ? Colors.purple.shade50
                                    : (isPendingTeacher
                                    ? Colors.orange.shade50
                                    : (isInterviewedTeacher ? Colors.teal.shade50 : Colors.white)),
                                margin: const EdgeInsets.only(bottom: 12),
                                child: ExpansionTile(
                                  leading: CircleAvatar(
                                    backgroundColor: role == 'teacher'
                                        ? const Color(0xFF2C3A2B)
                                        : (role == 'admin' ? Colors.purple : const Color(0xFFE07A5F)),
                                    child: Text(role.isNotEmpty ? role[0].toUpperCase() : 'U', style: const TextStyle(color: Colors.white)),
                                  ),
                                  title: Wrap(
                                    spacing: 8,
                                    runSpacing: 6,
                                    crossAxisAlignment: WrapCrossAlignment.center,
                                    children: [
                                      Text('${data['name'] ?? 'مستخدم جديد'} (الدور: $role)'),
                                      if (isPendingTeacher) adminStatusBadge('طلب انضمام معلم معلق ⏳', Colors.orange),
                                      if (isPendingUpdate) adminStatusBadge('طلب تعديل بيانات ⏳', Colors.purple),
                                      if (isTrialTeacher) adminStatusBadge('معلم تجريبي: بانتظار المقابلة', Colors.blueGrey),
                                      if (role == 'teacher' && status == 'approved') adminStatusBadge('معلم معتمد ✅', Colors.green),
                                      if (isInterviewedTeacher) ...[
                                        adminStatusBadge('تمت المقابلة: بانتظار قرارك', Colors.teal),
                                        InterviewActionButtons(
                                          teacherId: docId,
                                          teacherName: (data['name'] ?? 'المعلم').toString(),
                                          videoUrl: data['interviewVideoUrl']?.toString(),
                                        ),
                                      ],
                                    ],
                                  ),
                                  subtitle: Wrap(
                                    spacing: 12,
                                    crossAxisAlignment: WrapCrossAlignment.center,
                                    children: [
                                      Text('الهاتف: ${data['phone'] ?? 'غير محدد'}'),
                                      if ((data['email'] ?? '').toString().isNotEmpty) Text('البريد: ${data['email']}'),
                                      if (role == 'teacher')
                                        TextButton.icon(
                                          style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 24)),
                                          icon: const Icon(Icons.edit, size: 14),
                                          label: const Text('تعديل الرقم', style: TextStyle(fontSize: 12)),
                                          onPressed: () => editTeacherPhone(context, docId, (data['phone'] ?? '').toString()),
                                        ),
                                    ],
                                  ),
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.all(16.0),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          if (isPendingUpdate) ...[
                                            Container(
                                              padding: const EdgeInsets.all(12),
                                              margin: const EdgeInsets.only(bottom: 12),
                                              decoration: BoxDecoration(color: Colors.purple.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.purple.shade200)),
                                              child: const Row(
                                                children: [
                                                  Icon(Icons.system_update, color: Colors.purple, size: 18),
                                                  SizedBox(width: 8),
                                                  Expanded(child: Text('هذا المعلم طلب تحديث بياناته. راجع البيانات بالأسفل.', style: TextStyle(color: Colors.purple, fontWeight: FontWeight.bold, fontSize: 13))),
                                                ],
                                              ),
                                            ),
                                          ],
                                          if (role == 'teacher') ...[
                                            if (isPendingUpdate) ...[
                                              Text('الاسم الجديد المطلوب: ${pendingUpdates!['name'] ?? data['name']}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                                              Text('الدولة/المدينة: ${pendingUpdates['country'] ?? data['country']} - ${pendingUpdates['city'] ?? data['city']}', style: const TextStyle(fontSize: 13)),
                                              Text('التخصصات الجديدة: ${pendingUpdates['subjects'] != null ? (pendingUpdates['subjects'] as List).join('، ') : 'لم يتغير'}', style: const TextStyle(fontSize: 13)),
                                              Text('الفئات العمرية: ${pendingUpdates['targetAge'] != null ? (pendingUpdates['targetAge'] as List).join('، ') : 'لم يتغير'}', style: const TextStyle(fontSize: 13)),
                                              Text('لغة التدريس: ${pendingUpdates['teachingLanguage'] ?? data['teachingLanguage']}', style: const TextStyle(fontSize: 13)),
                                              Text('الدرجة العلمية: ${pendingUpdates['academicDegree'] ?? data['academicDegree']}', style: const TextStyle(fontSize: 13)),
                                              const SizedBox(height: 8),
                                              const Text('الوثائق الجديدة المرفقة (إن وجدت):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                              if (pendingUpdates['certificateUrl'] != null)
                                                ListTile(
                                                  leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
                                                  title: const Text('عرض الشهادة الجامعية الجديدة', style: TextStyle(fontSize: 13)),
                                                  trailing: const Icon(Icons.open_in_new, size: 16),
                                                  onTap: () => html.window.open(pendingUpdates['certificateUrl'], '_blank'),
                                                ),
                                              if (pendingUpdates['identityUrl'] != null)
                                                ListTile(
                                                  leading: const Icon(Icons.badge, color: Colors.indigo),
                                                  title: const Text('عرض الهوية الجديدة', style: TextStyle(fontSize: 13)),
                                                  trailing: const Icon(Icons.open_in_new, size: 16),
                                                  onTap: () => html.window.open(pendingUpdates['identityUrl'], '_blank'),
                                                ),
                                              if (pendingUpdates['advancedDegreeCertificateUrl'] != null)
                                                ListTile(
                                                  leading: const Icon(Icons.school, color: Colors.purple),
                                                  title: const Text('عرض شهادة الماجستير/الدكتوراه الجديدة', style: TextStyle(fontSize: 13)),
                                                  trailing: const Icon(Icons.open_in_new, size: 16),
                                                  onTap: () => html.window.open(pendingUpdates['advancedDegreeCertificateUrl'], '_blank'),
                                                ),
                                            ] else ...[
                                              Text('التخصصات: ${data['subjects']?.join(', ') ?? 'غير محدد'}', style: const TextStyle(fontSize: 13)),
                                              Text('الفئات العمرية: ${data['targetAge']?.join(', ') ?? 'غير محدد'}', style: const TextStyle(fontSize: 13)),
                                              Text('لغة التدريس: ${data['teachingLanguage'] ?? 'غير محدد'}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                                              Text('الأجهزة المتاحة: ${data['ownedDevices'] != null ? (data['ownedDevices'] as List).join('، ') : 'غير محدد'}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                                              Text('الدرجة العلمية العليا: ${data['academicDegree'] ?? 'لا يوجد'}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                                              const SizedBox(height: 8),
                                              if (certUrl != null)
                                                ListTile(
                                                  leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
                                                  title: const Text('عرض الشهادة الجامعية'),
                                                  trailing: const Icon(Icons.open_in_new),
                                                  onTap: () => html.window.open(certUrl!, '_blank'),
                                                ),
                                              if (data['identityUrl'] != null)
                                                ListTile(
                                                  leading: const Icon(Icons.badge, color: Colors.indigo),
                                                  title: const Text('عرض الهوية الشخصية'),
                                                  trailing: const Icon(Icons.open_in_new),
                                                  onTap: () => html.window.open(data['identityUrl'], '_blank'),
                                                ),
                                              if (data['experienceCertificateUrl'] != null)
                                                ListTile(
                                                  leading: const Icon(Icons.workspace_premium, color: Colors.amber),
                                                  title: const Text('عرض شهادة الخبرة'),
                                                  trailing: const Icon(Icons.open_in_new),
                                                  onTap: () => html.window.open(data['experienceCertificateUrl'], '_blank'),
                                                ),
                                              if (data['advancedDegreeCertificateUrl'] != null)
                                                ListTile(
                                                  leading: const Icon(Icons.school, color: Colors.purple),
                                                  title: const Text('عرض شهادة الدرجة العلمية العليا'),
                                                  trailing: const Icon(Icons.open_in_new),
                                                  onTap: () => html.window.open(data['advancedDegreeCertificateUrl'], '_blank'),
                                                ),
                                            ],
                                          ] else if (role == 'student') ...[
                                            buildStudentAdminInfo(context, docId, data),
                                          ],
                                          const SizedBox(height: 12),
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.end,
                                            children: [
                                              if (isPendingUpdate) ...[
                                                ElevatedButton.icon(
                                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                                                  icon: const Icon(Icons.check, size: 16),
                                                  label: const Text('قبول التعديلات'),
                                                  onPressed: () async {
                                                    await FirebaseFirestore.instance.collection('users').doc(docId).update({
                                                      'name': pendingUpdates!['name'] ?? data['name'],
                                                      'country': pendingUpdates['country'] ?? data['country'],
                                                      'city': pendingUpdates['city'] ?? data['city'],
                                                      'subjects': pendingUpdates['subjects'] ?? data['subjects'],
                                                      'targetAge': pendingUpdates['targetAge'] ?? data['targetAge'],
                                                      'teachingLanguage': pendingUpdates['teachingLanguage'] ?? data['teachingLanguage'],
                                                      'ownedDevices': pendingUpdates['ownedDevices'] ?? data['ownedDevices'],
                                                      'academicDegree': pendingUpdates['academicDegree'] ?? data['academicDegree'],
                                                      if (pendingUpdates['certificateUrl'] != null) 'certificateUrl': pendingUpdates['certificateUrl'],
                                                      if (pendingUpdates['advancedDegreeCertificateUrl'] != null) 'advancedDegreeCertificateUrl': pendingUpdates['advancedDegreeCertificateUrl'],
                                                      if (pendingUpdates['identityUrl'] != null) 'identityUrl': pendingUpdates['identityUrl'],
                                                      if (pendingUpdates['experienceCertificateUrl'] != null) 'experienceCertificateUrl': pendingUpdates['experienceCertificateUrl'],
                                                      'status': 'approved',
                                                      'accountStatus': 'approved',
                                                      'isAvailable': true,
                                                      'pendingProfileUpdates': FieldValue.delete(),
                                                    });
                                                  },
                                                ),
                                                const SizedBox(width: 8),
                                                ElevatedButton.icon(
                                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                                                  icon: const Icon(Icons.cancel, size: 16),
                                                  label: const Text('رفض التعديلات'),
                                                  onPressed: () async {
                                                    await FirebaseFirestore.instance.collection('users').doc(docId).update({
                                                      'status': 'approved',
                                                      'accountStatus': 'approved',
                                                      'isAvailable': true,
                                                      'pendingProfileUpdates': FieldValue.delete(),
                                                    });
                                                  },
                                                ),
                                              ] else if (isPendingTeacher) ...[
                                                ElevatedButton.icon(
                                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                                                  icon: const Icon(Icons.check, size: 16),
                                                  label: const Text('قبول التسجيل (معلم تجريبي)'),
                                                  onPressed: () => approveTeacherRegistration(context, docId, (data['name'] ?? 'المعلم').toString()),
                                                ),
                                                const SizedBox(width: 8),
                                                ElevatedButton.icon(
                                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                                                  icon: const Icon(Icons.cancel, size: 16),
                                                  label: const Text('رفض وحذف الحساب'),
                                                  onPressed: () => deleteTeacherAccount(context, docId, (data['name'] ?? 'المعلم').toString()),
                                                ),
                                              ] else if (isTrialTeacher) ...[
                                                const Flexible(
                                                  child: Padding(
                                                    padding: EdgeInsets.symmetric(horizontal: 12),
                                                    child: Text('بانتظار أن يُجري المعلم مقابلته التجريبية', style: TextStyle(fontSize: 12, color: Colors.grey)),
                                                  ),
                                                ),
                                                ElevatedButton.icon(
                                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                                                  icon: const Icon(Icons.delete_forever, size: 16),
                                                  label: const Text('حذف المعلم'),
                                                  onPressed: () => deleteTeacherAccount(context, docId, (data['name'] ?? 'المعلم').toString()),
                                                ),
                                              ] else if (isInterviewedTeacher) ...[
                                                const Flexible(
                                                  child: Text(
                                                    'أزرار (عرض الفيديو، توثيق، إعادة المقابلة، حذف) بجانب اسم المعلم بالأعلى',
                                                    style: TextStyle(fontSize: 12, color: Colors.grey),
                                                  ),
                                                ),
                                              ] else ...[
                                                IconButton(
                                                  icon: const Icon(Icons.edit, color: Colors.blue),
                                                  onPressed: () => _showUserFormDialog(docId: docId, initialData: data),
                                                ),
                                                IconButton(
                                                  icon: const Icon(Icons.delete, color: Colors.red),
                                                  onPressed: () => _confirmDelete(docId: docId, collection: 'users', title: data['name'] ?? 'المستخدم'),
                                                ),
                                              ]
                                            ],
                                          )
                                        ],
                                      ),
                                    )
                                  ],
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          )
        ],
      ),
    );
  }

  // 3. إدارة الجلسات وطلبات الأسبقية (تم الإصلاح: 4 أقسام للفلترة)
  Widget _buildSessionManagementTab() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('إدارة الطلبات والجلسات (Sessions Collection)', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF2C3A2B))),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2C3A2B), foregroundColor: Colors.white),
                icon: const Icon(Icons.add_to_photos),
                label: const Text('إنشاء طلب حصة جديد'),
                onPressed: _showAddSessionDialog,
              )
            ],
          ),
          const SizedBox(height: 16),
          // أزرار فلترة الجلسات (4 أقسام)
          Wrap(
            spacing: 8,
            children: [
              FilterChip(label: const Text('معلقة'), selected: _sessionFilter == 'pending', onSelected: (v) => setState(() => _sessionFilter = 'pending')),
              FilterChip(label: const Text('نشطة'), selected: _sessionFilter == 'active', onSelected: (v) => setState(() => _sessionFilter = 'active')),
              FilterChip(label: const Text('مكتملة'), selected: _sessionFilter == 'completed', onSelected: (v) => setState(() => _sessionFilter = 'completed')),
              FilterChip(label: const Text('ملغاة'), selected: _sessionFilter == 'cancelled', onSelected: (v) => setState(() => _sessionFilter = 'cancelled')),
              FilterChip(label: const Text('منقطعة'), selected: _sessionFilter == 'interrupted', onSelected: (v) => setState(() => _sessionFilter = 'interrupted')),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('sessions').snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('لا توجد جلسات حالياً.'));
                }
                var docs = snapshot.data!.docs.where((doc) {
                  final d = doc.data() as Map<String, dynamic>;
                  if (d['isTrialInterview'] == true) return false; // مقابلات المعلمين لها مكان ثاني
                  final status = d['status'] ?? 'pending';
                  if (_sessionFilter == 'active') {
                    return ['accepted', 'active', 'in_progress'].contains(status);
                  }
                  return status == _sessionFilter;
                }).toList();

                docs.sort((a, b) {
                  final aData = a.data() as Map<String, dynamic>;
                  final bData = b.data() as Map<String, dynamic>;
                  final aTime = aData['createdAt'] as Timestamp?;
                  final bTime = bData['createdAt'] as Timestamp?;
                  if (aTime == null && bTime == null) return 0;
                  if (aTime == null) return 1;
                  if (bTime == null) return -1;
                  return bTime.compareTo(aTime);
                });

                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    final docId = docs[index].id;
                    final status = data['status'] ?? 'pending';
                    final bool isLiveOrAccepted = ['accepted', 'active', 'in_progress'].contains(status);

                    // ✨ كود التحقق يوضع هنا (خارج قائمة children)
                    bool isActuallyLive = false;
                    if (isLiveOrAccepted) {
                      final dynamic rawTimer = data['timerStartedAt'];
                      if (rawTimer is Timestamp) {
                        final startMs = rawTimer.toDate().millisecondsSinceEpoch;
                        final nowMs = DateTime.now().millisecondsSinceEpoch;
                        final diffMins = (nowMs - startMs) / 60000;
                        isActuallyLive = diffMins <= 65;
                      }
                    }

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('المادة: ${data['subject']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                  const SizedBox(height: 4),
                                  Text('الطالب: ${data['studentName']} | الموعد: ${data['scheduledTime'] ?? "فوري"}'),
                                  Text('المعلم: ${data['teacherName'] ?? data['assignedTeacherName'] ?? "لم يحدد بعد"} | الحالة: $status', style: const TextStyle(color: Color(0xFFE07A5F), fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 6),
                                  buildSessionExtras(data),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                // ✨ نستخدم المتغير isActuallyLive هنا داخل الواجهة
                                if (isActuallyLive) ...[
                                  ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                                    icon: const Icon(Icons.visibility, size: 16),
                                    label: const Text('مراقبة الحصة'),
                                    onPressed: () => _monitorSession(docId),
                                  ),
                                  const SizedBox(height: 6),
                                ],
                                if (status == 'pending') ...[
                                  ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE07A5F), foregroundColor: Colors.white),
                                    icon: const Icon(Icons.swap_horiz),
                                    label: const Text('إسناد يدوي'),
                                    onPressed: () => _showReassignTeacherDialog(docId),
                                  ),
                                  const SizedBox(height: 6),
                                ],
                                if (status == 'pending' || isLiveOrAccepted)
                                  OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(foregroundColor: Colors.orange),
                                    icon: const Icon(Icons.cancel),
                                    label: const Text('إلغاء الطلب'),
                                    onPressed: () => _cancelSession(docId, data['studentId']),
                                  ),
                                if (status == 'completed' || status == 'cancelled' || status == 'interrupted')
                                  OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                                    icon: const Icon(Icons.delete_forever),
                                    label: const Text('حذف نهائي'),
                                    onPressed: () => _confirmDelete(docId: docId, collection: 'sessions', title: 'جلسة ${data['subject']}'),
                                  )
                              ],
                            )
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          )
        ],
      ),
    );
  }


  // بطاقة الإحصائيات
  Widget _buildStatCard(String title, String value, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: color.withOpacity(0.15),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 4),
                  Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// 💬 تبويب الدعم الفني (Support Tab)
// ==========================================
class AdminSupportTab extends StatelessWidget {
  const AdminSupportTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('محادثات الدعم الفني', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF2C3A2B))),
          const SizedBox(height: 16),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('support_chats').orderBy('lastMessageAt', descending: true).snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('لا توجد رسائل دعم فني حالياً.'));
                }
                return ListView.builder(
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    final doc = snapshot.data!.docs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    return Card(
                      child: ListTile(
                        leading: const CircleAvatar(backgroundColor: Color(0xFF2C3A2B), child: Icon(Icons.person, color: Colors.white)),
                        title: Text(data['studentName'] ?? 'طالب', style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(data['lastMessage'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () {
                          Navigator.push(context, MaterialPageRoute(
                            builder: (context) => AdminChatScreen(studentId: doc.id, studentName: data['studentName']),
                          ));
                        },
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

// ==========================================
// 💬 شاشة المحادثة التفصيلية للأدمن (Chat Screen)
// ==========================================
class AdminChatScreen extends StatefulWidget {
  final String studentId;
  final String studentName;

  const AdminChatScreen({super.key, required this.studentId, required this.studentName});

  @override
  State<AdminChatScreen> createState() => _AdminChatScreenState();
}

class _AdminChatScreenState extends State<AdminChatScreen> {
  final TextEditingController _msgController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    // ✨ تصفير عداد الإشعارات عند فتح المحادثة
    FirebaseFirestore.instance.collection('support_chats').doc(widget.studentId).update({
      'unreadByAdminCount': 0,
    });
  }

  // ✨ دالة الإرسال (تدعم الزر و Enter)
  void _sendMessage() async {
    if (_msgController.text.trim().isEmpty) return;
    String text = _msgController.text.trim();
    _msgController.clear(); // مسح النص فوراً
    _focusNode.requestFocus(); // إبقاء التركيز على الحقل للإرسال المتتالي

    await FirebaseFirestore.instance.collection('support_chats').doc(widget.studentId).collection('messages').add({
      'text': text,
      'sender': 'admin',
      'createdAt': FieldValue.serverTimestamp(),
    });

    await FirebaseFirestore.instance.collection('support_chats').doc(widget.studentId).update({
      'lastMessage': text,
      'lastMessageAt': FieldValue.serverTimestamp(),
      'unreadByStudentCount': FieldValue.increment(1), // ✨ زيادة شارة الطالب
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF2C3A2B),
        title: Text(widget.studentName, style: const TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('support_chats').doc(widget.studentId).collection('messages').orderBy('createdAt', descending: false).snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final docs = snapshot.data!.docs;
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    final isAdmin = data['sender'] == 'admin';
                    return Align(
                      alignment: isAdmin ? Alignment.centerLeft : Alignment.centerRight,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isAdmin ? Colors.grey[200] : const Color(0xFF2C3A2B).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(data['text'] ?? '', style: TextStyle(color: isAdmin ? Colors.black87 : const Color(0xFF2C3A2B))),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _msgController,
                    focusNode: _focusNode,
                    decoration: InputDecoration(
                      hintText: 'اكتب ردك هنا...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    // ✨ إرسال عند ضغط Enter
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send, color: Color(0xFF2C3A2B)),
                  onPressed: _sendMessage,
                )
              ],
            ),
          )
        ],
      ),
    );
  }
}