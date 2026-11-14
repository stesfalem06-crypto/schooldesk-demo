import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'api.dart';
import 'app_state.dart';
import 'edition.dart';
import 'grades.dart';
import 'marks_grid.dart';
import 'timetable_page.dart';
import 'office.dart';
import 'shell.dart';
import 'theme.dart';
import 'widgets.dart';

class ConnectScreen extends StatefulWidget {
  const ConnectScreen({super.key});
  @override
  State<ConnectScreen> createState() => _ConnectScreenState();
}

class _ConnectScreenState extends State<ConnectScreen> {
  final ip = TextEditingController();
  List<String> found = [];
  bool looking = false;
  String? problem;

  Future<void> search() async {
    setState(() { looking = true; problem = null; });
    final list = await SchoolApi.find();
    setState(() { looking = false; found = list; if (list.isEmpty) problem = 'No school computer answered. Type its number.'; });
  }

  @override
  Widget build(BuildContext context) {
    return SchoolScaffold(
      title: 'Find the school',
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('The school computer must be on.', style: TextStyle(fontSize: 18)),
          const SizedBox(height: 12),
          FilledButton.icon(onPressed: looking ? null : search, icon: const Icon(Icons.wifi_find), label: Text(looking ? 'Looking…' : 'Find the school')),
          if (problem != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(problem!, style: const TextStyle(color: failRed, fontSize: 16))),
          for (final host in found)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: FilledButton(onPressed: () => context.read<AppModel>().setBase(host), child: Text(host)),
            ),
          const SizedBox(height: 18),
          TextField(controller: ip, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Or type the number, like 192.168.1.20')),
          const SizedBox(height: 8),
          FilledButton(onPressed: () => context.read<AppModel>().setBase(ip.text), child: const Text('Open')),
        ],
      ),
    );
  }
}

class LockScreen extends StatefulWidget {
  const LockScreen({super.key});
  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  final code = TextEditingController();
  String? problem;

  @override
  void initState() {
    super.initState();
    context.read<AppModel>().refreshLicense();
  }

  @override
  Widget build(BuildContext context) {
    final model = context.watch<AppModel>();
    return SchoolScaffold(
      title: 'Locked',
      school: model.school,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(model.lockMessage, style: const TextStyle(fontSize: 20)),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(children: [
                const Text('School computer number', style: TextStyle(fontSize: 16)),
                const SizedBox(height: 6),
                Text(model.machineId.isEmpty ? '…' : model.machineId, textAlign: TextAlign.center, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: leaf, letterSpacing: 1)),
                const SizedBox(height: 8),
                if (model.qrPayload.isNotEmpty) QrImageView(data: model.qrPayload, size: 200),
              ]),
            ),
          ),
          const SizedBox(height: 12),
          TextField(controller: code, decoration: const InputDecoration(labelText: 'Unlock code')),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: () async {
              final msg = await model.unlock(code.text);
              if (msg != null && context.mounted) setState(() => problem = msg);
            },
            child: const Text('Unlock'),
          ),
          if (problem != null) Text(problem!, style: const TextStyle(color: failRed, fontSize: 16)),
          TextButton(onPressed: model.forget, child: const Text('Use a different computer')),
        ],
      ),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final name = TextEditingController();
  final pass = TextEditingController();
  String? problem;
  bool busy = false;

  @override
  Widget build(BuildContext context) {
    final model = context.watch<AppModel>();
    return SchoolScaffold(
      title: 'Sign in',
      school: model.school,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Icon(Icons.school, size: 72, color: leaf),
          const SizedBox(height: 12),
          TextField(controller: name, decoration: const InputDecoration(labelText: 'Your name')),
          const SizedBox(height: 10),
          TextField(controller: pass, obscureText: true, decoration: const InputDecoration(labelText: 'Password')),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: busy
                ? null
                : () async {
                    setState(() { busy = true; problem = null; });
                    final msg = await model.signIn(name.text.trim(), pass.text);
                    if (context.mounted) setState(() { busy = false; problem = msg; });
                  },
            child: Text(busy ? 'Opening…' : 'Go in'),
          ),
          if (problem != null) Text(problem!, style: const TextStyle(color: failRed, fontSize: 16)),
          if (demoEdition) ...[
            const SizedBox(height: 18),
            const Text('Open a sample role', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            _DemoRole(label: 'Admin', username: 'admin', password: 'admin1850', busy: busy, onDone: (msg) => setState(() { busy = false; problem = msg; }), onStart: () => setState(() { busy = true; problem = null; })),
            _DemoRole(label: 'Director', username: 'director', password: 'director1850', busy: busy, onDone: (msg) => setState(() { busy = false; problem = msg; }), onStart: () => setState(() { busy = true; problem = null; })),
            _DemoRole(label: 'Homeroom teacher', username: 'dawit', password: 'dawit1850', busy: busy, onDone: (msg) => setState(() { busy = false; problem = msg; }), onStart: () => setState(() { busy = true; problem = null; })),
            _DemoRole(label: 'Subject teacher', username: 'meron', password: 'meron1850', busy: busy, onDone: (msg) => setState(() { busy = false; problem = msg; }), onStart: () => setState(() { busy = true; problem = null; })),
            _DemoRole(label: 'Class and subject', username: 'samuel', password: 'samuel1850', busy: busy, onDone: (msg) => setState(() { busy = false; problem = msg; }), onStart: () => setState(() { busy = true; problem = null; })),
          ],
        ],
      ),
    );
  }
}

