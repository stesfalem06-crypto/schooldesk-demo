import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:schooldesk/app_state.dart';
import 'package:schooldesk/demo_extra.dart';
import 'package:schooldesk/school_book.dart';
import 'package:schooldesk/vault.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('typing 2, 5 names those students', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final dir = Directory.systemTemp.createTempSync('sd-att');
    await SchoolBook.open(directory: dir.path);
    final model = AppModel(Vault());
    model.enterRole('admin');
    await tester.pumpWidget(ChangeNotifierProvider.value(
      value: model,
      child: const MaterialApp(home: AttendanceScreen(smokeClassName: '1-1')),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('Amanuel Araya'), findsWidgets);
    expect(find.textContaining('Present today 0'), findsNothing);
    await tester.enterText(find.byKey(const Key('absent-numbers')), '2, 5');
    await tester.pump();
    expect(find.textContaining('Absent today: Biniam Haile, Genet Weldemichael'), findsOneWidget);
    expect(find.textContaining('No student with number'), findsNothing);
    await tester.enterText(find.byKey(const Key('absent-numbers')), '2, 5, 99');
    await tester.pump();
    expect(find.text('No student with number 99'), findsOneWidget);
    expect(find.textContaining('No student with number 2, 5'), findsNothing);
  });
}
