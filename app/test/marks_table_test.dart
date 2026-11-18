import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:schooldesk/data_grid.dart';
import 'package:schooldesk/marks_table.dart';

List<GridCol> _columns(int subjects) => [
      const GridCol('No.', 40, TextAlign.center, pin: true),
      const GridCol('Student', 180, TextAlign.left, flex: true, pin: true),
      const GridCol('Sex', 40, TextAlign.center),
      for (final name in ['Mathematics', 'English', 'Science', 'Social studies', 'Civics', 'Art', 'Music', 'ICT'].take(subjects)) GridCol(name, 84, TextAlign.right),
      const GridCol('Total', 64, TextAlign.right),
      const GridCol('Average', 72, TextAlign.right),
      const GridCol('Rank', 56, TextAlign.center),
      const GridCol('Result', 72, TextAlign.center),
    ];

void main() {
  test('a four-subject class fits and Social studies breaks on the space', () {
    final layout = layoutGrid(990, _columns(4));
    expect(layout.scrolls, isFalse);
    expect(layout.total, lessThanOrEqualTo(990));
    expect(layout.widths[layout.widths.length - 2], greaterThanOrEqualTo(textWidth('Rank', headerStyle)));
    expect(headerLabel('Rank', 48), 'Rank');
    expect(headerLabel('Social studies', 400), 'Social studies');
    expect(headerLabel('Social studies', 70), 'Social\nstudies');
  });

  test('eight subjects scroll instead of squeezing Rank off the page', () {
    final layout = layoutGrid(990, _columns(8));
    expect(layout.scrolls, isTrue);
    expect(_columns(8).take(2).every((col) => col.pin), isTrue);
  });

  testWidgets('average sort and name filter keep the real ranks', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: MarksTable(subjects: ['Mathematics'], rows: _rows))));
    await tester.pump();
    var grid = tester.widget<DataGrid>(find.byType(DataGrid));
    expect(grid.rows.first[1], 'Abel Tesfamariam');
    expect(grid.rows.first[6], '1');
    expect(grid.rows[1][6], '2');
    expect(grid.rows[2][6], '4');

    await tester.tap(find.text('Ascending'));
    await tester.pump();
    grid = tester.widget<DataGrid>(find.byType(DataGrid));
    expect(grid.rows.last[1], 'Abel Tesfamariam');
    expect(grid.rows.last[6], '1');

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