class _DemoRole extends StatelessWidget {
  const _DemoRole({required this.label, required this.username, required this.password, required this.busy, required this.onStart, required this.onDone});

  final String label;
  final String username;
  final String password;
  final bool busy;
  final VoidCallback onStart;
  final void Function(String?) onDone;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: OutlinedButton(
        onPressed: busy
            ? null
            : () async {
                onStart();
                final msg = await context.read<AppModel>().signIn(username, password);
                if (context.mounted) onDone(msg);
              },
        child: Text(label),
      ),
    );
  }
}

List<DeskItem> rolePages(AppModel model) {
  if (model.seesSchool) {
    final items = <DeskItem>[
      const DeskItem('See fees', Icons.payments, FeesScreen()),
      const DeskItem('See results', Icons.leaderboard, ResultsScreen()),
      const DeskItem('Who is away', Icons.event_busy, AbsenceScreen()),
      const DeskItem('Plan week', Icons.calendar_month, TimetableScreen()),
    ];
    if (model.isDirector) items.add(const DeskItem('Meetings', Icons.groups, MeetingsScreen()));
    return items;
  }
  if (model.isHomeroom) {
    return const [
      DeskItem('My class', Icons.groups, StudentsScreen()),
      DeskItem('Enter marks', Icons.edit, MarksScreen()),
      DeskItem('Take fees', Icons.payments, FeesScreen()),
      DeskItem('See results', Icons.leaderboard, ResultsScreen()),
      DeskItem('Plan week', Icons.calendar_month, TimetableScreen()),
    ];
  }
  return const [
    DeskItem('Enter marks', Icons.edit, MarksScreen()),
    DeskItem('My week', Icons.calendar_month, TimetableScreen()),
  ];
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Map<String, dynamic>? dash;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final model = context.read<AppModel>();
    if (!model.seesSchool) return;
    try {
      final raw = await model.ask((api) => api.get('/api/v1/dashboard'));
      dash = (raw as Map).map((k, v) => MapEntry(k.toString(), v));
      if (mounted) setState(() {});
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final model = context.watch<AppModel>();
    final items = rolePages(model);
    final extra = <DeskItem>[];
    if (model.isAdmin) {
      extra.addAll(const [
        DeskItem('Set up school', Icons.tune, SetupScreen()),
        DeskItem('Money book', Icons.account_balance_wallet, MoneyScreen()),
        DeskItem('Staff list', Icons.badge, StaffScreen()),
        DeskItem('Backup', Icons.backup, BackupScreen()),
        DeskItem('Logins', Icons.person_add, UsersScreen()),
      ]);
    } else if (model.isDirector) {
      extra.add(const DeskItem('Make report', Icons.description, ReportScreen()));
    }
    final head = (dash?['head'] as Map?) ?? {};
    final finance = (dash?['finance'] as Map?) ?? {};
    final tiles = <Widget>[
      for (final item in [...items, ...extra])
        BigTile(icon: item.icon, label: item.label, color: leaf, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => item.page))),
    ];
    return SchoolScaffold(
      title: model.user['display_name']?.toString() ?? 'Home',
      hint: 'Tap a big tile. You can always come back here.',
      school: model.school,
      actions: [
        IconButton(tooltip: 'Leave', onPressed: model.signOut, icon: const Icon(Icons.logout, size: 28)),
      ],
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (model.seesSchool)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Wrap(spacing: 24, runSpacing: 8, children: [
                  Text('Students ${head['students'] ?? '…'}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                  Text('Fees in ${finance['fees_collected'] ?? '…'}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: passGreen)),
                  Text('Still to pay ${finance['fees_remaining'] ?? '…'}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                  Text('Away today ${dash?['absent_today'] ?? '…'}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: failRed)),
                ]),
              ),
            ),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: MediaQuery.sizeOf(context).width > 700 ? 3 : 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.15,
            children: tiles,
          ),
        ],
      ),
    );
  }
}

