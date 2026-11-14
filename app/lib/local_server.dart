import 'dart:convert';
import 'dart:io';

import 'edition.dart';
import 'startup_log.dart';

enum LocalServer { missing, ready, notReady }

/// Starts the school server packed beside this app.
/// [missing] means this build has no server next to it.
/// [notReady] means the file is there but it is not accepting connections yet.
Future<LocalServer> startBundledServer() async {
  if (!Platform.isMacOS && !Platform.isWindows && !Platform.isLinux) return LocalServer.missing;
  final name = Platform.isWindows ? 'schooldesk-server.exe' : 'schooldesk-server';
  final server = File('${File(Platform.resolvedExecutable).parent.path}${Platform.pathSeparator}$name');
  if (!await server.exists()) return LocalServer.missing;
  if (!await _portOpen()) {
    final data = _dataDir();
    if (data == null) {
      await logStartup('No folder for school records');
      return LocalServer.notReady;
    }
    try {
      await data.create(recursive: true);
      await Process.start(
        server.path,
        ['--data', data.path, '--addr', ':$localPort'],
        mode: ProcessStartMode.detached,
        workingDirectory: data.path,
      );
    } catch (error, stack) {
      await logStartup('Could not start ${server.path}: $error', stack);
      return LocalServer.notReady;
    }
  }
  for (var i = 0; i < 50; i++) {
    if (await _portOpen() && await _matchesThisEdition()) return LocalServer.ready;
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
  await logStartup('Server did not answer as the ${demoEdition ? 'demo' : 'school'} program on port $localPort');
  return LocalServer.notReady;
}

Future<bool> _matchesThisEdition() async {
  try {
    final client = HttpClient();
    final req = await client.getUrl(Uri.parse('http://127.0.0.1:$localPort/api/v1/health'));
    final res = await req.close().timeout(const Duration(seconds: 2));
    final body = await res.transform(utf8.decoder).join();
    final data = jsonDecode(body);
    if (data is! Map) return false;
    final demo = data['demo'] == true;
    return demoEdition ? demo : !demo;
  } catch (error) {
    await logStartup('Could not check the school program: $error');
    return false;
  }
}

Directory? _dataDir() {
  if (Platform.isMacOS) {
    final home = Platform.environment['HOME'];
    if (home == null || home.isEmpty) return null;
    return Directory('$home/Library/Application Support/$localDataFolder');
  }
  if (Platform.isWindows) {
    final base = Platform.environment['LOCALAPPDATA'];
    if (base == null || base.isEmpty) return null;
    return Directory('$base\\$localDataFolder');
  }
  final home = Platform.environment['HOME'];
  if (home == null || home.isEmpty) return null;
  return Directory('$home/.local/share/$localDataFolder');
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
