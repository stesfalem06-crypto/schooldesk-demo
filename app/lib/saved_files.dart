import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'edition.dart';

Future<Directory> reportFolder() async {
  Directory docs;
  if (Platform.environment['FLUTTER_TEST'] == 'true') {
    docs = Directory('${Directory.systemTemp.path}/SchoolDeskDocs');
  } else {
    try {
      docs = await getApplicationDocumentsDirectory().timeout(const Duration(milliseconds: 400));
    } catch (_) {
      docs = Directory('${Directory.systemTemp.path}/SchoolDesk');
    }
  }
  if (!demoEdition) return docs;
  final dir = Directory('${docs.path}/SchoolDesk');
  await dir.create(recursive: true);
  return dir;
}