class MarksScreen extends StatefulWidget {
  const MarksScreen({super.key});
  @override
  State<MarksScreen> createState() => _MarksScreenState();
}

class _MarksScreenState extends State<MarksScreen> {
  List<Map<String, dynamic>> subjects = [];
  String? error;
  bool loading = true;

  @override
  void initState() { super.initState(); load(); }

  Future<void> load() async {
    setState(() { loading = true; error = null; });
    try {
      final data = await context.read<AppModel>().ask((api) => api.get('/api/v1/class-subjects'));
      subjects = asMaps(data);
    } on ApiException catch (e) {
      error = e.message;
    }
    if (context.mounted) setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return SchoolScaffold(
      title: 'Marks',
      school: context.watch<AppModel>().school,
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : error != null
              ? ErrorNote(error!, load)
              : subjects.isEmpty
                  ? const EmptyNote('No subjects yet.')
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        const Text('Choose a subject. A red total means the exam is low.', style: TextStyle(fontSize: 16)),
                        const SizedBox(height: 8),
                        for (final s in subjects)
                          Card(
                            child: ListTile(
                              leading: const Icon(Icons.menu_book, color: leaf, size: 32),
                              title: Text('${s['class_name']} · ${s['subject_name']}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => MarkGridScreen(subject: s))),
                            ),
                          ),
                      ],
                    ),
    );
  }
}

class AssessmentsScreen extends StatefulWidget {
  const AssessmentsScreen({super.key, required this.subject});
  final Map<String, dynamic> subject;
  @override
  State<AssessmentsScreen> createState() => _AssessmentsScreenState();
}

class _AssessmentsScreenState extends State<AssessmentsScreen> {
  List<Map<String, dynamic>> items = [];
  bool loading = true;
  String? error;

  @override
  void initState() { super.initState(); load(); }

  Future<void> load() async {
    try {
      final data = await context.read<AppModel>().ask((api) => api.get('/api/v1/assessments?class_subject_id=${widget.subject['id']}'));
      items = asMaps(data);
      error = null;
    } on ApiException catch (e) {
      error = e.message;
    }
    if (context.mounted) setState(() => loading = false);
  }

  Future<void> add(int half) async {
    final title = half == 1 ? 'First half mark' : 'Second half mark';
    try {
      await context.read<AppModel>().ask((api) => api.post('/api/v1/assessments', {
            'class_subject_id': widget.subject['id'],
            'component': 'classwork',
            'half': half,
            'title': title,
            'max_marks': 10,
          }));
      await load();
    } on ApiException catch (e) {
      if (context.mounted) toast(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SchoolScaffold(
      title: widget.subject['subject_name']?.toString() ?? 'Marks',
      school: context.watch<AppModel>().school,
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : error != null
              ? ErrorNote(error!, load)
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (widget.subject['can_edit'] == true)
                      Row(children: [
                        Expanded(child: FilledButton(onPressed: () => add(1), child: const Text('First half'))),
                        const SizedBox(width: 8),
                        Expanded(child: FilledButton(onPressed: () => add(2), child: const Text('Second half'))),
                      ])
                    else
                      const Padding(padding: EdgeInsets.only(bottom: 8), child: Text('You can look. Only the subject teacher changes these marks.', style: TextStyle(fontSize: 16))),
                    const SizedBox(height: 8),
                    for (final a in items)
                      Card(
                        child: ListTile(
                          title: Text(a['title']?.toString() ?? '', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                          subtitle: Text(a['component'] == 'exam' ? 'Exam out of 40' : 'Half ${a['half']} · out of ${a['max_marks']}'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ScoreScreen(subject: widget.subject, assessment: a))),
                        ),
                      ),
                  ],
                ),
    );
  }
}

class ScoreScreen extends StatefulWidget {
  const ScoreScreen({super.key, required this.subject, required this.assessment});
  final Map<String, dynamic> subject;
  final Map<String, dynamic> assessment;
  @override
  State<ScoreScreen> createState() => _ScoreScreenState();
}

