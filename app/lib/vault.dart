import 'dart:convert';
import 'dart:math';

import 'package:encrypt/encrypt.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class Vault {
  Vault() : _box = const FlutterSecureStorage();

  final FlutterSecureStorage _box;
  final Map<String, String> _mem = {};
  bool _memory = false;
  Encrypter? _enc;
  IV? _iv;

  Future<void> open() async {
    try {
      await _openSecure();
    } catch (_) {
      _memory = true;
    }
  }

  Future<void> _openSecure() async {
    var key = await _box.read(key: 'data_key');
    if (key == null || key.length < 32) {
      final bytes = List<int>.generate(32, (_) => Random.secure().nextInt(256));
      key = base64Encode(bytes);
      await _box.write(key: 'data_key', value: key);
    }
    final raw = base64Decode(key);
    _enc = Encrypter(AES(Key(raw), mode: AESMode.gcm));
    var iv = await _box.read(key: 'data_iv');
    if (iv == null) {
      final made = IV.fromSecureRandom(12);
      iv = made.base64;
      await _box.write(key: 'data_iv', value: iv);
    }
    _iv = IV.fromBase64(iv);
  }

  Future<void> write(String name, String value) async {
    if (_memory) {
      _mem[name] = value;
      return;
    }
    final enc = _enc;
    final iv = _iv;
    if (enc == null || iv == null) return;
    await _box.write(key: 'v_$name', value: enc.encrypt(value, iv: iv).base64);
  }

  Future<String?> read(String name) async {
    if (_memory) return _mem[name];
    final enc = _enc;
    final iv = _iv;
    final raw = await _box.read(key: 'v_$name');
    if (enc == null || iv == null || raw == null) return null;
    try {
      return enc.decrypt(Encrypted.fromBase64(raw), iv: iv);
    } catch (_) {
      return null;
    }
  }

  Future<void> writeJson(String name, Object value) => write(name, jsonEncode(value));

  Future<dynamic> readJson(String name) async {
    final raw = await read(name);
    if (raw == null || raw.isEmpty) return null;
    return jsonDecode(raw);
  }
}
