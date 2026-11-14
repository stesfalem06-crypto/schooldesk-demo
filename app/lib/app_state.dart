import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';

import 'api.dart';
import 'edition.dart';
import 'local_api.dart';
import 'school_book.dart';
import 'startup_log.dart';
import 'vault.dart';

class AppModel extends ChangeNotifier {
  AppModel(this.vault);

  final Vault vault;
  String? base;
  String? token;
  String school = '';
  Map<String, dynamic> user = {};
  bool licensed = false;
  String machineId = '';
  String qrPayload = '';
  String lockMessage = 'This school is locked';
  bool busy = false;
  String? error;
  List<Map<String, dynamic>> outbox = [];
  bool workedBefore = false;

  String get role => user['role']?.toString() ?? '';
  bool get isAdmin => role == 'admin';
  bool get isDirector => role == 'director';
  bool get seesSchool => isAdmin || isDirector;
  List<String> get homerooms => ((user['homeroom_class_ids'] as List?) ?? []).map((e) => e.toString()).toList();
  bool get isHomeroom => homerooms.isNotEmpty;
  String get deviceId => _device;

  String _device = '';

  SchoolApi? get api {
    if (demoEdition) return LocalSchoolApi();
    return base == null ? null : SchoolApi(base!, token: token);
  }

  String _smokeFile() {
    final marker = File('${SchoolBook.instance.directory}/smoke-role');
    if (!marker.existsSync()) return '';
    final role = marker.readAsStringSync().trim();
    try {
      marker.deleteSync();
    } catch (_) {}
    return role;
  }

  Future<void> bootDemo() async {
    await SchoolBook.open();
    school = SchoolBook.instance.schoolName;
    licensed = true;
    base = 'local';
    final smoke = Platform.environment['SCHOOLDESK_SMOKE'] ?? _smokeFile();
    if (smoke == 'admin' || smoke == 'director' || smoke == 'homeroom' || smoke == 'subject') enterRole(smoke);
    notifyListeners();
  }

  void enterRole(String key) {
    final book = SchoolBook.instance;
    book.setActor(key);
    user = Map<String, dynamic>.from(book.actor ?? {});
    school = book.schoolName;
    licensed = true;
    base = 'local';
    token = 'local';
    notifyListeners();
  }

  Future<void> boot() async {
    await vault.open();
    base = await vault.read('base');
    if (base != null && base!.isEmpty) base = null;
    token = await vault.read('token');
    school = await vault.read('school') ?? '';
    _device = await vault.read('device') ?? '';
    if (_device.isEmpty) {
      _device = _uuid();
      await vault.write('device', _device);
    }
    final rawUser = await vault.readJson('user');
    if (rawUser is Map) user = rawUser.map((k, v) => MapEntry(k.toString(), v));
    final rawBox = await vault.readJson('outbox');
    if (rawBox is List) {
      outbox = rawBox.whereType<Map>().map((e) => e.map((k, v) => MapEntry(k.toString(), v))).toList();
    }
    workedBefore = (await vault.read('licensed_once')) == '1';
    if (base != null) {
      await refreshLicense();
    }
    notifyListeners();
  }

  Future<void> forget() async {
    base = null;
    token = null;
    user = {};
    licensed = false;
    await vault.write('base', '');
    await vault.write('token', '');
    if (defaultTargetPlatform == TargetPlatform.macOS) {
      await vault.write('skip_local', '1');
    }
    notifyListeners();
  }

  Future<void> setBase(String value) async {
    var v = value.trim();
    if (!v.startsWith('http')) v = 'http://$v';
    v = v.replaceAll(RegExp(r'/+$'), '');
    if (!v.contains(':8741') && !RegExp(r':\d+$').hasMatch(v.split('//').last)) {
      v = '$v:8741';
    }
    base = v;
    await vault.write('base', v);
    token = null;
    user = {};
    await refreshLicense();
    notifyListeners();
  }

