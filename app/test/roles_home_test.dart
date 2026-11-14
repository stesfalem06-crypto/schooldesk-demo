import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:schooldesk/app_state.dart';
import 'package:schooldesk/screens.dart';
import 'package:schooldesk/shell.dart';
import 'package:schooldesk/theme.dart';
import 'package:schooldesk/vault.dart';

void main() {
  testWidgets('admin home shows school tasks and hides a class', (tester) async {
    final model = _model('admin', 'Admin');
    await tester.pumpWidget(_app(model));
    await tester.pump();
    expect(find.text('See fees'), findsWidgets);
    expect(find.text('Who is away'), findsWidgets);
    expect(find.text('Set up school'), findsOneWidget);
    expect(find.text('My class'), findsNothing);
    expect(find.text('Enter marks'), findsNothing);
    expect(find.text(footerText), findsOneWidget);
  });

  testWidgets('homeroom home can take fees and enter marks', (tester) async {
    final model = _model('teacher', 'Samuel');
    model.user['homeroom_class_ids'] = ['class-1'];
    await tester.pumpWidget(_app(model));
    await tester.pump();
    expect(find.text('My class'), findsWidgets);
    expect(find.text('Take fees'), findsWidgets);
    expect(find.text('Enter marks'), findsWidgets);
    expect(find.text('Set up school'), findsNothing);
  });

  testWidgets('subject teacher only sees marks and the week', (tester) async {
    final model = _model('teacher', 'Meron');
    await tester.pumpWidget(_app(model));
    await tester.pump();
    expect(find.text('Enter marks'), findsWidgets);
    expect(find.text('My week'), findsWidgets);
    expect(find.text('Take fees'), findsNothing);
    expect(find.text('My class'), findsNothing);
  });
}

AppModel _model(String role, String name) {
  final model = AppModel(Vault());
  model.user = {'role': role, 'display_name': name, 'homeroom_class_ids': <String>[]};
  model.school = 'Hope Academy';
  model.base = 'http://127.0.0.1:9';
  model.licensed = true;
  model.token = 'token';
  return model;
}

Widget _app(AppModel model) {
  return ChangeNotifierProvider.value(
    value: model,
    child: MaterialApp(theme: schoolTheme(), home: DeskHost(home: const HomeScreen(), pages: rolePages)),
  );
}
