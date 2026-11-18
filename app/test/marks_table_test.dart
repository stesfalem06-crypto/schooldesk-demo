import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:schooldesk/data_grid.dart';
import 'package:schooldesk/marks_table.dart';

void main() {
  testWidgets('average sort and name filter keep the real ranks', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: MarksTable(subjects: ['Mathematics'], rows: _rows))));
    await tester.pump();
    var grid = tester.widget<DataGrid>(find.byType(DataGrid));
    expect(grid.rows.first[1], 'Abel Tesfamariam');
    expect(grid.rows.first[6], '1');
    expect(find.textContaining('Rank 1 is at the top'), findsOneWidget);

    await tester.tap(find.text('Ascending'));
    await tester.pump();
    grid = tester.widget<DataGrid>(find.byType(DataGrid));
    expect(grid.rows.last[1], 'Abel Tesfamariam');
    expect(grid.rows.last[6], '1');
    expect(find.textContaining('Rank 1 is at the bottom'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, 'Find a student'), 'Yon');
    await tester.pump();
    grid = tester.widget<DataGrid>(find.byType(DataGrid));
    expect(grid.rows.length, 1);
    expect(grid.rows.single[1], 'Yonas Habte');
    expect(grid.rows.single[6], '2');
  });
}

const _rows = [
  {'roll': 1, 'name': 'Abel Tesfamariam', 'sex': 'M', 'marks': {'Mathematics': {'total': 90}}, 'total': 90, 'average': 90, 'rank': 1, 'result': 'Pass'},
  {'roll': 4, 'name': 'Yonas Habte', 'sex': 'M', 'marks': {'Mathematics': {'total': 80}}, 'total': 80, 'average': 80, 'rank': 2, 'result': 'Pass'},
  {'roll': 2, 'name': 'Feven Tekle', 'sex': 'F', 'marks': {'Mathematics': {'total': 70}}, 'total': 70, 'average': 70, 'rank': 4, 'result': 'Pass'},
];
