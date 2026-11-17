import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import 'app_state.dart';
import 'demo_extra.dart';
import 'money.dart';
import 'office.dart';
import 'screens.dart';
import 'shell.dart';
import 'startup_log.dart';
import 'theme.dart';
import 'timetable_page.dart';
import 'widgets.dart';

List<DeskItem> erpMenu(AppModel model) {
  final items = <DeskItem>[];
  if (model.isAdmin || model.isDirector || model.isHomeroom) {
    items.add(const DeskItem('Students', Icons.groups_outlined, StudentsScreen()));
  }
  items.add(DeskItem('Marks & Results', Icons.grading_outlined, model.seesSchool ? const ResultsScreen() : const MarksScreen()));
  if (model.seesSchool) {
    items.add(const DeskItem('Attendance', Icons.event_busy_outlined, AbsenceScreen()));
  } else if (model.isHomeroom) {
    items.add(const DeskItem('Attendance', Icons.fact_check_outlined, AttendanceScreen()));
  }
  if (model.seesSchool || model.isHomeroom) {
    items.add(const DeskItem('Fees', Icons.payments_outlined, FeesScreen()));
  }
  if (model.isAdmin) items.add(const DeskItem('Staff', Icons.badge_outlined, StaffScreen()));
  items.add(const DeskItem('Timetable', Icons.calendar_month_outlined, TimetableScreen()));
  if (model.seesSchool) {
    items.add(const DeskItem('Reports', Icons.description_outlined, ReportScreen()));
  } else if (model.isHomeroom) {
    items.add(const DeskItem('Reports', Icons.badge_outlined, ReportCardScreen()));
  }
  if (model.isAdmin) items.add(const DeskItem('Money book', Icons.account_balance_wallet_outlined, MoneyScreen()));
  if (model.isDirector) items.add(const DeskItem('Meetings', Icons.groups_outlined, MeetingsScreen()));
  final settings = _settings(model);
  if (settings.isNotEmpty) items.add(DeskItem('Settings', Icons.settings_outlined, SettingsHub(items: settings)));
  return items;
}

List<DeskItem> _settings(AppModel model) {
  if (model.isAdmin) {
    return const [
      DeskItem('Set up school', Icons.tune, SetupScreen()),
      DeskItem('Notices', Icons.campaign_outlined, NoticeScreen()),
      DeskItem('Calendar', Icons.event_outlined, CalendarScreen()),
      DeskItem('Defaulters', Icons.warning_amber_outlined, DefaulterScreen()),
      DeskItem('Subjects', Icons.grid_on_outlined, MatrixScreen()),
      DeskItem('Promote', Icons.upgrade_outlined, PromoteScreen()),
      DeskItem('Backup', Icons.backup_outlined, BackupScreen()),
      DeskItem('Logins', Icons.person_add_outlined, UsersScreen()),
    ];
  }
  if (model.isDirector) {
    return const [
      DeskItem('Notices', Icons.campaign_outlined, NoticeScreen()),
      DeskItem('Calendar', Icons.event_outlined, CalendarScreen()),
    ];
  }
  return const [];
}

class SettingsHub extends StatelessWidget {
  const SettingsHub({super.key, required this.items});
  final List<DeskItem> items;

  @override
  Widget build(BuildContext context) {
    return SchoolScaffold(
      title: 'Settings',
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, i) {
          final item = items[i];
          return Card(
            child: ListTile(
              key: Key('action-${item.label}'),
              leading: Icon(item.icon, color: navy),
              title: Text(item.label, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => item.page)),
            ),
          );
        },
      ),
    );
  }
}

class ErpDashboard extends StatefulWidget {
  const ErpDashboard({super.key});
  @override
  State<ErpDashboard> createState() => _ErpDashboardState();
}

class _ErpDashboardState extends State<ErpDashboard> {
  Map<String, dynamic>? dash;
  Map<String, dynamic>? charts;
  int staff = 0;

  @override
  void initState() {
    super.initState();
    load();
    WidgetsBinding.instance.addPostFrameCallback((_) => openSmokePage());
  }

  void openSmokePage() {
    if (!mounted) return;
    final page = context.read<AppModel>().smokePage;
    const names = {
      'fees': 'Fees',
      'marks': 'Marks & Results',
      'results': 'Marks & Results',
      'students': 'Students',
      'staff': 'Staff',
      'attendance': 'Attendance',
      'timetable': 'Timetable',
      'reports': 'Reports',
    };
    final name = names[page];
    if (name == null) return;
    final host = DeskHost.of(context);
    final items = erpMenu(context.read<AppModel>());
    final index = items.indexWhere((item) => item.label == name);
    if (host != null && index >= 0) host.go(index + 1);
  }

