import 'dart:io';

import 'package:path_provider/path_provider.dart';

Future<void> logStartup(Object error, [StackTrace? stack]) async {
  final text = '${DateTime.now().toIso8601String()} $error${stack == null ? '' : '\n$stack'}\n';
  try {
    stdout.writeln(text);
    stderr.writeln(text);
  } catch (_) {}
  try {
    final file = File(await _logPath());
    await file.parent.create(recursive: true);
    await file.writeAsString(text, mode: FileMode.append);
  } catch (_) {}
}

Future<String> _logPath() async {
  if (Platform.isMacOS) {
    final home = Platform.environment['HOME'] ?? '';
    return '$home/Library/Logs/SchoolDesk/startup.log';
  }
  if (Platform.isWindows) {
    final base = Platform.environment['LOCALAPPDATA'] ?? Platform.environment['TEMP'] ?? '.';
    return '$base\\SchoolDesk\\Logs\\startup.log';
  }
  if (Platform.isAndroid) {
    final dir = await getApplicationSupportDirectory();
    return '${dir.path}/SchoolDesk/logs/startup.log';
  }
  final home = Platform.environment['HOME'] ?? '.';
  return '$home/.local/share/SchoolDesk/logs/startup.log';
}
