import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import 'app_state.dart';
import 'shell.dart';
import 'theme.dart';

class SoftCard extends StatelessWidget {
  const SoftCard({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.radius = 26});
  final Widget child;
  final EdgeInsets padding;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFFCFAF6),
      elevation: 2,
      shadowColor: const Color(0x140E2438),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius),
        side: const BorderSide(color: Colors.white),
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

class DemoChrome extends StatelessWidget {
  const DemoChrome({super.key, required this.items, required this.index, required this.onSelect, required this.wide, required this.child});

  final List<DeskItem> items;
  final int index;
  final ValueChanged<int> onSelect;
  final bool wide;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final shown = items.length > 4 ? items.sublist(0, 4) : items;
    final rail = wide
        ? _rail(items, index)
        : null;
    return Scaffold(
      backgroundColor: cream,
      body: SafeArea(
        child: wide
            ? Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                rail!,
                const SizedBox(width: 8),
                Expanded(child: child),
              ])
            : child,
      ),
      bottomNavigationBar: wide
          ? null
          : Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: SoftCard(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                radius: 28,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _bit(Icons.home, 'Home', index == 0, () => onSelect(0)),
                    for (var i = 0; i < shown.length; i++) _bit(shown[i].icon, shown[i].label, index == i + 1, () => onSelect(i + 1)),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _rail(List<DeskItem> items, int index) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
      child: SoftCard(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: SingleChildScrollView(
          child: Column(children: [
            _bit(Icons.home, 'Home', index == 0, () => onSelect(0)),
            for (var i = 0; i < items.length; i++) _bit(items[i].icon, items[i].label, index == i + 1, () => onSelect(i + 1)),
          ]),
        ),
      ),
    );
  }

  Widget _bit(IconData icon, String label, bool on, VoidCallback tap) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        onTap: tap,
        borderRadius: BorderRadius.circular(18),
        child: SizedBox(
          width: 76,
          child: Column(children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(color: on ? navy : const Color(0xFFF3EEE6), borderRadius: BorderRadius.circular(16)),
              child: Icon(icon, color: on ? Colors.white : navy, size: 24),
            ),
            const SizedBox(height: 4),
            Text(label, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: on ? navy : navyInk)),
          ]),
        ),
      ),
    );
  }
}

class HelloBar extends StatelessWidget {
  const HelloBar({super.key, required this.onSearch});
  final ValueChanged<String> onSearch;

  @override
  Widget build(BuildContext context) {
    final model = context.watch<AppModel>();
    final name = model.user['display_name']?.toString() ?? 'there';
    return Row(children: [
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Hello, $name 👋', style: const TextStyle(fontFamily: 'Georgia', fontSize: 28, fontWeight: FontWeight.w700, color: navy)),
        const Text('Hope Academy · tap a card to begin', style: TextStyle(fontSize: 15, color: Color(0xFF6D7C8A))),
      ])),
      SizedBox(
        width: 220,
        child: TextField(
          decoration: const InputDecoration(hintText: 'Search', prefixIcon: Icon(Icons.search)),
          onSubmitted: onSearch,
        ),
      ),
      const SizedBox(width: 8),
      CircleAvatar(radius: 22, backgroundColor: navy, child: Text(name.isEmpty ? 'H' : name[0], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800))),
      TextButton(onPressed: () {
        Navigator.of(context).popUntil((route) => route.isFirst);
        context.read<AppModel>().signOut();
      }, child: const Text('Switch role')),
    ]);
  }
}