  Future<void> load() async {
    final model = context.read<AppModel>();
    final watch = Stopwatch()..start();
    try {
      if (model.seesSchool) {
        final raw = await model.ask((api) => api.get('/api/v1/dashboard'));
        dash = (raw as Map).map((k, v) => MapEntry(k.toString(), v));
        final chartRaw = await model.ask((api) => api.get('/api/v1/charts'));
        charts = (chartRaw as Map).map((k, v) => MapEntry(k.toString(), v));
        final people = asMaps(await model.ask((api) => api.get('/api/v1/staff')));
        staff = people.length;
      }
    } catch (error, stack) {
      logStartup(error, stack);
    }
    logStartup('dashboard loaded ${watch.elapsedMilliseconds} ms');
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final model = context.watch<AppModel>();
    final head = (dash?['head'] as Map?) ?? {};
    final finance = (dash?['finance'] as Map?) ?? {};
    final male = charts?['male'] ?? head['male'] ?? '—';
    final female = charts?['female'] ?? head['female'] ?? '—';
    final students = head['students'] ?? ((male is num && female is num) ? male + female : '—');
    final grades = asMaps(charts?['pass_by_grade']);
    var promoted = 0;
    var sitting = 0;
    for (final grade in grades) {
      promoted += (grade['promoted'] as num?)?.toInt() ?? 0;
      sitting += (grade['students'] as num?)?.toInt() ?? 0;
    }
    final pass = sitting == 0 ? '—' : '${((promoted / sitting) * 100).round()}%';
    return SchoolScaffold(
      title: 'Dashboard',
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Good day, ${model.user['display_name'] ?? ''}', style: const TextStyle(fontSize: 16, color: Color(0xFF5C6B7A))),
          const SizedBox(height: 12),
          _kpis([
            _kpi('Students', '$students', 'Boys $male · Girls $female'),
            _kpi('Away today', '${dash?['absent_today'] ?? '—'}', 'Marked absent today'),
            _kpi('Fees collected', model.seesSchool ? nfk(finance['fees_collected']) : '—', model.seesSchool ? 'Still due ${nfk(finance['fees_remaining'])}' : 'Your class fees are under Fees'),
            _kpi('Pass rate', pass, 'Promoted $promoted of $sitting'),
            if (model.isAdmin) _kpi('Staff', '$staff', 'Teachers and office staff'),
          ]),
          const SizedBox(height: 16),
          if (grades.isNotEmpty)
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: _panel('Pass rate per grade', _gradeBars(grades, 'promoted', 'students'))),
              const SizedBox(width: 12),
              Expanded(child: _panel('Fees per grade', _feeBars(asMaps(charts?['fees_by_grade'])))),
            ]),
          if (!model.seesSchool) ...[
            const SizedBox(height: 8),
            const Text('Use the menu on the left. Each item opens one job.', style: TextStyle(fontSize: 16)),
          ],
        ],
      ),
    );
  }

  Widget _kpis(List<Widget> cards) {
    return LayoutBuilder(builder: (context, constraints) {
      final columns = constraints.maxWidth < 720 ? 2 : cards.length;
      const gap = 12.0;
      final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [for (final card in cards) SizedBox(width: width, child: card)],
      );
    });
  }

  Widget _kpi(String title, String value, String note) {
    return SizedBox(
      width: double.infinity,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontSize: 14, color: Color(0xFF5C6B7A))),
            const SizedBox(height: 6),
            Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: navy)),
            const SizedBox(height: 4),
            Text(note, style: const TextStyle(fontSize: 13)),
          ]),
        ),
      ),
    );
  }

  Widget _panel(String title, Widget child) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          child,
        ]),
      ),
    );
  }

  Widget _gradeBars(List<Map<String, dynamic>> grades, String part, String total) {
    return Column(children: [
      for (final grade in grades)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(children: [
            SizedBox(width: 64, child: Text('Grade ${grade['grade']}', style: const TextStyle(fontSize: 14))),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  minHeight: 10,
                  value: _ratio(grade[part], grade[total]),
                  backgroundColor: const Color(0xFFE6EDF5),
                  color: navy,
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(width: 64, child: Text('${grade[part]}/${grade[total]}', style: const TextStyle(fontSize: 13))),
          ]),
        ),
    ]);
  }

  Widget _feeBars(List<Map<String, dynamic>> grades) {
    var max = 1.0;
    for (final grade in grades) {
      final collected = (grade['collected'] as num?)?.toDouble() ?? 0;
      if (collected > max) max = collected;
    }
    return Column(children: [
      for (final grade in grades)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(children: [
            SizedBox(width: 64, child: Text('Grade ${grade['grade']}', style: const TextStyle(fontSize: 14))),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  minHeight: 10,
                  value: (((grade['collected'] as num?)?.toDouble() ?? 0) / max).clamp(0, 1),
                  backgroundColor: const Color(0xFFE6EDF5),
                  color: leaf,
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(width: 96, child: Text(nfk(grade['collected']), style: const TextStyle(fontSize: 13))),
          ]),
        ),
    ]);
  }

  double _ratio(Object? part, Object? total) {
    final p = (part as num?)?.toDouble() ?? 0;
    final t = (total as num?)?.toDouble() ?? 0;
    if (t <= 0) return 0;
    return (p / t).clamp(0, 1);
  }
}