class _ScoreScreenState extends State<ScoreScreen> {
  List<Map<String, dynamic>> students = [];
  Map<String, Map<String, dynamic>> scores = {};
  bool loading = true;
  String? error;

  @override
  void initState() { super.initState(); load(); }

  Future<void> load() async {
    final model = context.read<AppModel>();
    try {
      final people = await model.ask((api) => api.get('/api/v1/students?class_id=${widget.subject['class_id']}'));
      final marks = await model.ask((api) => api.get('/api/v1/scores?assessment_id=${widget.assessment['id']}'));
      students = asMaps(people);
      scores = {for (final s in asMaps(marks)) s['student_id'].toString(): s};
      error = null;
    } on ApiException catch (e) {
      error = e.message;
    }
    if (context.mounted) setState(() => loading = false);
  }

  Future<void> enter(Map<String, dynamic> student) async {
    final model = context.read<AppModel>();
    final current = scores[student['id'].toString()];
    final value = await askNumber(context, student['full_name'].toString(), hint: 'Out of ${widget.assessment['max_marks']}', initial: current?['score']?.toString() ?? '');
    if (value == null) return;
    final body = {
      'assessment_id': widget.assessment['id'],
      'student_id': student['id'],
      'score': value,
      'base_revision': current?['revision'] ?? 0,
    };
    try {
      final saved = await model.ask((api) => api.post('/api/v1/scores', body));
      if (saved is Map) scores[student['id'].toString()] = saved.map((k, v) => MapEntry(k.toString(), v));
      if (context.mounted) setState(() {});
    } on ApiException catch (e) {
      if (e.status == 0 || e.message.contains('not on this network')) {
        await model.queueScore(body);
        if (context.mounted) toast(context, 'Saved on this phone. It will go to school when the network is back.');
      } else if (context.mounted) {
        toast(context, e.message);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final model = context.watch<AppModel>();
    return SchoolScaffold(
      title: widget.assessment['title']?.toString() ?? 'Marks',
      school: model.school,
      actions: [
        if (widget.subject['can_edit'] == true)
        IconButton(
          tooltip: 'Undo',
          onPressed: () async {
            try {
              await model.ask((api) => api.post('/api/v1/scores/undo', {}));
              await load();
              if (context.mounted) toast(context, 'Last mark undone');
            } on ApiException catch (e) {
              if (context.mounted) toast(context, e.message);
            }
          },
          icon: const Icon(Icons.undo, size: 28),
        ),
      ],
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : error != null
              ? ErrorNote(error!, load)
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (model.outbox.isNotEmpty)
                      Card(color: const Color(0xFFFFF4D6), child: ListTile(title: Text('${model.outbox.length} marks waiting to send'), trailing: FilledButton(onPressed: () async {
                        final msgs = await model.flush();
                        if (context.mounted) toast(context, msgs.isEmpty ? 'Sent' : msgs.join(' '));
                        await load();
                      }, child: const Text('Send')))),
                    for (final s in students)
                      if (s['dropped_out'] != true)
                        Card(
                          child: ListTile(
                            title: Text(s['full_name'].toString(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                            trailing: Text(
                              scores[s['id'].toString()]?['score']?.toString() ?? '—',
                              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: scores[s['id'].toString()]?['score'] == null ? ink : passGreen),
                            ),
                            onTap: () async {
                        if (widget.subject['can_edit'] != true) {
                          toast(context, 'Only the subject teacher can change this mark.');
                          return;
                        }
                        await enter(s);
                      },
                          ),
                        ),
                  ],
                ),
    );
  }
}

class ResultsScreen extends StatefulWidget {
  const ResultsScreen({super.key});
  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen> {
  List<Map<String, dynamic>> classes = [];
  Map<String, dynamic>? picked;
  bool loading = true;
  String? error;

  @override
  void initState() { super.initState(); loadClasses(); }

  Future<void> loadClasses() async {
    try {
      final model = context.read<AppModel>();
      classes = asMaps(await model.ask((api) => api.get('/api/v1/classes')));
      error = null;
      if (!model.seesSchool && classes.length == 1) await open(classes.first);
    } on ApiException catch (e) {
      error = e.message;
    }
    if (context.mounted) setState(() => loading = false);
  }

  Future<void> open(Map<String, dynamic> cls) async {
    setState(() => loading = true);
    try {
      final data = await context.read<AppModel>().ask((api) => api.get('/api/v1/classes/${cls['id']}/results'));
      picked = (data as Map).map((k, v) => MapEntry(k.toString(), v));
      error = null;
    } on ApiException catch (e) {
      error = e.message;
    }
    if (context.mounted) setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final schoolWide = context.watch<AppModel>().seesSchool;
    if (schoolWide && picked == null) {
      return GradeSummary(title: 'Results', kind: 'results', onOpenClass: (cls) => open(cls));
    }
    final students = asMaps(picked?['students']);
    return SchoolScaffold(
      title: 'Results',
      school: context.watch<AppModel>().school,
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : error != null
              ? ErrorNote(error!, loadClasses)
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (picked != null) TextButton(onPressed: () => setState(() => picked = null), child: const Text('All classes')),
                    if (picked == null)
                      for (final c in classes)
                        Card(child: ListTile(title: Text(c['name'].toString(), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)), onTap: () => open(c))),
                    if (picked != null)
                      for (final s in students)
                        _resultCard(s),
                  ],
                ),
    );
  }

  Widget _resultCard(Map<String, dynamic> row) {
    final student = (row['student'] as Map?)?.map((k, v) => MapEntry(k.toString(), v)) ?? {};
    final standing = (row['standing'] as Map?)?.map((k, v) => MapEntry(k.toString(), v)) ?? {};
    final status = standing['status']?.toString() ?? '';
    final color = status == 'promoted' ? passGreen : status == 'failed' ? failRed : ink;
    final label = status == 'promoted' ? 'Promoted' : status == 'failed' ? 'Failed' : status == 'dropout' ? 'Left' : 'Not ready';
    return Card(
      child: ListTile(
        title: Text(student['full_name']?.toString() ?? '', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        subtitle: Text('Average ${standing['average'] ?? '—'}   Rank ${standing['rank'] ?? '—'}', style: const TextStyle(fontSize: 16)),
        trailing: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 16)),
      ),
    );
  }
}