  Future<void> refreshLicense() async {
    final client = api;
    if (client == null) return;
    try {
      final data = await client.get('/api/v1/license') as Map<String, dynamic>;
      licensed = data['licensed'] == true;
      school = data['school_name']?.toString() ?? school;
      machineId = data['machine_id']?.toString() ?? '';
      qrPayload = data['qr_payload']?.toString() ?? '';
      lockMessage = data['message']?.toString() ?? 'This school is locked';
      error = null;
      if (licensed) {
        workedBefore = true;
        await vault.write('licensed_once', '1');
        await vault.write('school', school);
      }
    } on ApiException catch (e) {
      error = e.message;
      licensed = false;
    } catch (problem, stack) {
      error = 'The school computer did not answer';
      licensed = false;
      await logStartup(problem, stack);
    }
  }

  Future<String?> unlock(String code) async {
    try {
      final data = await api!.post('/api/v1/license/activate', {'code': code}) as Map<String, dynamic>;
      licensed = data['licensed'] == true;
      school = data['school_name']?.toString() ?? '';
      if (licensed) {
        workedBefore = true;
        await vault.write('licensed_once', '1');
        await vault.write('school', school);
      }
      notifyListeners();
      return licensed ? null : (data['error']?.toString() ?? 'That code did not work');
    } on ApiException catch (e) {
      return e.message;
    }
  }

  Future<String?> signIn(String username, String password) async {
    try {
      final data = await api!.post('/api/v1/auth/login', {
        'username': username,
        'password': password,
        'device_id': _device,
        'device_name': 'School phone',
        'platform': defaultTargetPlatform.name,
      }) as Map<String, dynamic>;
      token = data['token']?.toString();
      school = data['school_name']?.toString() ?? school;
      final u = data['user'];
      if (u is Map) user = u.map((k, v) => MapEntry(k.toString(), v));
      await vault.write('token', token ?? '');
      await vault.write('school', school);
      await vault.writeJson('user', user);
      licensed = true;
      notifyListeners();
      return null;
    } on ApiException catch (e) {
      if (e.locked) licensed = false;
      notifyListeners();
      return e.message;
    }
  }

  Future<void> signOut() async {
    if (demoEdition) {
      user = {};
      token = null;
      notifyListeners();
      return;
    }
    try {
      await api?.post('/api/v1/auth/logout', {});
    } catch (_) {}
    token = null;
    user = {};
    await vault.write('token', '');
    await vault.writeJson('user', {});
    notifyListeners();
  }

  Future<dynamic> ask(Future<dynamic> Function(SchoolApi api) call) async {
    final client = api;
    if (client == null) throw ApiException('Find the school computer first');
    try {
      final value = await call(client);
      error = null;
      return value;
    } on ApiException catch (e) {
      if (e.locked) licensed = false;
      error = e.message;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> queueScore(Map<String, dynamic> score) async {
    outbox.add(score);
    await vault.writeJson('outbox', outbox);
    notifyListeners();
  }

  Future<List<String>> flush() async {
    final messages = <String>[];
    final client = api;
    if (client == null || outbox.isEmpty) return messages;
    try {
      final data = await client.post('/api/v1/sync', {
        'device_id': _device,
        'device_name': 'School phone',
        'platform': defaultTargetPlatform.name,
        'since': 0,
        'scores': outbox,
      }) as Map<String, dynamic>;
      final conflicts = (data['conflicts'] as List?) ?? [];
      if (conflicts.isEmpty) {
        outbox = [];
      } else {
        messages.add('Some marks were already changed at school. Those were kept.');
        outbox = [];
      }
      await vault.writeJson('outbox', outbox);
      notifyListeners();
    } on ApiException catch (e) {
      messages.add(e.message);
    }
    return messages;
  }

  bool get canMarkOffline => workedBefore && role == 'teacher' && base != null;
}

String _uuid() {
  final r = Random.secure();
  final b = List<int>.generate(16, (_) => r.nextInt(256));
  return base64UrlEncode(b).replaceAll('=', '');
}
