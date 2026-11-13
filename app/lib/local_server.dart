import 'dart:io';

import 'edition.dart';

/// Starts the school server packed beside this Mac app.
/// Returns true when that server is accepting connections.
Future<bool> startBundledServer() async {
  if (!Platform.isMacOS) return false;
  final server = File('${File(Platform.resolvedExecutable).parent.path}/schooldesk-server');
  if (!await server.exists()) return false;
  if (await _portOpen()) return true;
  final home = Platform.environment['HOME'];
  if (home == null || home.isEmpty) return false;
  final data = Directory('$home/Library/Application Support/$localDataFolder');
  await data.create(recursive: true);
  await Process.start(
    server.path,
    ['--data', data.path, '--addr', ':$localPort'],
    mode: ProcessStartMode.detached,
    workingDirectory: data.path,
  );
  for (var i = 0; i < 50; i++) {
    if (await _portOpen()) return true;
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
  return false;
}

Future<bool> _portOpen() async {
  try {
    final socket = await Socket.connect('127.0.0.1', localPort, timeout: const Duration(milliseconds: 200));
    await socket.close();
    return true;
  } catch (_) {
    return false;
  }
}
