import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import 'api.dart';
import 'app_state.dart';
import 'edition.dart';
import 'saved_files.dart';
import 'school_book.dart';
import 'shell.dart';
import 'money.dart';
import 'theme.dart';
import 'widgets.dart';

class GradeSummary extends StatefulWidget {
  const GradeSummary({super.key, required this.title, required this.kind, this.onOpenClass});

  final String title;
  final String kind;
  final void Function(Map<String, dynamic> cls)? onOpenClass;

  @override
  State<GradeSummary> createState() => _GradeSummaryState();
}

class _GradeSummaryState extends State<GradeSummary> {
  Map<String, dynamic>? data;
  Map<String, dynamic>? grade;
  List<Map<String, dynamic>> students = [];
  String? className;
  bool loading = true;
  String? error;
  String? note;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() { loading = true; error = null; });
    try {
      final path = widget.kind == 'fees' ? '/api/v1/summary/fees' : '/api/v1/summary/results';
      final raw = await context.read<AppModel>().ask((api) => api.get(path));
      data = (raw as Map).map((k, v) => MapEntry(k.toString(), v));
    } on ApiException catch (e) {
      error = e.message;
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> openClass(Map<String, dynamic> cls) async {
    if (widget.onOpenClass != null) {
      widget.onOpenClass!(cls);
      return;
    }
    setState(() => loading = true);
    try {
      students = asMaps(await context.read<AppModel>().ask((api) => api.get('/api/v1/fees?class_id=${cls['id']}')));
      className = cls['name']?.toString();
      error = null;
    } on ApiException catch (e) {
      error = e.message;
    }
    if (mounted) setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final school = context.watch<AppModel>().school;
    final grades = asMaps(data?['grades']);
    return SchoolScaffold(
      title: className ?? (grade == null ? widget.title : grade!['name'].toString()),
      school: school,
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : error != null
              ? ErrorNote(error!, load)
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (className != null) ...[
                      TextButton(onPressed: () => setState(() { className = null; students = []; }), child: const Text('Back to sections')),
                      for (final s in students) _feeStudent(s),
                    ] else if (grade != null) ...[
                      TextButton(onPressed: () => setState(() => grade = null), child: const Text('All grades')),
                      for (final section in asMaps(grade!['sections']))
                        _card(
                          section['name'].toString(),
                          widget.kind == 'fees'
                              ? 'Open the students'
                              : 'Promoted ${section['promoted']} · Failed ${section['failed']} · Left ${section['dropouts']}',
                          () => widget.kind == 'fees'
                              ? openClass(section)
                              : widget.onOpenClass?.call({'id': section['id'], 'name': section['name']}),
                        ),
                    ] else ...[
                      _totalCard(),
                      const SizedBox(height: 8),
                      if (widget.kind == 'results' && context.watch<AppModel>().isAdmin)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: FilledButton(onPressed: makeStats, child: const Text('Make statistics PDFs')),
                        ),
                      if (note != null) Text(note!, style: const TextStyle(fontSize: 16)),
                      for (final g in grades)
                        _card(
                          g['name']?.toString() ?? 'Grade',
                          widget.kind == 'fees'
                              ? 'Collected ${nfk(g['collected'])} · Left ${nfk(g['remaining'])} · ${g['students']} students'
                              : 'Promoted ${g['promoted']} · Failed ${g['failed']} · Left ${g['dropouts']} · ${g['students']} students',
                          () => setState(() => grade = g),
                        ),
                      if (grades.isEmpty) const EmptyNote('No grades yet. Add a class first.'),
                    ],
                  ],
                ),
    );
  }

  Widget _totalCard() {
    if (widget.kind == 'fees') {
      return _card('Whole school', 'Collected ${nfk(data?['collected'])} · Left ${nfk(data?['remaining'])} · ${data?['students'] ?? 0} students', null, color: leaf);
    }
    return _card('Whole school', 'Promoted ${data?['promoted'] ?? 0} · Failed ${data?['failed'] ?? 0} · Left ${data?['dropouts'] ?? 0}', null, color: leaf);
  }

  Widget _card(String title, String subtitle, VoidCallback? onTap, {Color color = ink}) {
    return Card(
      child: ListTile(
        key: Key('row-$title'),
        title: Text(title, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: color)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 16)),
        trailing: onTap == null ? null : const Icon(Icons.chevron_right, size: 32),
        onTap: onTap,
      ),
    );
  }

  Future<void> makeStats() async {
    setState(() => note = 'Making the statistics…');
    try {
      if (demoEdition && Platform.environment['FLUTTER_TEST'] == 'true') {
        final book = SchoolBook.instance;
        book.callNow('POST', '/api/v1/semester/close', {});
        final list = book.callNow('GET', '/api/v1/reports/semester', null) as List;
        final dir = Directory('${Directory.systemTemp.path}/SchoolDesk/stats');
        dir.createSync(recursive: true);
        for (final item in list) {
          final row = Map<String, dynamic>.from(item as Map);
          final bytes = book.callNow('GET', '/api/v1/reports/semester/${row['id']}', null) as List<int>;
          File('${dir.path}/${row['title']}.pdf').writeAsBytesSync(bytes);
        }
        if (!mounted) return;
        setState(() => note = 'Statistics saved');
        saved(context, 'Statistics saved');
        return;
      }
      final model = context.read<AppModel>();
      await model.ask((api) => api.post('/api/v1/semester/close', {}));
      final list = asMaps(await model.ask((api) => api.get('/api/v1/reports/semester')));
      final dir = await reportFolder();
      for (final item in list) {
        final bytes = await model.api!.bytes('/api/v1/reports/semester/${item['id']}');
        final name = (item['title'] ?? 'stats').toString().replaceAll(' ', '-');
        await File('${dir.path}/$name.pdf').writeAsBytes(bytes);
      }
      if (!mounted) return;
      setState(() => note = 'Statistics saved');
      saved(context, 'Statistics saved');
    } catch (e) {
      if (!mounted) return;
      setState(() => note = '$e');
      toast(context, '$e');
    }
  }

  Widget _feeStudent(Map<String, dynamic> row) {
    final left = (row['remaining'] as num?) ?? 0;
    return Card(
      child: ListTile(
        title: Text(row['full_name'].toString(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        subtitle: Text('Paid ${nfk(row['paid'])} · Left ${nfk(row['remaining'])}', style: TextStyle(fontSize: 16, color: left == 0 ? passGreen : failRed, fontWeight: FontWeight.w700)),
      ),
    );
  }
}
