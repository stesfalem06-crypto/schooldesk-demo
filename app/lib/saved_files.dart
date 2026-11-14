import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'edition.dart';

Future<Directory> reportFolder() async {
  final docs = await getApplicationDocumentsDirectory();
  if (!demoEdition) return docs;
  final dir = Directory('${docs.path}/SchoolDesk');
  await dir.create(recursive: true);
  return dir;
}