class StudentsScreen extends StatefulWidget {
  const StudentsScreen({super.key});
  @override
  State<StudentsScreen> createState() => _StudentsScreenState();
}

class _StudentsScreenState extends State<StudentsScreen> {
  String? classId;
  List<Map<String, dynamic>> classes = [];
  List<Map<String, dynamic>> students = [];
  Map<String, dynamic>? summary;
  bool loading = true;

  @override
  void initState() { super.initState(); boot(); }

  Future<void> boot() async {
    final model = context.read<AppModel>();
    classes = asMaps(await model.ask((api) => api.get('/api/v1/classes')));
    classId = model.homerooms.isNotEmpty ? model.homerooms.first : (classes.isNotEmpty ? classes.first['id'].toString() : null);
    await load();
  }

  Future<void> load() async {
    if (classId == null) { setState(() => loading = false); return; }
    final model = context.read<AppModel>();
    students = asMaps(await model.ask((api) => api.get('/api/v1/students?class_id=$classId')));
    final sum = await model.ask((api) => api.get('/api/v1/classes/$classId/summary'));
    summary = (sum as Map).map((k, v) => MapEntry(k.toString(), v));
    if (context.mounted) setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final head = (summary?['head'] as Map?) ?? {};
    return SchoolScaffold(
      title: 'My class',
      school: context.watch<AppModel>().school,
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text('Students ${head['students'] ?? 0}   Boys ${head['male'] ?? 0}   Girls ${head['female'] ?? 0}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                Text('Left ${head['dropped'] ?? 0}', style: const TextStyle(fontSize: 16, color: failRed)),
                const SizedBox(height: 8),
                FilledButton(onPressed: addStudent, child: const Text('Add a student')),
                const SizedBox(height: 8),
                for (final s in students)
                  Card(
                    child: ListTile(
                      leading: Icon(s['sex'] == 'F' ? Icons.girl : Icons.boy, size: 32, color: s['dropped_out'] == true ? failRed : leaf),
                      title: Text(s['full_name'].toString(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                      subtitle: Text(s['dropped_out'] == true ? 'Left · ${s['dropout_reason'] ?? ''}' : 'Mother: ${s['mother_name'] ?? ''}'),
                      trailing: s['dropped_out'] == true
                          ? TextButton(onPressed: () => drop(s, false), child: const Text('Undo'))
                          : TextButton(onPressed: () => drop(s, true), child: const Text('Left school', style: TextStyle(color: failRed))),
                    ),
                  ),
              ],
            ),
    );
  }

  Future<void> addStudent() async {
    if (classId == null) return;
    final name = TextEditingController();
    final mother = TextEditingController();
    var sex = 'F';
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New student'),
        content: StatefulBuilder(builder: (context, setLocal) {
          return Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: name, decoration: const InputDecoration(labelText: 'Full name')),
            TextField(controller: mother, decoration: const InputDecoration(labelText: 'Mother\'s name')),
            const SizedBox(height: 8),
            Wrap(spacing: 8, children: [
              ChoiceChip(label: const Text('Girl'), selected: sex == 'F', onSelected: (_) => setLocal(() => sex = 'F')),
              ChoiceChip(label: const Text('Boy'), selected: sex == 'M', onSelected: (_) => setLocal(() => sex = 'M')),
            ]),
          ]);
        }),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    if (name.text.trim().isEmpty) {
      toast(context, 'Type the student\'s name');
      return;
    }
    try {
      await context.read<AppModel>().ask((api) => api.post('/api/v1/students', {
            'full_name': name.text.trim(),
            'sex': sex,
            'mother_name': mother.text.trim(),
            'class_id': classId,
          }));
      if (mounted) saved(context, 'Student added');
      await load();
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message);
    }
  }

  Future<void> drop(Map<String, dynamic> student, bool left) async {
    final ok = await confirm(context, left ? 'Mark as left?' : 'Bring this student back?', student['full_name'].toString(), danger: left);
    if (!ok || !context.mounted) return;
    var reason = '';
    if (left) {
      final typed = await showDialog<String>(
        context: context,
        builder: (context) {
          final box = TextEditingController();
          return AlertDialog(
            title: const Text('Why did they leave?'),
            content: TextField(controller: box, decoration: const InputDecoration(labelText: 'Reason (you can leave this blank)')),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
              FilledButton(onPressed: () => Navigator.pop(context, box.text), child: const Text('Save')),
            ],
          );
        },
      );
      if (typed == null || !context.mounted) return;
      reason = typed.trim();
    }
    final today = DateTime.now();
    final date = '${today.year.toString().padLeft(4, '0')}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    await context.read<AppModel>().ask((api) => api.post('/api/v1/students/${student['id']}/dropout', {'dropped': left, 'reason': reason, 'date': date}));
    if (context.mounted) saved(context, left ? 'Marked as left' : 'Brought back');
    await load();
  }
}

