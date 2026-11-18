import 'package:material_ui/material_ui.dart';

import 'theme.dart';

class GridCol {
  const GridCol(this.label, this.width, this.align, {this.sortKey});
  final String label;
  final double width;
  final TextAlign align;
  final String? sortKey;
  String get key => sortKey ?? label;
}

class DataGrid extends StatefulWidget {
  const DataGrid({super.key, required this.columns, required this.rows, this.expand = true, this.sortKey, this.descending = false, this.onSort});
  final List<GridCol> columns;
  final List<List<String>> rows;
  final bool expand;
  final String? sortKey;
  final bool descending;
  final ValueChanged<String>? onSort;

  @override
  State<DataGrid> createState() => _DataGridState();
}

class _DataGridState extends State<DataGrid> {
  final _head = ScrollController();
  final _body = ScrollController();
  var _lock = false;

  @override
  void initState() {
    super.initState();
    _head.addListener(() => _follow(_head, _body));
    _body.addListener(() => _follow(_body, _head));
  }

  void _follow(ScrollController from, ScrollController to) {
    if (_lock || !to.hasClients || !from.hasClients) return;
    if (to.offset == from.offset) return;
    _lock = true;
    to.jumpTo(from.offset);
    _lock = false;
  }

  @override
  void dispose() {
    _head.dispose();
    _body.dispose();
    super.dispose();
  }

  double get _width => widget.columns.fold(0, (sum, col) => sum + col.width);

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(children: [
        ColoredBox(
          color: const Color(0xFFE7EEF6),
          child: SingleChildScrollView(
            controller: _head,
            scrollDirection: Axis.horizontal,
            child: _line(widget.columns.map((col) => col.label).toList(), head: true, stripe: false),
          ),
        ),
        const Divider(height: 1, color: line),
        if (widget.expand)
          Expanded(child: _bodyScroll())
        else
          SingleChildScrollView(
            controller: _body,
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: _width,
              child: Column(children: [
                for (var i = 0; i < widget.rows.length; i++) _line(widget.rows[i], head: false, stripe: i.isOdd),
              ]),
            ),
          ),
      ]),
    );
  }

  Widget _bodyScroll() {
    return Scrollbar(
      controller: _body,
      thumbVisibility: true,
      notificationPredicate: (note) => note.metrics.axis == Axis.horizontal,
      child: SingleChildScrollView(
        controller: _body,
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: _width,
          child: ListView.builder(
            itemCount: widget.rows.length,
            itemBuilder: (context, i) => _line(widget.rows[i], head: false, stripe: i.isOdd),
          ),
        ),
      ),
    );
  }

  Widget _cell(String text, GridCol col, {required bool head}) {
    final style = TextStyle(fontSize: head ? 12 : 14, fontWeight: head ? FontWeight.w800 : FontWeight.w600, color: ink);
    final label = Text(text, maxLines: 1, softWrap: false, overflow: TextOverflow.fade, textAlign: col.align, style: style);
    if (!head || widget.sortKey != col.key) return label;
    final arrow = Icon(widget.descending ? Icons.arrow_downward : Icons.arrow_upward, size: 14, color: ink);
    final end = col.align == TextAlign.right || col.align == TextAlign.end;
    final mid = col.align == TextAlign.center;
    return Row(
      mainAxisAlignment: end ? MainAxisAlignment.end : mid ? MainAxisAlignment.center : MainAxisAlignment.start,
      children: [
        Flexible(child: label),
        const SizedBox(width: 2),
        arrow,
      ],
    );
  }

  Widget _line(List<String> values, {required bool head, required bool stripe}) {
    return ColoredBox(
      color: head ? const Color(0xFFE7EEF6) : (stripe ? const Color(0xFFF7F9FC) : Colors.white),
      child: DecoratedBox(
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: line))),
        child: Row(children: [
          for (var i = 0; i < widget.columns.length; i++)
            SizedBox(
              width: widget.columns[i].width,
              child: InkWell(
                onTap: head && widget.onSort != null ? () => widget.onSort!(widget.columns[i].key) : null,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                  child: _cell(i < values.length ? values[i] : '', widget.columns[i], head: head),
                ),
              ),
            ),
        ]),
      ),
    );
  }
}
