import 'package:material_ui/material_ui.dart';

import 'theme.dart';

class GridCol {
  const GridCol(this.label, this.width, this.align, {this.sortKey, this.flex = false, this.pin = false});
  final String label;
  final double width;
  final TextAlign align;
  final String? sortKey;
  final bool flex;
  final bool pin;
  String get key => sortKey ?? label;
}

class GridLayout {
  const GridLayout(this.widths, this.scrolls);
  final List<double> widths;
  final bool scrolls;
  double get total => widths.fold(0, (sum, width) => sum + width);
}

const headerStyle = TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: ink, height: 1.15);
const _headerHeight = 64.0;
const _cellStyle = TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: ink);

double textWidth(String text, TextStyle style) {
  final painter = TextPainter(text: TextSpan(text: text, style: style), textDirection: TextDirection.ltr, maxLines: 1)..layout();
  return painter.width;
}

/// Preferred column widths. A single word that does not fit grows the column
/// so the header is never cut mid-word. Extra space goes to the flexible
/// column. Horizontal scrolling starts only when the preferred widths are
/// wider than [available].
GridLayout layoutGrid(double available, List<GridCol> columns, {double minFlex = 140}) {
  final widths = <double>[];
  for (final col in columns) {
    var width = col.width;
    final words = col.label.split(RegExp(r'\s+')).where((word) => word.isNotEmpty);
    if (words.length <= 1) {
      final need = textWidth(col.label, headerStyle) * 1.15 + 14;
      if (need > width) width = need;
    }
    widths.add(width);
  }
  var sum = widths.fold(0.0, (total, width) => total + width);
  // Leave a small safety margin so the last column is never clipped.
  final room = available.isFinite ? available - 48 : available;
  final flexAt = columns.indexWhere((col) => col.flex);
  if (room.isFinite && sum > room && flexAt >= 0) {
    // First give back spare space from the student name column, but never
    // below the longest name, so names are not cut.
    final give = (widths[flexAt] - minFlex).clamp(0.0, sum - room);
    widths[flexAt] -= give;
    sum -= give;
  }
  if (room.isFinite && sum > room) {
    // Then tighten the other columns, at most 20%, before scrolling.
    final fixed = flexAt >= 0 ? widths[flexAt] : 0.0;
    final scale = (room - fixed) / (sum - fixed);
    if (scale >= 0.8) {
      for (var i = 0; i < widths.length; i++) {
        if (i != flexAt) widths[i] = widths[i] * scale;
      }
      return GridLayout(widths, false);
    }
  }
  available = room;
  if (!available.isFinite || available <= 0 || sum > available + 0.5) {
    return GridLayout(widths, available.isFinite && sum > available + 0.5);
  }
  final flex = columns.indexWhere((col) => col.flex);
  if (flex >= 0) widths[flex] += available - sum;
  return GridLayout(widths, false);
}

