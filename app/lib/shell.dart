import 'package:material_ui/material_ui.dart';

import 'package:provider/provider.dart';

import 'app_state.dart';
import 'edition.dart';
import 'erp_shell.dart';
import 'startup_log.dart';
import 'theme.dart';

class DeskItem {
  const DeskItem(this.label, this.icon, this.page);
  final String label;
  final IconData icon;
  final Widget page;
}

class DeskHost extends StatefulWidget {
  const DeskHost({super.key, required this.home, required this.pages});

  final Widget home;
  final List<DeskItem> Function(AppModel model) pages;

  static DeskHostState? of(BuildContext context) => context.findAncestorStateOfType<DeskHostState>();

  @override
  State<DeskHost> createState() => DeskHostState();
}

class DeskHostState extends State<DeskHost> {
  int index = 0;

  void home() {
    setState(() => index = 0);
    final nav = Navigator.maybeOf(context);
    if (nav != null && nav.canPop()) nav.popUntil((route) => route.isFirst);
  }

  void go(int i) {
    final watch = Stopwatch()..start();
    setState(() => index = i);
    if (demoEdition) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        logStartup('page $i ${watch.elapsedMilliseconds} ms');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final model = context.watch<AppModel>();
    final items = widget.pages(model);
    final wide = MediaQuery.sizeOf(context).width >= 960;
    final safeIndex = index >= items.length + 1 ? 0 : index;
    final page = safeIndex == 0 ? widget.home : items[safeIndex - 1].page;
    if (demoEdition) {
      return ErpShell(items: items, index: safeIndex, onSelect: go, child: page);
    }
    if (wide) {
      return Scaffold(
        backgroundColor: paper,
        body: SafeArea(
          child: Row(children: [
            NavigationRail(
              backgroundColor: card,
              selectedIndex: safeIndex,
              onDestinationSelected: go,
              labelType: NavigationRailLabelType.all,
              destinations: [
                const NavigationRailDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: Text('Home')),
                for (final item in items) NavigationRailDestination(icon: Icon(item.icon), label: Text(item.label)),
              ],
            ),
            const VerticalDivider(width: 1),
            Expanded(child: page),
          ]),
        ),
      );
    }
    final shown = items.length > 4 ? items.sublist(0, 4) : items;
    return Scaffold(
      backgroundColor: paper,
      body: SafeArea(child: page),
      bottomNavigationBar: NavigationBar(
        selectedIndex: safeIndex > shown.length ? 0 : safeIndex,
        onDestinationSelected: (i) => go(i > shown.length ? 0 : i),
        destinations: [
          const NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Home'),
          for (final item in shown) NavigationDestination(icon: Icon(item.icon), label: item.label),
        ],
      ),
    );
  }
}

class SchoolScaffold extends StatelessWidget {
  const SchoolScaffold({super.key, required this.title, required this.body, this.actions, this.school, this.hint});

  final String title;
  final String? school;
  final String? hint;
  final Widget body;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    final nav = Navigator.maybeOf(context);
    final desk = DeskHost.of(context);
    final inside = demoEdition && ErpShell.of(context) != null;
    final canBack = inside ? (nav?.canPop() ?? false) : ((nav?.canPop() ?? false) || (desk != null && desk.index != 0));
    if (inside) {
      return Scaffold(
        backgroundColor: const Color(0xFFF4F6F8),
        body: Column(children: [
          if (title.isNotEmpty || canBack)
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
              child: Row(children: [
                if (canBack)
                  IconButton(
                    tooltip: 'Back',
                    onPressed: () {
                      if (nav != null && nav.canPop()) {
                        nav.pop();
                      } else {
                        desk?.home();
                      }
                    },
                    icon: const Icon(Icons.arrow_back),
                  ),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                    if ((hint ?? '').isNotEmpty) Text(hint!, style: const TextStyle(fontSize: 15, color: Color(0xFF5C6B7A))),
                  ]),
                ),
                ...?actions,
              ]),
            ),
          Expanded(child: body),
        ]),
      );
    }
    if (demoEdition && title.isEmpty) {
      return Scaffold(backgroundColor: const Color(0xFFF4F6F8), body: SafeArea(child: Column(children: [Expanded(child: body), const SchoolFooter()])));
    }
    return Scaffold(
      backgroundColor: paper,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
              child: Row(
                children: [
                  if (canBack)
                    IconButton(
                      iconSize: 32,
                      tooltip: 'Back',
                      onPressed: () {
                        if (nav != null && nav.canPop()) {
                          nav.pop();
                        } else {
                          desk?.home();
                        }
                      },
                      icon: const Icon(Icons.arrow_back),
                    ),
                  if (desk != null)
                    IconButton(
                      iconSize: 32,
                      tooltip: 'Home',
                      onPressed: desk.home,
                      icon: const Icon(Icons.home),
                    ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if ((school ?? '').isNotEmpty)
                          Text(school!, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: leaf, fontWeight: FontWeight.w800, fontSize: 14)),
                        Text(title, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
                        if ((hint ?? '').isNotEmpty)
                          Text(hint!, style: const TextStyle(fontSize: 16, color: leafDark)),
                      ],
                    ),
                  ),
                  if (demoEdition)
                    TextButton(onPressed: () {
                      Navigator.of(context).popUntil((route) => route.isFirst);
                      context.read<AppModel>().signOut();
                    }, child: const Text('Switch role')),
                  if (demoEdition)
                    Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: failRed, borderRadius: BorderRadius.circular(6)),
                      child: const Text('DEMO', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.6)),
                    ),
                  ...?actions,
                ],
              ),
            ),
            Expanded(child: body),
            const SchoolFooter(),
          ],
        ),
      ),
    );
  }
}

class SchoolFooter extends StatelessWidget {
  const SchoolFooter({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: ink,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: const Text(footerText, textAlign: TextAlign.center, style: TextStyle(color: Color(0xFFF4F1EA), fontSize: 12)),
    );
  }
}

class BigTile extends StatelessWidget {
  const BigTile({super.key, required this.icon, required this.label, required this.color, required this.onTap});

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: card,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(radius: 28, backgroundColor: color.withValues(alpha: 0.15), child: Icon(icon, color: color, size: 32)),
              const SizedBox(height: 10),
              Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            ],
          ),
        ),
      ),
    );
  }
}

Future<bool> confirm(BuildContext context, String title, String body, {bool danger = false}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
      content: Text(body, style: const TextStyle(fontSize: 18)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel', style: TextStyle(fontSize: 18))),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: danger ? failRed : leaf),
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Yes'),
        ),
      ],
    ),
  );
  return result ?? false;
}

void toast(BuildContext context, String text) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text, style: const TextStyle(fontSize: 16))));
}

void saved(BuildContext context, String text) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    backgroundColor: passGreen,
    content: Row(children: [
      const Icon(Icons.check_circle, color: Colors.white),
      const SizedBox(width: 8),
      Expanded(child: Text(text, style: const TextStyle(fontSize: 16, color: Colors.white))),
    ]),
  ));
}
