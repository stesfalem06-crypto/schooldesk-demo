import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:schooldesk/sample_week.dart';
import 'package:schooldesk/shamm_ui.dart';
import 'package:schooldesk/theme.dart';

Future<void> loadSchoolFonts() async {
  final regular = File('../server/internal/report/fonts/DejaVuSans.ttf')
      .readAsBytesSync();
  final bold = File('../server/internal/report/fonts/DejaVuSans-Bold.ttf')
      .readAsBytesSync();
  final loader = FontLoader('Roboto')
    ..addFont(
      Future<ByteData>.value(ByteData.sublistView(Uint8List.fromList(regular))),
    )
    ..addFont(
      Future<ByteData>.value(ByteData.sublistView(Uint8List.fromList(bold))),
    );
  await loader.load();
  final icons = _materialIcons();
  if (icons == null) {
    throw StateError(
      'MaterialIcons-Regular.otf was not found. Set FLUTTER_ROOT.',
    );
  }
  final iconLoader = FontLoader('MaterialIcons')
    ..addFont(Future<ByteData>.value(ByteData.sublistView(icons)));
  await iconLoader.load();
}

Uint8List? _materialIcons() {
  final roots = <String>[
    Platform.environment['FLUTTER_ROOT'] ?? '',
    Directory.current.path,
  ];
  final which = Process.runSync('which', ['flutter'], runInShell: true);
  if (which.exitCode == 0) {
    final bin = File(which.stdout.toString().trim());
    roots.add(bin.parent.parent.path);
  }
  for (final root in roots.where((item) => item.isNotEmpty)) {
    final file = File(
      '$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
    );
    if (file.existsSync()) return file.readAsBytesSync();
  }
  return null;
}

void main() {
  late SampleWeek week;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await loadSchoolFonts();
    final raw = File('../server/internal/engine/testdata/sample-school.json')
        .readAsStringSync();
    week = SampleWeek.parse(jsonDecode(raw) as Map<String, dynamic>);
  });

  testWidgets('sign-in by name and PIN', (tester) async {
    await _open(
      tester,
      const PinLogin(
        names: [
          'Hanna Berhe',
          'Samuel Ghebremeskel',
          'Meron Tesfalem',
          'Dawit Okubay',
        ],
      ),
    );
    expect(find.text('Hanna Berhe'), findsOneWidget);
    expect(find.text('Tap your name'), findsOneWidget);
    await _save(tester, 'sign-in');
  });

  testWidgets('messages', (tester) async {
    await _open(
      tester,
      const ChatScreen(
        previewPeople: ['Samuel Ghebremeskel', 'Meron Tesfalem'],
        previewMessages: ['Staff meeting at the hall'],
      ),
    );
    expect(find.text('Staff meeting at the hall'), findsOneWidget);
    await _save(tester, 'chat');
  });

  testWidgets('call', (tester) async {
    await _open(
      tester,
      const CallBoard(name: 'Samuel Ghebremeskel', status: 'Connected'),
    );
    expect(find.text('End call'), findsOneWidget);
    expect(find.text('This call stays on the school network.'), findsOneWidget);
    await _save(tester, 'call');
  });

  testWidgets('timetable', (tester) async {
    await _open(tester, TimetableBoard(week: week));
    expect(find.text('Break'), findsOneWidget);
    expect(find.text('English'), findsWidgets);
    expect(find.text('H. Gebre'), findsWidgets);
    expect(find.text('1-1'), findsWidgets);
    expect(find.text('Class'), findsOneWidget);
    expect(find.text('Teacher'), findsOneWidget);
    expect(find.text('Mon'), findsOneWidget);
    expect(find.text('Fri'), findsOneWidget);
    await _save(tester, 'timetable');
  });

  testWidgets('update', (tester) async {
    await _open(tester, const UpdatePrompt());
    expect(find.text('Update available, install'), findsOneWidget);
    expect(
      find.text('The school records stay on the school computer.'),
      findsOneWidget,
    );
    await _save(tester, 'update');
  });
}

Future<void> _open(WidgetTester tester, Widget child) async {
  const width = 1080.0;
  const height = 2340.0;
  tester.view.physicalSize = const Size(width, height);
  tester.view.devicePixelRatio = width / 412.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: schoolTheme(),
      home: child,
    ),
  );
  await tester.pump();
}

Future<void> _save(WidgetTester tester, String name) async {
  await expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile('goldens/shamm-$name.png'),
  );
}
