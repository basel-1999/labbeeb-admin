import 'dart:async';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

/// عنوان السيرفر (Render)
const String kApiBase = 'https://labbeeb-wep.onrender.com';

/// نداء مسار إدارة بالسيرفر، مع توكن المستخدم المسجل (أدمن أو مسؤول مالي حسب المسار)
Future<Map<String, dynamic>> callAdminApi(String path, {Map<String, dynamic>? body}) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    throw Exception('انتهت الجلسة، سجّل دخولك من جديد.');
  }
  final token = await user.getIdToken();
  if (token == null) {
    throw Exception('تعذر التحقق من هويتك، سجّل دخولك من جديد.');
  }

  final res = await http
      .post(
    Uri.parse('$kApiBase$path'),
    headers: {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    },
    body: jsonEncode(body ?? <String, dynamic>{}),
  )
      .timeout(const Duration(seconds: 90));

  Map<String, dynamic> data = {};
  try {
    final decoded = jsonDecode(utf8.decode(res.bodyBytes));
    if (decoded is Map<String, dynamic>) data = decoded;
  } catch (_) {}

  if (res.statusCode >= 200 && res.statusCode < 300) return data;

  final detail = data['detail'];
  throw Exception(detail is String ? detail : 'خطأ من الخادم (${res.statusCode})');
}

/// تحويل أي خطأ لنص عربي واضح
String cleanError(Object e) {
  if (e is TimeoutException) {
    return 'الخادم تأخر بالرد. ممكن يكون نائماً، انتظر دقيقة وأعد المحاولة.';
  }
  var s = e.toString();
  if (s.startsWith('Exception: ')) s = s.substring('Exception: '.length);
  if (s.contains('XMLHttpRequest') || s.contains('Failed to fetch') || s.contains('ClientException')) {
    return 'تعذر الاتصال بالخادم (قد يكون نائماً أو الإنترنت منقطع). انتظر دقيقة وأعد المحاولة.';
  }
  return s;
}