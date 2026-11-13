import 'package:material_ui/material_ui.dart';

import 'edition.dart';
import 'theme.dart';

class SchoolScaffold extends StatelessWidget {
  const SchoolScaffold({super.key, required this.title, required this.body, this.actions, this.school});

  final String title;
  final String? school;
  final Widget body;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: paper,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
              child: Row(
                children: [
                  if (Navigator.canPop(context))
                    IconButton(
                      iconSize: 32,
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back),
                    ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if ((school ?? '').isNotEmpty)
                          Text(school!, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: leaf, fontWeight: FontWeight.w800, fontSize: 14)),
                        Text(title, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
                      ],
                    ),
                  ),
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
