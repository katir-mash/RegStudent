import 'dart:async';
import 'dart:convert';
import 'dart:io';

class RegistryError implements Exception {
  final String message;
  final int status;
  const RegistryError(this.message, [this.status = 0]);
}

class Student {
  final int id;
  final String name, email, cohort;
  const Student(this.id, this.name, this.email, this.cohort);
  factory Student.fromJson(Map<String, dynamic> m) =>
      Student(m['id'], m['name'], m['email'], m['cohort']);
}

String? validateName(String text) {
  final length = text.trim().runes.length;
  if (length == 0) return 'Аты-жөнін енгізіңіз';
  return length > 80 ? 'Ең көбі 80 таңба' : null;
}

String? validateEmail(String text) {
  final value = text.trim();
  final valid = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value);
  return value.length <= 254 && valid ? null : 'Дұрыс email енгізіңіз';
}

String? validateGroup(String text) {
  final n = text.trim().runes.length;
  return n > 0 && n <= 24 ? null : 'Топ атауы 1–24 таңба болуы керек';
}

List<Student> filtered(List<Student> rows, String query, bool ascending) {
  final q = query.trim().toLowerCase();
  final out = rows
      .where((s) =>
          s.name.toLowerCase().contains(q) ||
          s.cohort.toLowerCase().contains(q))
      .toList();
  out.sort((a, b) {
    final cmp = a.name.toLowerCase().compareTo(b.name.toLowerCase());
    return (ascending ? 1 : -1) * (cmp == 0 ? a.id.compareTo(b.id) : cmp);
  });
  return out;
}

class RegistryApi {
  final Uri base;
  String _token = '';
  String loginName = '';
  bool admin = false;
  RegistryApi(this.base);

  Future<dynamic> request(String method, String path,
      [Map<String, String>? data]) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 6);
    Future<dynamic> send() async {
      final req = await client.openUrl(method, base.resolve(path));
      if (_token.isNotEmpty) req.headers.set('Authorization', 'Bearer $_token');
      if (data != null) {
        req.headers.contentType = ContentType.json;
        req.write(jsonEncode(data));
      }
      final res = await req.close();
      final body = await utf8.decoder.bind(res).join();
      if (res.statusCode >= 400) {
        const messages = {
          400: 'Деректерді тексеріңіз',
          401: 'Кіру деректері немесе сессия жарамсыз',
          403: 'Әкімші құқығы қажет',
          404: 'Жазба табылмады',
          409: 'Бұл email тіркелген'
        };
        throw RegistryError(
            messages[res.statusCode] ?? 'Сервер сұранысты орындай алмады',
            res.statusCode);
      }
      return body.isEmpty ? null : jsonDecode(body);
    }

    try {
      return await send().timeout(const Duration(seconds: 8));
    } on IOException {
      throw const RegistryError('Серверге қосылу мүмкін болмады');
    } on TimeoutException {
      throw const RegistryError('Сервер жауабы кешікті');
    } on FormatException {
      throw const RegistryError('Сервер жауабы жарамсыз');
    } finally {
      client.close(force: true);
    }
  }

  Future<void> signIn(String login, String password) async {
    final data = await request(
        'POST', '/api/login', {'login': login, 'password': password});
    _token = data['token'];
    loginName = login;
    admin = data['role'] == 'admin';
  }

  void signOut() {
    _token = '';
    loginName = '';
    admin = false;
  }

  Future<List<Student>> list() async =>
      (await request('GET', '/api/students') as List)
          .map((m) => Student.fromJson(m))
          .toList();
  Future<void> save(int? id, String name, String email, String cohort) async {
    await request(
        id == null ? 'POST' : 'PUT',
        id == null ? '/api/students' : '/api/students/$id',
        {'name': name.trim(), 'email': email.trim(), 'cohort': cohort.trim()});
  }

  Future<void> remove(int id) async {
    await request('DELETE', '/api/students/$id');
  }
}
