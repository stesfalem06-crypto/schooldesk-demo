import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import 'app_state.dart';
import 'demo_extra.dart';
import 'school_book.dart';
import 'widgets.dart';
import 'shell.dart';
import 'startup_log.dart';
import 'theme.dart';

class ErpShell extends StatefulWidget {
  const ErpShell({super.key, required this.items, required this.index, required this.onSelect, required this.child});

  final List<DeskItem> items;
  final int index;
  final ValueChanged<int> onSelect;
  final Widget child;

  static ErpShellState? of(BuildContext context) => context.findAncestorStateOfType<ErpShellState>();

  @override
  State<ErpShell> createState() => ErpShellState();
}

class DeskTrail {
  static void push(BuildContext context, Widget page, {required String nav, required List<String> crumbs}) {
    Navigator.of(context).push(MaterialPageRoute(
      settings: RouteSettings(arguments: {'nav': nav, 'crumbs': crumbs}),
      builder: (_) => page,
    ));
  }
}

class ErpShellState extends State<ErpShell> {
  final _search = TextEditingController();
  List<Map<String, dynamic>> _hits = [];
  GlobalKey<NavigatorState> _navKey = GlobalKey<NavigatorState>();
  late final _TrailObserver _observer = _TrailObserver(this);
  int _navFor = -1;
  List<String> _crumbs = [];
  String? _navLabel;

  void applyTrail(List<String> crumbs, String? nav) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _crumbs = crumbs;
        _navLabel = nav;
      });
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  String get section => widget.index == 0 ? 'Dashboard' : widget.items[widget.index - 1].label;

  int get _highlight {
    if (_navLabel == null) return widget.index;
    final i = widget.items.indexWhere((item) => item.label == _navLabel);
    return i < 0 ? -1 : i + 1;
  }

  void _openSearch(String query) {
    final text = query.trim();
    if (text.isEmpty) {
      setState(() => _hits = []);
      return;
    }
    final model = context.read<AppModel>();
    if (model.seesSchool) {
      final hits = asMaps(SchoolBook.instance.callNow('GET', '/api/v1/search?q=${Uri.encodeQueryComponent(text)}', null));
      setState(() => _hits = hits.where((h) => h['kind'] == 'student').take(8).toList());
      return;
    }
    _navKey.currentState?.push(MaterialPageRoute(builder: (_) => SearchScreen(query: text)));
    _search.clear();
  }

  void _openHit(Map<String, dynamic> hit) {
    setState(() => _hits = []);
    _search.clear();
    _navKey.currentState?.push(MaterialPageRoute(
      settings: RouteSettings(arguments: {'nav': 'Students', 'crumbs': ['Students', hit['name'].toString()]}),
      builder: (_) => ProfileScreen(id: hit['id'].toString()),
    ));
  }

  @override
  Widget build(BuildContext context) {
    if (_navFor != widget.index) {
      _navFor = widget.index;
      _navKey = GlobalKey<NavigatorState>();
    }
    final model = context.watch<AppModel>();
    return Material(
      color: const Color(0xFFF4F6F8),
      child: Row(children: [
        _Side(items: widget.items, index: _highlight, onSelect: widget.onSelect),
        Expanded(
          child: Column(children: [
            _Top(model: model, search: _search, onSearch: _openSearch, hits: _hits, onHit: _openHit),
            Container(
              width: double.infinity,
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
              child: Text('Home  /  ${(_crumbs.isEmpty ? [section] : _crumbs).join('  /  ')}', style: const TextStyle(fontSize: 15, color: Color(0xFF5C6B7A))),
            ),
            const Divider(height: 1, color: line),
            Expanded(
              child: Navigator(
                key: _navKey,
                observers: [_observer],
                onGenerateRoute: (settings) => MaterialPageRoute(settings: settings, builder: (_) => widget.child),
              ),
            ),
            const SchoolFooter(),
          ]),
        ),
      ]),
    );
  }
}

class _Top extends StatelessWidget {
  const _Top({required this.model, required this.search, required this.onSearch, required this.hits, required this.onHit});
  final AppModel model;
  final TextEditingController search;
  final ValueChanged<String> onSearch;
  final List<Map<String, dynamic>> hits;
  final ValueChanged<Map<String, dynamic>> onHit;

  @override
  Widget build(BuildContext context) {
    final role = model.user['display_name']?.toString() ?? 'Staff';
    final person = model.user['person_name']?.toString() ?? '';
    final who = person.isEmpty ? role : '$role · $person';
    return Material(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 12, 10),
        child: Column(children: [
          Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(model.school.isEmpty ? 'Hope Academy' : model.school, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: ink)),
              Text(who, style: const TextStyle(fontSize: 14, color: Color(0xFF5C6B7A))),
            ]),
          ),
          SizedBox(
            width: 280,
            child: TextField(
              controller: search,
              decoration: const InputDecoration(hintText: 'Search students and staff', prefixIcon: Icon(Icons.search), isDense: true),
              onChanged: onSearch,
              onSubmitted: onSearch,
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: () => context.read<AppModel>().signOut(),
            child: const Text('Switch role'),
          ),
        ]),
          if (hits.isNotEmpty)
            for (final hit in hits)
              ListTile(
                dense: true,
                title: Text(hit['name'].toString(), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                subtitle: const Text('Student'),
                onTap: () => onHit(hit),
              ),
        ]),
      ),
    );
  }
}

class _Side extends StatelessWidget {
  const _Side({required this.items, required this.index, required this.onSelect});
  final List<DeskItem> items;
  final int index;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 232,
      color: Colors.white,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text('SchoolDesk', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: navy)),
        ),
        Expanded(
          child: ListView(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), children: [
            _link(Icons.dashboard_outlined, 'Dashboard', index == 0, () => onSelect(0)),
            for (var i = 0; i < items.length; i++) _link(items[i].icon, items[i].label, index == i + 1, () => onSelect(i + 1)),
          ]),
        ),
      ]),
    );
  }

  Widget _link(IconData icon, String label, bool on, VoidCallback tap) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Material(
        color: on ? const Color(0xFFE7F0FA) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          key: Key('nav-$label'),
          borderRadius: BorderRadius.circular(8),
          onTap: () {
            final watch = Stopwatch()..start();
            tap();
            WidgetsBinding.instance.addPostFrameCallback((_) {
              logStartup('nav $label ${watch.elapsedMilliseconds} ms');
            });
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            child: Row(children: [
              Icon(icon, size: 20, color: on ? navy : const Color(0xFF3E4C59)),
              const SizedBox(width: 10),
              Expanded(child: Text(label, style: TextStyle(fontSize: 15, fontWeight: on ? FontWeight.w800 : FontWeight.w600, color: on ? navy : ink))),
            ]),
          ),
        ),
      ),
    );
  }
}

class _TrailObserver extends NavigatorObserver {
  _TrailObserver(this.shell);
  final ErpShellState shell;

  void _sync(Route<dynamic>? route) {
    final args = route?.settings.arguments;
    if (args is Map && args['crumbs'] is List) {
      shell.applyTrail(List<String>.from(args['crumbs'] as List), args['nav']?.toString());
    } else {
      shell.applyTrail(const [], null);
    }
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (previousRoute == null) return;
    _sync(route);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) => _sync(previousRoute);

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) => _sync(newRoute);
}
