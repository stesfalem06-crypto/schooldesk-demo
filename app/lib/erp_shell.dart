import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import 'app_state.dart';
import 'demo_extra.dart';
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

class ErpShellState extends State<ErpShell> {
  final _search = TextEditingController();
  GlobalKey<NavigatorState> _navKey = GlobalKey<NavigatorState>();
  int _navFor = -1;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  String get section => widget.index == 0 ? 'Dashboard' : widget.items[widget.index - 1].label;

  void _openSearch(String query) {
    final text = query.trim();
    if (text.isEmpty) return;
    _navKey.currentState?.push(MaterialPageRoute(builder: (_) => SearchScreen(query: text)));
    _search.clear();
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
        _Side(items: widget.items, index: widget.index, onSelect: widget.onSelect),
        Expanded(
          child: Column(children: [
            _Top(model: model, search: _search, onSearch: _openSearch),
            Container(
              width: double.infinity,
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
              child: Text('Home  /  $section', style: const TextStyle(fontSize: 15, color: Color(0xFF5C6B7A))),
            ),
            const Divider(height: 1, color: line),
            Expanded(
              child: Navigator(
                key: _navKey,
                onGenerateRoute: (_) => MaterialPageRoute(builder: (_) => widget.child),
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
  const _Top({required this.model, required this.search, required this.onSearch});
  final AppModel model;
  final TextEditingController search;
  final ValueChanged<String> onSearch;

  @override
  Widget build(BuildContext context) {
    final role = model.user['display_name']?.toString() ?? 'Staff';
    return Material(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 12, 10),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(model.school.isEmpty ? 'Hope Academy' : model.school, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: ink)),
              Text(role, style: const TextStyle(fontSize: 14, color: Color(0xFF5C6B7A))),
            ]),
          ),
          SizedBox(
            width: 280,
            child: TextField(
              controller: search,
              decoration: const InputDecoration(hintText: 'Search students and staff', prefixIcon: Icon(Icons.search), isDense: true),
              onSubmitted: onSearch,
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: () => context.read<AppModel>().signOut(),
            child: const Text('Switch role'),
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
