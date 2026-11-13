import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schooldesk/shell.dart';
import 'package:schooldesk/theme.dart';

void main() {
  testWidgets('every screen shell shows the footer', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SchoolScaffold(title: 'Home', body: SizedBox())));
    expect(find.text(footerText), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
  });
}