class FeesScreen extends StatefulWidget {
  const FeesScreen({super.key});
  @override
  State<FeesScreen> createState() => _FeesScreenState();
}

class _FeesScreenState extends State<FeesScreen> {
  List<Map<String, dynamic>> rows = [];
  bool loading = true;
  String? classId;

  @override
  void initState() { super.initState(); load(); }

  Future<void> load() async {
    final model = context.read<AppModel>();
    classId = model.homerooms.isNotEmpty ? model.homerooms.first : null;
    final path = classId == null ? '/api/v1/fees' : '/api/v1/fees?class_id=$classId';
    rows = asMaps(await model.ask((api) => api.get(path)));
    if (context.mounted) setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (context.watch<AppModel>().seesSchool) {
      return const GradeSummary(title: 'Fees', kind: 'fees');
    }
    return SchoolScaffold(
      title: 'Fees',
      school: context.watch<AppModel>().school,
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : rows.isEmpty
              ? const EmptyNote('No fees to show.')
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    for (final r in rows)
                      Card(
                        child: ListTile(
                          title: Text(r['full_name'].toString(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                          subtitle: Text('Paid ${r['paid']}   Left ${r['remaining']}', style: TextStyle(fontSize: 16, color: (r['remaining'] as num? ?? 0) == 0 ? passGreen : failRed, fontWeight: FontWeight.w700)),
                          onTap: () async {
                            final amount = await askNumber(context, 'Amount paid', hint: r['full_name'].toString());
                            if (amount == null || !context.mounted) return;
                            try {
                              final today = DateTime.now();
                              final date = '${today.year.toString().padLeft(4, '0')}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
                              await context.read<AppModel>().ask((api) => api.post('/api/v1/fees', {'student_id': r['student_id'], 'amount': amount, 'paid_on': date}));
                              if (context.mounted) saved(context, 'Payment saved');
                              await load();
                            } on ApiException catch (e) {
                              if (context.mounted) toast(context, e.message);
                            }
                          },
                        ),
                      ),
                  ],
                ),
    );
  }
}
