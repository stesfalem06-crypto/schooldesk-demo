import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:multicast_dns/multicast_dns.dart';

class ApiException implements Exception {
  ApiException(this.message, {this.locked = false, this.conflict, this.status = 0});
  final String message;
  final bool locked;
  final Map<String, dynamic>? conflict;
  final int status;
  @override
  String toString() => message;
}

class SchoolApi {
  SchoolApi(this.base, {this.token});

  String base;
  String? token;

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

  Uri _u(String path) => Uri.parse('$base$path');

  Future<dynamic> get(String path) => _send(() => http.get(_u(path), headers: _headers));

  Future<dynamic> post(String path, Object body) =>
      _send(() => http.post(_u(path), headers: _headers, body: jsonEncode(body)));

  Future<dynamic> put(String path, Object body) =>
      _send(() => http.put(_u(path), headers: _headers, body: jsonEncode(body)));

  Future<dynamic> delete(String path) => _send(() => http.delete(_u(path), headers: _headers));

  Future<List<int>> postBytes(String path, Object body) async {
    http.Response res;
    try {
      res = await http.post(_u(path), headers: _headers, body: jsonEncode(body)).timeout(const Duration(seconds: 30));
    } on SocketException {
      throw ApiException('The school computer is not on this network');
    }
    if (res.statusCode >= 400) {
      var msg = 'That did not work';
      try {
        final data = jsonDecode(res.body);
        if (data is Map && data['error'] != null) msg = data['error'].toString();
      } catch (_) {}
      throw ApiException(msg, status: res.statusCode, locked: res.statusCode == 423);
    }
    return res.bodyBytes;
  }

  Future<List<int>> bytes(String path) async {
    final res = await http.get(_u(path), headers: _headers).timeout(const Duration(seconds: 20));
    if (res.statusCode == 423) throw ApiException('This school is locked', locked: true, status: 423);
    if (res.statusCode >= 400) throw ApiException('Could not open the file', status: res.statusCode);
    return res.bodyBytes;
  }

  Future<dynamic> _send(Future<http.Response> Function() call) async {
    http.Response res;
    try {
      res = await call().timeout(const Duration(seconds: 20));
    } on SocketException {
      throw ApiException('The school computer is not on this network');
    }
    Map<String, dynamic> data = {};
    if (res.body.isNotEmpty) {
      final decoded = jsonDecode(res.body);
      if (decoded is Map<String, dynamic>) data = decoded;
      if (decoded is List) return decoded;
    }
    if (res.statusCode == 423 || data['locked'] == true) {
      throw ApiException(data['error']?.toString() ?? 'This school is locked', locked: true, status: res.statusCode);
    }
    if (res.statusCode == 409) {
      throw ApiException(data['error']?.toString() ?? 'The school record is newer', conflict: data, status: 409);
    }
    if (res.statusCode >= 400) {
      throw ApiException(data['error']?.toString() ?? 'That did not work', status: res.statusCode);
    }
    return data;
  }

  static Future<List<String>> find({Duration timeout = const Duration(seconds: 4)}) async {
    final client = MDnsClient();
    final found = <String>{};
    try {
      await client.start();
      await for (final ptr in client.lookup<PtrResourceRecord>(ResourceRecordQuery.serverPointer('_schooldesk._tcp.local')).timeout(timeout, onTimeout: (sink) => sink.close())) {
        await for (final srv in client.lookup<SrvResourceRecord>(ResourceRecordQuery.service(ptr.domainName))) {
          final host = srv.target.endsWith('.') ? srv.target.substring(0, srv.target.length - 1) : srv.target;
          found.add('http://$host:${srv.port}');
        }
      }
    } catch (_) {
      // Finding the school by name is optional. The number can be typed.
    } finally {
      client.stop();
    }
    return found.toList();
  }

  /// Asks on the school network. The server answers with its address. No internet is used.
  static Future<List<String>> findUdp({Duration timeout = const Duration(seconds: 2)}) async {
    final found = <String>{};
    RawDatagramSocket socket;
    try {
      socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    } catch (_) {
      return [];
    }
    socket.broadcastEnabled = true;
    socket.send(utf8.encode('SHAMM?'), InternetAddress('255.255.255.255'), 8742);
    final timer = Timer(timeout, socket.close);
    try {
      await for (final event in socket) {
        if (event != RawSocketEvent.read) continue;
        final dg = socket.receive();
        if (dg == null) continue;
        final match = RegExp(r'SHAMM/1\s+(\d+)').firstMatch(utf8.decode(dg.data, allowMalformed: true));
        if (match != null) found.add('http://${dg.address.address}:${match.group(1)}');
      }
    } catch (_) {
      // The school can still be opened by typing its number.
    } finally {
      timer.cancel();
      socket.close();
    }
    return found.toList();
  }
}
