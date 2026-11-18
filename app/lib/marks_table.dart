import 'package:material_ui/material_ui.dart';

import 'data_grid.dart';
import 'theme.dart';

class NameSortBar extends StatelessWidget {
  const NameSortBar({
    super.key,
    required this.filter,
    required this.sortKey,
    required this.choices,
    required this.descending,
    required this.onFilter,
    required this.onSort,
    required this.onDirection,
    this.status = '',
  });

  final TextEditingController filter;
  final String sortKey;
  final List<String> choices;
  final bool descending;
  final ValueChanged<String> onFilter;
  final ValueChanged<String> onSort;
  final ValueChanged<bool> onDirection;
  final String status;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Wrap(spacing: 12, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
        SizedBox(
          width: 260,
          child: TextField(
            controller: filter,
            decoration: const InputDecoration(labelText: 'Find a student', isDense: true),
            onChanged: onFilter,
          ),
        ),
        const Text('Sort by', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        DropdownButton<String>(
          value: choices.contains(sortKey) ? sortKey : choices.first,
          items: [for (final choice in choices) DropdownMenuItem(value: choice, child: Text(_label(choice), style: const TextStyle(fontSize: 16)))],
          onChanged: (value) {
            if (value != null) onSort(value);
          },
        ),
        ChoiceChip(label: const Text('Ascending'), selected: !descending, onSelected: (_) => onDirection(false)),
        ChoiceChip(label: const Text('Descending'), selected: descending, onSelected: (_) => onDirection(true)),
      ]),
      if (status.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text(status, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: navy))),
    ]);
  }

  String _label(String key) => key;
}

List<Map<String, dynamic>> orderRows(List<Map<String, dynamic>> rows, {required String sortKey, required bool descending, required String query}) {
  final needle = query.trim().toLowerCase();
  final picked = rows.where((row) => needle.isEmpty || row['name'].toString().toLowerCase().contains(needle)).toList();
  int compare(Map<String, dynamic> a, Map<String, dynamic> b) {
    if (sortKey == 'Name' || sortKey == 'Sex' || sortKey == 'Result') {
      final left = _text(a, sortKey);
      final right = _text(b, sortKey);
      final order = left.compareTo(right);
      if (order != 0) return descending ? -order : order;
    } else {
      final left = _number(a, sortKey);
      final right = _number(b, sortKey);
      if (left == null && right == null) {
        // both missing
      } else if (left == null) {
        return 1;
      } else if (right == null) {
        return -1;
      } else if (left != right) {
        return descending ? right.compareTo(left) : left.compareTo(right);
      }
    }
    return a['name'].toString().toLowerCase().compareTo(b['name'].toString().toLowerCase());
  }

  picked.sort(compare);
  return picked;
}

String _text(Map<String, dynamic> row, String key) {
  if (key == 'Name') return row['name'].toString().toLowerCase();
  if (key == 'Sex') return row['sex'].toString();
  return row['result'].toString();
}

num? _number(Map<String, dynamic> row, String key) {
  if (key == 'No.' || key == 'Roll') {
    final roll = row['roll'];
    return roll is num ? roll : num.tryParse('$roll');
  }
  if (key == 'Average' || key == 'Total') {
    final value = row[key == 'Average' ? 'average' : 'total'];
    return value is num ? value : num.tryParse('$value');
  }
  if (key == 'Rank') return row['rank'] is num ? row['rank'] as num : null;
  final marks = row['marks'];
  if (marks is Map && marks[key] is Map) {
    final total = (marks[key] as Map)['total'];
    if (total is num) return total;
  }
  return null;
}

String oneDecimal(Object? value) {
  if (value is num) return value.toStringAsFixed(1);
  return '$value';
}

class MarksTable extends StatefulWidget {
  const MarksTable({super.key, required this.subjects, required this.rows, this.expand = true});
  final List<String> subjects;
  final List<Map<String, dynamic>> rows;
  final bool expand;

  @override
  State<MarksTable> createState() => _MarksTableState();
}

class _MarksTableState extends State<MarksTable> {
  final filter = TextEditingController();
  String sortKey = 'Average';
  bool descending = true;

  @override
  void dispose() {
    filter.dispose();
    super.dispose();
  }

  void _header(String key) {
    setState(() {
      if (sortKey == key) {
        descending = !descending;
      } else {
        sortKey = key;
        descending = key != 'Name' && key != 'Sex' && key != 'Result';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final shown = orderRows(widget.rows, sortKey: sortKey, descending: descending, query: filter.text);
    final columns = [
      const GridCol('No.', 48, TextAlign.center, sortKey: 'No.'),
      const GridCol('Student', 220, TextAlign.left, sortKey: 'Name'),
      const GridCol('Sex', 48, TextAlign.center, sortKey: 'Sex'),
      for (final subject in widget.subjects) GridCol(subject, 96, TextAlign.right, sortKey: subject),
      const GridCol('Total', 80, TextAlign.right, sortKey: 'Total'),
      const GridCol('Average', 80, TextAlign.right, sortKey: 'Average'),
      const GridCol('Rank', 64, TextAlign.center, sortKey: 'Rank'),
      const GridCol('Result', 80, TextAlign.center, sortKey: 'Result'),
    ];
    final lines = <List<String>>[
      for (final row in shown)
        [
          '${row['roll'] ?? ''}',
          row['dropped'] == true ? '${row['name']} (left)' : '${row['name']}',
          '${row['sex'] ?? ''}',
          for (final subject in widget.subjects) _mark(row, subject),
          '${row['total'] ?? ''}',
          row['dropped'] == true ? '—' : oneDecimal(row['average']),
          row['rank'] is num ? '${row['rank']}' : '—',
          '${row['result'] ?? ''}',
        ],
    ];
    final choices = ['Name', 'Average', ...widget.subjects];
    final bar = NameSortBar(
      filter: filter,
      sortKey: sortKey,
      choices: choices,
      descending: descending,
      onFilter: (_) => setState(() {}),
      onSort: (value) => setState(() {
        sortKey = value;
        descending = value != 'Name';
      }),
      onDirection: (down) => setState(() => descending = down),
      status: 'Showing ${shown.length} of ${widget.rows.length}',
    );
    final grid = DataGrid(columns: columns, rows: lines, expand: widget.expand, sortKey: sortKey, descending: descending, onSort: _header);
    if (!widget.expand) {
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [bar, const SizedBox(height: 8), grid]);
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      bar,
      const SizedBox(height: 8),
      Expanded(child: grid),
    ]);
  }

  String _mark(Map<String, dynamic> row, String subject) {
    final marks = row['marks'];
    if (marks is! Map || marks[subject] is! Map) return '—';
    final total = (marks[subject] as Map)['total'];
    if (total == null) return '—';
    return '$total';
  }
}
