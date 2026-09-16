import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
          return const AdminDashboardScreen();
        }

        return const AdminLoginScreen();
      },
    );
  }
}

// 🔑 شاشة تسجيل دخول المدير
class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _loginAdmin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = 'يرجى إدخال البريد الإلكتروني وكلمة المرور.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      UserCredential userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userCredential.user!.uid)
          .get();

      if (userDoc.exists && userDoc.data()?['role'] == 'admin') {
        // تم تسجيل الدخول بنجاح كمدير
      } else {
        await FirebaseAuth.instance.signOut();
        setState(() {
          _errorMessage = 'عذراً، هذا الحساب لا يملك صلاحيات مدير النظام (Admin).';
        });
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        _errorMessage = e.message ?? 'فشل تسجيل الدخول. تحقق من البيانات.';
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'حدث خطأ غير متوقع: $e';
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF2C3A2B),
      body: Center(
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
                'لوحة تحكم المدير | لبيب',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF2C3A2B)),
              ),
              const Text('تسجيل الدخول الآمن لمدير النظام', style: TextStyle(color: Colors.grey, fontSize: 13)),
              const SizedBox(height: 24),
              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)),
                  child: Text(_errorMessage!, style: const TextStyle(color: Colors.red, fontSize: 12)),
                ),
                const SizedBox(height: 16),
              ],
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'البريد الإلكتروني للأدمن',
                  prefixIcon: Icon(Icons.email),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'كلمة المرور',
                  prefixIcon: Icon(Icons.lock),
                  border: OutlineInputBorder(),
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
                      : const Text('تسجيل الدخول للوحة التحكم', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              )
            ],
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
  String _rechargeFilter = 'pending'; // فلتر الشحن (معلقة أو معبأ)

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this); // 5 تبويبات
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
                      'status': 'approved',
                      'accountStatus': 'approved',
                      'updatedAt': FieldValue.serverTimestamp(),
                    };

                    if (selectedRole == 'teacher') {
                      userData['subjects'] = infoController.text.split(',').map((e) => e.trim()).toList();
                      userData['isAvailable'] = true;
                    } else if (selectedRole == 'student') {
                      userData['grade'] = infoController.text.trim();
                    }

                    if (docId == null) {
                      userData['createdAt'] = FieldValue.serverTimestamp();
                      await FirebaseFirestore.instance.collection('users').add(userData);
                    } else {
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
              stream: FirebaseFirestore.instance.collection('sessions').where('status', whereIn: ['accepted', 'in_progress']).snapshots(),
              builder: (context, snapshot) {
                int count = snapshot.data?.docs.length ?? 0;
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
              stream: FirebaseFirestore.instance.collection('users').where('status', isEqualTo: 'pending_approval').snapshots(),
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
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildQualityAndStatsTab(),
          _buildUserManagementTab(),
          _buildSessionManagementTab(),
          _buildRechargeRequestsTab(),
          const AdminSupportTab(),
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

              bool isCurrentlyLive = false;
              if ((status == 'in_progress' || status == 'accepted') && timerStartedAt != null) {
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
          // أزرار الفلترة
          Wrap(
            spacing: 8,
            children: [
              FilterChip(label: const Text('الكل'), selected: _userFilter == 'all', onSelected: (v) => setState(() => _userFilter = 'all')),
              FilterChip(label: const Text('طلاب'), selected: _userFilter == 'student', onSelected: (v) => setState(() => _userFilter = 'student')),
              FilterChip(label: const Text('معلمين'), selected: _userFilter == 'teacher', onSelected: (v) => setState(() => _userFilter = 'teacher')),
              FilterChip(label: const Text('أدمن'), selected: _userFilter == 'admin', onSelected: (v) => setState(() => _userFilter = 'admin')),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('users').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('حدث خطأ أثناء جلب البيانات: ${snapshot.error}'));
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('لا يوجد مستخدمون حالياً في قاعدة البيانات.'));
                }

                var docs = snapshot.data!.docs.where((doc) {
                  final role = (doc.data() as Map<String, dynamic>)['role'] ?? 'student';
                  return _userFilter == 'all' ? true : role == _userFilter;
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
                    final role = data['role'] ?? 'student';
                    final status = data['status'] ?? data['accountStatus'] ?? 'approved';
                    final isAvailable = data['isAvailable'] == true;
                    final isPendingTeacher = role == 'teacher' &&
                        (status == 'pending_approval' || status == 'pending' || status == 'pending_review' || !isAvailable);

                    // ✨ استخراج رابط الشهادة (سواء من certificateUrl أو من مصفوفة certificates)
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
                      color: isPendingTeacher ? Colors.orange.shade50 : Colors.white,
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ExpansionTile(
                        leading: CircleAvatar(
                          backgroundColor: role == 'teacher'
                              ? const Color(0xFF2C3A2B)
                              : (role == 'admin' ? Colors.purple : const Color(0xFFE07A5F)),
                          child: Text(role.isNotEmpty ? role[0].toUpperCase() : 'U', style: const TextStyle(color: Colors.white)),
                        ),
                        title: Row(
                          children: [
                            Text('${data['name'] ?? 'مستخدم جديد'} (الدور: $role)'),
                            if (isPendingTeacher) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(color: Colors.orange, borderRadius: BorderRadius.circular(12)),
                                child: const Text('طلب انضمام معلم معلق ⏳', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                              ),
                            ]
                          ],
                        ),
                        subtitle: Text('الهاتف: ${data['phone'] ?? 'غير محدد'}'),
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (role == 'teacher') ...[
                                  Text('التخصصات: ${data['subjects']?.join(', ') ?? 'غير محدد'}', style: const TextStyle(fontSize: 13)),
                                  Text('الفئات العمرية: ${data['targetAge']?.join(', ') ?? 'غير محدد'}', style: const TextStyle(fontSize: 13)),
                                  const SizedBox(height: 8),
                                  // ✨ إظهار الشهادة بجانب الهوية
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
                                ] else if (role == 'student') ...[
                                  Text('المرحلة الدراسية: ${data['grade'] ?? 'غير محدد'}', style: const TextStyle(fontSize: 13)),
                                  Text('الرصيد: ${data['points'] ?? 0} نقطة', style: const TextStyle(fontSize: 13)),
                                ],
                                const SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    if (isPendingTeacher) ...[
                                      ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                                        icon: const Icon(Icons.check, size: 16),
                                        label: const Text('قبول المعلم'),
                                        onPressed: () async {
                                          await FirebaseFirestore.instance.collection('users').doc(docId).update({
                                            'role': 'teacher',
                                            'status': 'approved',
                                            'accountStatus': 'approved',
                                            'isAvailable': true,
                                          });
                                        },
                                      ),
                                      const SizedBox(width: 8),
                                      ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                                        icon: const Icon(Icons.cancel, size: 16),
                                        label: const Text('رفض المعلم'),
                                        onPressed: () => _confirmDelete(docId: docId, collection: 'users', title: 'طلب انضمام: ${data['name'] ?? "معلم"}'),
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
                  final status = (doc.data() as Map<String, dynamic>)['status'] ?? 'pending';
                  if (_sessionFilter == 'active') {
                    return ['accepted', 'in_progress'].contains(status);
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
                    final bool isLiveOrAccepted = status == 'in_progress' || status == 'accepted';

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

  // 4. تبويب طلبات شحن الرصيد (تم الإصلاح: حماية من النقر المزدوج + قائمة الرصيد المعبأ)
  Widget _buildRechargeRequestsTab() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'طلبات شحن الرصيد (Recharge Requests)',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF2C3A2B)),
          ),
          const SizedBox(height: 16),
          // أزرار فلترة الشحن (معلقة / الرصيد المعبأ)
          Wrap(
            spacing: 8,
            children: [
              FilterChip(label: const Text('معلقة'), selected: _rechargeFilter == 'pending', onSelected: (v) => setState(() => _rechargeFilter = 'pending')),
              FilterChip(label: const Text('الرصيد المعبأ'), selected: _rechargeFilter == 'approved', onSelected: (v) => setState(() => _rechargeFilter = 'approved')),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('recharge_requests')
                  .where('status', isEqualTo: _rechargeFilter)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(child: Text(_rechargeFilter == 'pending' ? 'لا توجد طلبات شحن معلقة حالياً.' : 'لا يوجد رصيد معبأ مسبقاً.'));
                }

                final docs = snapshot.data!.docs.toList();
                docs.sort((a, b) {
                  final aTime = (a.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
                  final bTime = (b.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
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
                    final studentId = data['studentId'] ?? '';
                    final studentName = data['studentName'] ?? 'طالب';
                    final packageTitle = data['packageTitle'] ?? 'باقة';
                    final pointsCount = data['pointsCount'] ?? 0;
                    final referenceNumber = data['referenceNumber'] ?? 'لا يوجد';
                    final receiptImageUrl = data['receiptImageUrl'] ?? '';

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          children: [
                            if (receiptImageUrl.isNotEmpty)
                              InkWell(
                                onTap: () => html.window.open(receiptImageUrl, '_blank'),
                                child: Container(
                                  width: 80,
                                  height: 80,
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.grey.shade300),
                                    borderRadius: BorderRadius.circular(8),
                                    image: DecorationImage(
                                      image: NetworkImage(receiptImageUrl),
                                      fit: BoxFit.cover,
                                    ),
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
                            else
                              Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  color: Colors.grey[200],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.receipt_long, color: Colors.grey),
                              ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('الطالب: $studentName', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                  Text('الباقة: $packageTitle ($pointsCount نقطة)'),
                                  Text('مرجع التحويل: $referenceNumber', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                                ],
                              ),
                            ),
                            // ✨ إظهار الأزرار بناءً على حالة الطلب
                            if (_rechargeFilter == 'pending')
                              Column(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.check_circle, color: Colors.green, size: 30),
                                    tooltip: 'قبول الشحن وإضافة النقاط للطالب',
                                    onPressed: () async {
                                      // ✨ حماية قاطعة من النقر المزدوج
                                      final reqRef = FirebaseFirestore.instance.collection('recharge_requests').doc(docId);
                                      final reqSnap = await reqRef.get();
                                      if (reqSnap.exists && reqSnap.data()?['status'] == 'approved') {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('تمت الموافقة على هذا الطلب مسبقاً'), backgroundColor: Colors.orange),
                                        );
                                        return;
                                      }

                                      try {
                                        final userRef = FirebaseFirestore.instance.collection('users').doc(studentId);
                                        final userSnap = await userRef.get();

                                        num currentPoints = 0;
                                        if (userSnap.exists) {
                                          final userData = userSnap.data() as Map<String, dynamic>;
                                          final dynamic rawPoints = userData['points'];
                                          currentPoints = (rawPoints is num) ? rawPoints : 0;
                                        }

                                        await userRef.update({
                                          'points': currentPoints + pointsCount,
                                        });

                                        await reqRef.update({
                                          'status': 'approved',
                                          'approvedAt': FieldValue.serverTimestamp(),
                                        });

                                        if (mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text('✅ تم شحن $pointsCount نقطة للطالب $studentName بنجاح!')),
                                          );
                                        }
                                      } catch (e) {
                                        if (mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text('❌ خطأ في الشحن: $e'), backgroundColor: Colors.red),
                                          );
                                        }
                                      }
                                    },
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.cancel, color: Colors.red, size: 30),
                                    tooltip: 'رفض الطلب وحذفه',
                                    onPressed: () => _confirmDelete(docId: docId, collection: 'recharge_requests', title: 'طلب شحن: $studentName'),
                                  ),
                                ],
                              )
                            else
                              const Icon(Icons.check_circle, color: Colors.green, size: 30),
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