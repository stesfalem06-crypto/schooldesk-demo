import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import 'app_state.dart';
import 'startup_log.dart';
import 'demo_extra.dart';
import 'demo_look.dart';
import 'office.dart';
import 'screens.dart';
import 'shell.dart';
import 'theme.dart';
import 'widgets.dart';

class DemoHome extends StatefulWidget {
  const DemoHome({super.key});
  @override
  State<DemoHome> createState() => _DemoHomeState();
}

class _DemoHomeState extends State<DemoHome> {
  Map<String, dynamic>? charts;
  List<Map<String, dynamic>> classes = [];
  List<Map<String, dynamic>> upcoming = [];

  @override
  void initState() {
    super.initState();
    load();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      openSmokePage();
      noteLayout();
    });
  }

  void noteLayout() {
    if (!mounted) return;
    final box = context.findRenderObject();
    final size = box is RenderBox ? box.size : Size.zero;
    final window = MediaQuery.sizeOf(context);
    logStartup('home laid out ${size.width.toStringAsFixed(0)}x${size.height.toStringAsFixed(0)} in a ${window.width.toStringAsFixed(0)}x${window.height.toStringAsFixed(0)} window');
    if (size.height < 40) logStartup('home body has no height, so the page cannot paint');
  }

  void openSmokePage() {
    if (!mounted) return;
    final page = context.read<AppModel>().smokePage;
    Widget? screen;
    if (page == 'fees') screen = const FeesScreen();
    if (page == 'marks') screen = const MarksScreen();
    if (page == 'results') screen = const ResultsScreen();
    if (screen == null) return;
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen!));
  }

  Future<void> load() async {
    final model = context.read<AppModel>();
    try {
      if (model.seesSchool) charts = Map<String, dynamic>.from(await model.ask((api) => api.get('/api/v1/charts')) as Map);
      classes = asMaps(await model.ask((api) => api.get('/api/v1/classes')));
      upcoming = asMaps(await model.ask((api) => api.get('/api/v1/calendar')));
    } catch (_) {}
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final model = context.watch<AppModel>();
    final actions = _actions(model);
    final wide = MediaQuery.sizeOf(context).width > 900;
    return SchoolScaffold(
      title: '',
      school: '',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        children: [
          HelloBar(onSearch: (q) => Navigator.push(context, MaterialPageRoute(builder: (_) => SearchScreen(query: q)))),
          const SizedBox(height: 14),
          if (wide)
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(flex: 3, child: _hero(context)),
              const SizedBox(width: 12),
              Expanded(flex: 2, child: Column(children: [_todayCard(), const SizedBox(height: 12), _upcoming()])),
            ])
          else ...[
            _hero(context),
            const SizedBox(height: 12),
            _todayCard(),
            const SizedBox(height: 12),
            _upcoming(),
          ],
          const SizedBox(height: 16),
          const Text('Classes', style: TextStyle(fontFamily: 'Georgia', fontSize: 26, fontWeight: FontWeight.w700, color: navy)),
          const Text('Each section, with its teacher', style: TextStyle(fontSize: 15, color: Color(0xFF6D7C8A))),
          const SizedBox(height: 8),
          SizedBox(
            height: 168,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final cls in classes.take(8)) _classCard(cls),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Wrap(spacing: 10, runSpacing: 10, children: [
            for (final item in actions) _pastel(context, item),
          ]),
          const SizedBox(height: 16),
          if (wide)
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: _quote()),
              const SizedBox(width: 12),
              Expanded(flex: 2, child: _chartCard()),
            ])
          else ...[
            _quote(),
            const SizedBox(height: 12),
            _chartCard(),
          ],
        ],
      ),
    );
  }

  List<DeskItem> _actions(AppModel model) {
    final items = <DeskItem>[...rolePages(model)];
    if (model.isAdmin) {
      items.addAll(const [
        DeskItem('Money book', Icons.account_balance_wallet, MoneyScreen()),
        DeskItem('Staff list', Icons.badge, StaffScreen()),
        DeskItem('Set up school', Icons.tune, SetupScreen()),
        DeskItem('Notices', Icons.campaign, NoticeScreen()),
        DeskItem('Calendar', Icons.event, CalendarScreen()),
        DeskItem('Defaulters', Icons.warning_amber, DefaulterScreen()),
        DeskItem('Subjects', Icons.grid_on, MatrixScreen()),
        DeskItem('Promote', Icons.upgrade, PromoteScreen()),
      ]);
    } else if (model.isDirector) {
      items.addAll(const [
        DeskItem('Make report', Icons.description, ReportScreen()),
        DeskItem('Notices', Icons.campaign, NoticeScreen()),
        DeskItem('Calendar', Icons.event, CalendarScreen()),
      ]);
    } else if (model.isHomeroom) {
      items.addAll(const [
        DeskItem('Attendance', Icons.fact_check, AttendanceScreen()),
        DeskItem('Report cards', Icons.badge, ReportCardScreen()),
      ]);
    }
    return items;
  }

  Widget _hero(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.only(topLeft: Radius.circular(36), topRight: Radius.circular(84), bottomLeft: Radius.circular(72), bottomRight: Radius.circular(28)),
      child: Stack(children: [
        Image.asset('assets/hero-school.webp', height: 250, width: double.infinity, fit: BoxFit.cover),
        Positioned.fill(
          child: DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.bottomLeft, end: Alignment.topRight, colors: [navy.withValues(alpha: 0.55), Colors.transparent]))),
        ),
        Positioned(
          left: 18,
          right: 18,
          bottom: 16,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('TODAY AT HOPE ACADEMY', style: TextStyle(color: Colors.white, fontSize: 12, letterSpacing: 1.1, fontWeight: FontWeight.w800)),
            const Text('A calm day at school', style: TextStyle(fontFamily: 'Georgia', color: Colors.white, fontSize: 30, fontWeight: FontWeight.w700)),
            const Text('Open a class, the fees, or the week.', style: TextStyle(color: Colors.white, fontSize: 16)),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FeesScreen())),
              icon: const Icon(Icons.arrow_forward),
              label: const Text('See fees'),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _todayCard() {
    final male = charts?['male'] ?? '—';
    final female = charts?['female'] ?? '—';
    return SoftCard(
      radius: 32,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Today', style: TextStyle(fontFamily: 'Georgia', fontSize: 22, fontWeight: FontWeight.w700, color: navy)),
        Text('$male boys · $female girls', style: const TextStyle(fontSize: 16)),
        const Text('Term 1 · Hope Academy', style: TextStyle(fontSize: 15, color: Color(0xFF6D7C8A))),
      ]),
    );
  }

  Widget _upcoming() {
    final next = upcoming.isEmpty ? null : upcoming.last;
    return SoftCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Upcoming', style: TextStyle(fontFamily: 'Georgia', fontSize: 22, fontWeight: FontWeight.w700, color: navy)),
        Text(next?['title']?.toString() ?? 'Nothing dated', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        Text(next?['date']?.toString() ?? '', style: const TextStyle(fontSize: 16)),
      ]),
    );
  }

  Widget _classCard(Map<String, dynamic> cls) {
    final art = (cls['grade'] as num? ?? 0) % 2 == 0 ? 'assets/class-room.webp' : 'assets/school-yard.webp';
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: SizedBox(
        width: 180,
        child: SoftCard(
          padding: EdgeInsets.zero,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
              child: Image.asset(art, height: 78, width: 180, fit: BoxFit.cover),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(cls['name'].toString(), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: navy)),
                  Text(cls['homeroom_name']?.toString() ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
                ])),
                const CircleAvatar(radius: 14, backgroundColor: navy, child: Icon(Icons.chevron_right, color: Colors.white, size: 18)),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _pastel(BuildContext context, DeskItem item) {
    const tones = [Color(0xFFD9E8F5), Color(0xFFF8E3C8), Color(0xFFDDEEDD), Color(0xFFF6D9E4), Color(0xFFE4DDF6)];
    final tone = tones[item.label.length % tones.length];
    return SizedBox(
      key: Key('action-${item.label}'),
      width: 108,
      child: InkWell(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => item.page)),
        child: Column(children: [
          CircleAvatar(radius: 28, backgroundColor: tone, child: Icon(item.icon, color: navy, size: 26)),
          const SizedBox(height: 6),
          Text(item.label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: navyInk)),
        ]),
      ),
    );
  }

  Widget _quote() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: Stack(children: [
        Image.asset('assets/school-yard.webp', height: 180, width: double.infinity, fit: BoxFit.cover),
        Positioned.fill(child: Container(color: navy.withValues(alpha: 0.35))),
        const Positioned(left: 16, right: 16, bottom: 16, child: Text('“A kind word in class lasts all year.”', style: TextStyle(fontFamily: 'Georgia', color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700))),
      ]),
    );
  }

  Widget _chartCard() {
    final grades = asMaps(charts?['pass_by_grade']);
    return SoftCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Pass by grade', style: TextStyle(fontFamily: 'Georgia', fontSize: 22, fontWeight: FontWeight.w700, color: navy)),
        const SizedBox(height: 8),
        SizedBox(height: 120, child: _bars(grades)),
        const SizedBox(height: 8),
        ClipRRect(borderRadius: BorderRadius.circular(18), child: Image.asset('assets/campus-map.webp', height: 90, width: double.infinity, fit: BoxFit.cover)),
      ]),
    );
  }

  Widget _bars(List<Map<String, dynamic>> grades) {
    if (grades.isEmpty) return const Text('Open results to see the chart');
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (final g in grades)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                Expanded(
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: FractionallySizedBox(
                      heightFactor: (((g['promoted'] as num?) ?? 0) / ((((g['students'] as num?) ?? 1) == 0) ? 1 : (g['students'] as num))).clamp(0.05, 1).toDouble(),
                      child: Container(decoration: BoxDecoration(color: navy, borderRadius: BorderRadius.circular(8))),
                    ),
                  ),
                ),
                Text('${g['grade']}', style: const TextStyle(fontSize: 11)),
              ]),
            ),
          ),
      ],
    );
  }
}