String headerLabel(String label, double innerWidth) {
  if (textWidth(label, headerStyle) <= innerWidth) return label;
  final space = label.lastIndexOf(' ');
  if (space <= 0) return label;
  return '${label.substring(0, space)}\n${label.substring(space + 1)}';
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
  final _pinV = ScrollController();
  final _restV = ScrollController();
  var _lock = false;

  @override
  void initState() {
    super.initState();
    _head.addListener(() => _follow(_head, _body));
    _body.addListener(() => _follow(_body, _head));
    _pinV.addListener(() => _follow(_pinV, _restV));
    _restV.addListener(() => _follow(_restV, _pinV));
  }

  void _follow(ScrollController from, ScrollController to) {
    if (_lock || !to.hasClients || !from.hasClients) return;
    if ((to.offset - from.offset).abs() < 0.5) return;
    _lock = true;
    to.jumpTo(from.offset.clamp(0, to.position.maxScrollExtent));
    _lock = false;
  }

  @override
  void dispose() {
    _head.dispose();
    _body.dispose();
    _pinV.dispose();
    _restV.dispose();
    super.dispose();
  }

  int get _pinCount {
    var count = 0;
    for (final col in widget.columns) {
      if (!col.pin) break;
      count++;
    }
    return count;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final flexAt = widget.columns.indexWhere((col) => col.flex);
      var minFlex = 140.0;
      if (flexAt >= 0) {
        for (final row in widget.rows) {
          if (flexAt < row.length) {
            final need = textWidth(row[flexAt], _cellStyle) * 1.1 + 16;
            if (need > minFlex) minFlex = need;
          }
        }
      }
      final layout = layoutGrid(constraints.maxWidth, widget.columns, minFlex: minFlex);
      return Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: layout.scrolls ? _scrolled(layout) : _fitted(layout),
      );
    });
  }

  Widget _fitted(GridLayout layout) {
    return Column(children: [
      _header(layout.widths, 0, layout.widths.length),
      const Divider(height: 1, color: line),
      if (widget.expand)
        Expanded(child: ListView.builder(itemCount: widget.rows.length, itemBuilder: (context, i) => _bodyLine(layout.widths, 0, layout.widths.length, i)))
      else
        Column(children: [for (var i = 0; i < widget.rows.length; i++) _bodyLine(layout.widths, 0, layout.widths.length, i)]),
    ]);
  }

  Widget _scrolled(GridLayout layout) {
    final pin = _pinCount;
    final pinWidth = layout.widths.take(pin).fold(0.0, (sum, width) => sum + width);
    final restWidth = layout.widths.skip(pin).fold(0.0, (sum, width) => sum + width);
    final header = SizedBox(
      height: _headerHeight,
      child: Row(children: [
        _header(layout.widths, 0, pin),
        Expanded(
          child: SingleChildScrollView(
            controller: _head,
            scrollDirection: Axis.horizontal,
            child: _header(layout.widths, pin, layout.widths.length),
          ),
        ),
      ]),
    );
    if (!widget.expand) {
      return Column(children: [
        header,
        const Divider(height: 1, color: line),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: pinWidth, child: Column(children: [for (var i = 0; i < widget.rows.length; i++) _bodyLine(layout.widths, 0, pin, i)])),
          SingleChildScrollView(
            controller: _body,
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: restWidth,
              child: Column(children: [for (var i = 0; i < widget.rows.length; i++) _bodyLine(layout.widths, pin, layout.widths.length, i)]),
            ),
          ),
        ]),
      ]);
    }
    return Column(children: [
      header,
      const Divider(height: 1, color: line),
      Expanded(
        child: Row(children: [
          SizedBox(
            width: pinWidth,
            child: ListView.builder(controller: _pinV, itemCount: widget.rows.length, itemBuilder: (context, i) => _bodyLine(layout.widths, 0, pin, i)),
          ),
          Expanded(
            child: LayoutBuilder(builder: (context, constraints) {
              return Scrollbar(
                controller: _body,
                thumbVisibility: true,
                notificationPredicate: (note) => note.metrics.axis == Axis.horizontal,
                child: SingleChildScrollView(
                  controller: _body,
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: restWidth,
                    height: constraints.maxHeight,
                    child: ListView.builder(controller: _restV, itemCount: widget.rows.length, itemBuilder: (context, i) => _bodyLine(layout.widths, pin, layout.widths.length, i)),
                  ),
                ),
              );
            }),
          ),
        ]),
      ),
    ]);
  }

  Widget _header(List<double> widths, int start, int end) {
    return ColoredBox(
      color: const Color(0xFFE7EEF6),
      child: Row(children: [for (var i = start; i < end; i++) _headerCell(widget.columns[i], widths[i])]),
    );
  }

  Widget _headerCell(GridCol col, double width) {
    final sorted = widget.sortKey == col.key;
    final label = headerLabel(col.label, width - 8);
    return InkWell(
      onTap: widget.onSort == null ? null : () => widget.onSort!(col.key),
      child: SizedBox(
        width: width,
        height: _headerHeight,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: col.align == TextAlign.right
                  ? CrossAxisAlignment.end
                  : col.align == TextAlign.left
                      ? CrossAxisAlignment.start
                      : CrossAxisAlignment.center,
              children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(label, maxLines: 2, softWrap: false, textAlign: col.align, style: headerStyle),
            ),
            if (sorted) Icon(widget.descending ? Icons.arrow_downward : Icons.arrow_upward, size: 12, color: ink),
          ]),
        ),
      ),
    );
  }

  Widget _bodyLine(List<double> widths, int start, int end, int index) {
    final values = widget.rows[index];
    return ColoredBox(
      color: index.isOdd ? const Color(0xFFF7F9FC) : Colors.white,
      child: DecoratedBox(
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: line))),
        child: Row(children: [
          for (var i = start; i < end; i++)
            SizedBox(
              width: widths[i],
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                child: Text(
                  i < values.length ? values[i] : '',
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.fade,
                  textAlign: widget.columns[i].align,
                  style: _cellStyle,
                ),
              ),
            ),
        ]),
      ),
    );
  }
}
